// lib/page/budget_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../utils/constants.dart';
import '../widgets/neumorphic.dart';

/// Lightweight embedded-budget model (used only inside this page).
class _EmbeddedBudget {
  final String key; // internal id for list position (e.g. index or generated)
  final String label;
  final double allocated; // amountAllocated (stored as string in your DB)
  final double used; // amountUsed
  final String? icon;
  final String? resets;
  final Map<String, dynamic>? raw;

  _EmbeddedBudget({
    required this.key,
    required this.label,
    required this.allocated,
    required this.used,
    this.icon,
    this.resets,
    this.raw,
  });

  factory _EmbeddedBudget.fromMap(Map<String, dynamic> m, int index) {
    double parseDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    final label = (m['budgetSource'] ?? m['name'] ?? '').toString();
    final allocated = parseDouble(
      m['amountAllocated'] ?? m['amount'] ?? m['targetAmount'],
    );
    final used = parseDouble(m['amountUsed'] ?? m['spent'] ?? 0);
    return _EmbeddedBudget(
      key: 'embedded_$index',
      label: label.isNotEmpty ? label : 'Untitled',
      allocated: allocated,
      used: used,
      icon: m['icons']?.toString(),
      resets: m['resets']?.toString(),
      raw: Map<String, dynamic>.from(m),
    );
  }

  Map<String, dynamic> toMapForWrite() {
    return {
      'budgetSource': label,
      'amountAllocated': allocated.toString(),
      'amountUsed': used,
      'icons': icon ?? raw?['icons'] ?? '',
      'resets': resets ?? raw?['resets'] ?? '',
    };
  }
}

/// Budget page that reads/writes budgets from the embedded `budgets` array
/// inside the user document (users/{clerkId}).
class BudgetPage extends StatefulWidget {
  final String clerkId;
  const BudgetPage({required this.clerkId, super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  final _fire = FirebaseFirestore.instance;

  Stream<DocumentSnapshot<Map<String, dynamic>>> _userDocStream() {
    return _fire.collection('users').doc(widget.clerkId).snapshots();
  }

  // Helpers ---------------------------------------------------------------

  static double _parseNum(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static List<_EmbeddedBudget> _budgetsFromDocMap(Map<String, dynamic>? data) {
    final raw = data?['budgets'];
    if (raw is List) {
      final list = <_EmbeddedBudget>[];
      for (var i = 0; i < raw.length; i++) {
        final item = raw[i];
        if (item is Map<String, dynamic>) {
          list.add(_EmbeddedBudget.fromMap(item, i));
        } else {
          // coerce non-map to simple map
          list.add(
            _EmbeddedBudget.fromMap({'budgetSource': item.toString()}, i),
          );
        }
      }
      return list;
    }
    return <_EmbeddedBudget>[];
  }

  Future<void> _writeBudgetsArray(List<Map<String, dynamic>> arr) async {
    final userRef = _fire.collection('users').doc(widget.clerkId);
    await userRef.update({'budgets': arr});
  }

  // UI actions -----------------------------------------------------------

  Future<void> _addOrEdit({_EmbeddedBudget? editing}) async {
    final nameCtl = TextEditingController(text: editing?.label ?? '');
    final targetCtl = TextEditingController(
      text: editing != null ? editing.allocated.toStringAsFixed(2) : '',
    );
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(editing == null ? 'Add Budget' : 'Edit Budget'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtl,
                  decoration: const InputDecoration(labelText: 'Budget name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: targetCtl,
                  decoration: const InputDecoration(labelText: 'Target amount'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Enter target amount';
                    if (double.tryParse(v.replaceAll(',', '')) == null)
                      return 'Invalid number';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx, true);
              },
              child: Text(editing == null ? 'Create' : 'Save'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    final name = nameCtl.text.trim();
    final target =
        double.tryParse(targetCtl.text.replaceAll(',', '').trim()) ?? 0.0;

    final userRef = _fire.collection('users').doc(widget.clerkId);

    try {
      final snap = await userRef.get();
      final data = snap.data() ?? {};
      final raw = (data['budgets'] is List)
          ? List.from(data['budgets'] as List)
          : <dynamic>[];

      if (editing == null) {
        // add new map entry
        final toAdd = {
          'budgetSource': name,
          'amountAllocated': target.toString(),
          'amountUsed': 0,
          'icons': '',
          'resets': '',
        };
        // append
        await userRef.update({
          'budgets': FieldValue.arrayUnion([toAdd]),
        });
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Budget added')));
      } else {
        // update the first entry whose budgetSource matches editing.label
        var replaced = false;
        final updated = <dynamic>[];
        for (final item in raw) {
          if (!replaced &&
              item is Map &&
              (item['budgetSource'] ?? '') == editing.label) {
            final newEntry = Map<String, dynamic>.from(item);
            newEntry['budgetSource'] = name;
            newEntry['amountAllocated'] = target.toString();
            // preserve amountUsed (or keep editing.used)
            newEntry['amountUsed'] = item['amountUsed'] ?? editing.used;
            updated.add(newEntry);
            replaced = true;
          } else {
            updated.add(item);
          }
        }
        if (!replaced) {
          // fallback: append if not found
          updated.add({
            'budgetSource': name,
            'amountAllocated': target.toString(),
            'amountUsed': editing.used,
            'icons': editing.icon ?? '',
            'resets': editing.resets ?? '',
          });
        }
        await userRef.update({'budgets': updated});
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Budget updated')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _deleteBudget(String label) async {
    final conf = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete budget'),
        content: Text(
          'Delete "$label"? This will remove the budget permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (conf != true) return;

    final userRef = _fire.collection('users').doc(widget.clerkId);
    try {
      final snap = await userRef.get();
      final data = snap.data() ?? {};
      final raw = (data['budgets'] is List)
          ? List.from(data['budgets'] as List)
          : <dynamic>[];
      final filtered = raw.where((item) {
        if (item is Map) return (item['budgetSource'] ?? '') != label;
        return item.toString() != label;
      }).toList();
      await userRef.update({'budgets': filtered});
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Budget deleted')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Future<void> _addSpent(_EmbeddedBudget b) async {
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Add spent to "${b.label}"'),
        content: TextFormField(
          controller: ctl,
          decoration: const InputDecoration(labelText: 'Amount to add'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final add = double.tryParse(ctl.text.replaceAll(',', '').trim()) ?? 0.0;
    if (add <= 0) return;

    final userRef = _fire.collection('users').doc(widget.clerkId);
    try {
      final snap = await userRef.get();
      final data = snap.data() ?? {};
      final raw = (data['budgets'] is List)
          ? List.from(data['budgets'] as List)
          : <dynamic>[];
      final updated = <dynamic>[];
      var updatedOne = false;
      for (final item in raw) {
        if (!updatedOne &&
            item is Map &&
            (item['budgetSource'] ?? '') == b.label) {
          final curr = _parseNum(item['amountUsed']);
          final newEntry = Map<String, dynamic>.from(item);
          newEntry['amountUsed'] = curr + add;
          updated.add(newEntry);
          updatedOne = true;
        } else {
          updated.add(item);
        }
      }
      if (!updatedOne) {
        updated.add({
          'budgetSource': b.label,
          'amountAllocated': b.allocated.toString(),
          'amountUsed': add,
          'icons': b.icon ?? '',
          'resets': b.resets ?? '',
        });
      }
      await userRef.update({'budgets': updated});
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Updated spent')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  Future<void> _resetSpent(_EmbeddedBudget b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reset spent'),
        content: Text('Reset spent for "${b.label}" to 0?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final userRef = _fire.collection('users').doc(widget.clerkId);
    try {
      final snap = await userRef.get();
      final data = snap.data() ?? {};
      final raw = (data['budgets'] is List)
          ? List.from(data['budgets'] as List)
          : <dynamic>[];
      final updated = <dynamic>[];
      for (final item in raw) {
        if (item is Map && (item['budgetSource'] ?? '') == b.label) {
          final newEntry = Map<String, dynamic>.from(item);
          newEntry['amountUsed'] = 0;
          updated.add(newEntry);
        } else {
          updated.add(item);
        }
      }
      await userRef.update({'budgets': updated});
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Spent reset')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Reset failed: $e')));
    }
  }

  // Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final userRef = _fire.collection('users').doc(widget.clerkId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userDocStream(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());

          final doc = snap.data!;
          final data = doc.data();
          final budgets = _budgetsFromDocMap(data);

          if (budgets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No budgets yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Tap the + button to create your first budget.'),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _addOrEdit(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add budget'),
                    ),
                  ],
                ),
              ),
            );
          }

          return SizedBox(

            height: 710,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: budgets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final b = budgets[i];
                final pct = (b.allocated <= 0)
                    ? 0.0
                    : (b.used / b.allocated).clamp(0.0, 1.0);
                final color = Theme.of(context).colorScheme.primary;
                return NeumorphicCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.label,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text(
                                      '₱${b.used.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '/ ₱${b.allocated.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${(pct * 100).toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    minHeight: 8,
                                    backgroundColor: Colors.white12,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            TextButton.icon(
                              onPressed: () => _addSpent(b),
                              icon: const Icon(Icons.add_shopping_cart),
                              label: const Text('Add spent'),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () => _resetSpent(b),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reset spent'),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Edit budget',
                              icon: const Icon(Icons.edit),
                              onPressed: () => _addOrEdit(editing: b),
                            ),
                            IconButton(
                              tooltip: 'Delete budget',
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteBudget(b.label),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEdit(),
        child: const Icon(Icons.add),
        backgroundColor: AppColors.cta,
      ),
    );
  }
}
