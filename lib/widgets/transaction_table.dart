import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';
import '../providers/firebase_providers.dart';
import '../utils/constants.dart';
import 'package:intl/intl.dart';
import '../utils/date_utils.dart';

/// A DataTable source for PaginatedDataTable
class _TransactionsDataSource extends DataTableSource {
  final List<TransactionModel> original;
  List<TransactionModel> rows;
  final void Function(TransactionModel)? onTap;

  _TransactionsDataSource({required this.original, this.onTap})
    : rows = List.from(original);

  void sort<T>(
    Comparable<T> Function(TransactionModel d) getField,
    bool ascending,
  ) {
    rows.sort((a, b) {
      final A = getField(a);
      final B = getField(b);
      final cmp = Comparable.compare(A, B);
      return ascending ? cmp : -cmp;
    });
    notifyListeners();
  }

  void updateFilter(String query, String typeFilter) {
    final q = query.trim().toLowerCase();
    rows = original.where((t) {
      final matchQuery = q.isEmpty
          ? true
          : (t.source.toLowerCase().contains(q) ||
                (t.notes ?? '').toLowerCase().contains(q));
      final matchType = (typeFilter == 'All') ? true : (t.type == typeFilter);
      return matchQuery && matchType;
    }).toList();
    notifyListeners();
  }

  @override
  DataRow getRow(int index) {
    assert(index >= 0);
    if (index >= rows.length) return const DataRow(cells: []);
    final t = rows[index];
    final dateLabel = _formatDate(t.date);
    return DataRow.byIndex(
      index: index,

      cells: [
        DataCell(Text(dateLabel)),
        DataCell(Text(t.source)),
        DataCell(Text(t.type)),
        DataCell(Text('₱${t.amount.toStringAsFixed(2)}')),
      ],
      // onSelectChanged: (sel) {
      //   if (sel == true && onTap != null) onTap!(t);
      // },
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => rows.length;

  @override
  int get selectedRowCount => 0;

  static String _formatDate(String iso) {
    try {
      final dt = parseFlexibleDate(iso);
      if (dt.millisecondsSinceEpoch == 0) return iso;
      return DateFormat.yMMMd().add_jm().format(dt);
    } catch (e) {
      return iso;
    }
  }
}

/// Main widget: listens to the transactions streamProvider family (pass clerkId)
class TransactionTable extends ConsumerStatefulWidget {
  final String clerkId;
  final int rowsPerPage;
  const TransactionTable({
    required this.clerkId,
    this.rowsPerPage = 9,
    super.key,
  });

  @override
  ConsumerState<TransactionTable> createState() => _TransactionTableState();
}

class _TransactionTableState extends ConsumerState<TransactionTable> {
  String _search = '';
  String _typeFilter = 'All';
  int _sortColumnIndex = 0;
  bool _sortAscending = false;
  _TransactionsDataSource? _dataSource;

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(transactionsStreamProvider(widget.clerkId));

    return txAsync.when(
      data: (txs) {
        _dataSource ??= _TransactionsDataSource(
          original: txs,
          onTap: _showTransactionDetails,
        );
        // if original list changed, refresh the datasource
        if (_dataSource!.original.length != txs.length ||
            !_listsEqual(_dataSource!.original, txs)) {
          _dataSource = _TransactionsDataSource(
            original: txs,
            onTap: _showTransactionDetails,
          );
          // apply current filters/sorting
          _dataSource!.updateFilter(_search, _typeFilter);
          _applySortingToDataSource();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Controls row: search + filter + add button (optional)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search by source or notes...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) {
                        setState(() {
                          _search = v;
                          _dataSource?.updateFilter(_search, _typeFilter);
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _typeFilter,
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All')),
                      DropdownMenuItem(value: 'Income', child: Text('Income')),
                      DropdownMenuItem(
                        value: 'Expense',
                        child: Text('Expense'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _typeFilter = v;
                        _dataSource?.updateFilter(_search, _typeFilter);
                      });
                    },
                  ),
                ],
              ),
            ),

            // PaginatedDataTable
            Expanded(
              child: SingleChildScrollView(
                child: PaginatedDataTable(
                  header: Text(
                    'Transactions (${_dataSource?.rowCount ?? 0})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  rowsPerPage: widget.rowsPerPage,
                  sortColumnIndex: _sortColumnIndex,
                  sortAscending: _sortAscending,
                  columns: [
                    DataColumn(
                      label: const Text('Date'),
                      onSort: (colIndex, asc) {
                        setState(() {
                          _sortColumnIndex = colIndex;
                          _sortAscending = asc;
                          _dataSource?.sort<DateTime>((d) {
                            try {
                              return parseFlexibleDate(d.date);
                            } catch (e) {
                              return DateTime.fromMillisecondsSinceEpoch(0);
                            }
                          }, asc);
                        });
                      },
                    ),
                    DataColumn(
                      label: const Text('Source'),
                      onSort: (colIndex, asc) {
                        setState(() {
                          _sortColumnIndex = colIndex;
                          _sortAscending = asc;
                          _dataSource?.sort<String>(
                            (d) => d.source.toLowerCase(),
                            asc,
                          );
                        });
                      },
                    ),
                    const DataColumn(label: Text('Type')),
                    DataColumn(
                      label: const Text('Amount'),
                      numeric: true,
                      onSort: (colIndex, asc) {
                        setState(() {
                          _sortColumnIndex = colIndex;
                          _sortAscending = asc;
                          _dataSource?.sort<num>((d) => d.amount, asc);
                        });
                      },
                    ),
                  ],
                  source: _dataSource!,
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error loading transactions: $e')),
    );
  }

  // helper to check list equality by id/amount/date
  bool _listsEqual(List<TransactionModel> a, List<TransactionModel> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].amount != b[i].amount ||
          a[i].date != b[i].date)
        return false;
    }
    return true;
  }

  void _applySortingToDataSource() {
    if (_dataSource == null) return;
    if (_sortColumnIndex == 0) {
      _dataSource!.sort<DateTime>((d) {
        try {
          return parseFlexibleDate(d.date);
        } catch (e) {
          return DateTime.fromMillisecondsSinceEpoch(0);
        }
      }, _sortAscending);
    } else if (_sortColumnIndex == 1) {
      _dataSource!.sort<String>((d) => d.source.toLowerCase(), _sortAscending);
    } else if (_sortColumnIndex == 3) {
      _dataSource!.sort<num>((d) => d.amount, _sortAscending);
    }
  }

  void _showTransactionDetails(TransactionModel t) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.source),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: ₱${t.amount.toStringAsFixed(2)}'),
            Text('Type: ${t.type}'),
            Text('Date: ${_TransactionsDataSource._formatDate(t.date)}'),
            if ((t.notes ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Notes: ${t.notes}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
