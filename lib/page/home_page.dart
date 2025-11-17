// lib/page/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:intl/intl.dart';

import '../providers/firebase_providers.dart';
import '../services/firebase_service.dart';
import '../models/transaction_model.dart';
import '../widgets/neumorphic.dart';
import '../widgets/transaction_table.dart';
import '../utils/constants.dart';
import 'auth_wrapper.dart';
import 'category_page.dart';
import '../utils/date_utils.dart';
import 'budget_page.dart';
import 'market_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _selectedIndex = 0;

  // pages placeholders — replace with your real pages as needed
  static const List<String> _titles = [
    'Dashboard',
    'Transactions',
    'Market',
    'Budgets',
    'Account',
    'Categories',
  ];

  void _onNavTap(int idx) {
    setState(() => _selectedIndex = idx);
  }

  Future<void> _openAddTransactionSheet(
    BuildContext context,
    String clerkId,
  ) async {
    final firebaseSvc = ref.read(firebaseServiceProvider);
    // show bottom sheet with form
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AddTransactionSheet(clerkId: clerkId, firebaseSvc: firebaseSvc);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final clerkUser = ClerkAuth.of(context).user;
    final clerkId = clerkUser?.id;

    if (clerkId == null) {
      return const Scaffold(body: SafeArea(child: ClerkAuthentication()));
    }

    // Stream providers to display quick summary on dashboard if needed
    final userAsync = ref.watch(userStreamProvider(clerkId));

    // The body for each index:
    Widget body;
    switch (_selectedIndex) {
      case 0:
        body = userAsync.when(
          data: (u) {
            // debugPrint('u data: $u');
            // // temporarily add these for debugging (place after debugPrint('u data: $u');)
            // try {
            //   debugPrint('--- USER MODEL DUMP ---');
            //   debugPrint('userId: ${u?.userId}');
            //   debugPrint('email: ${u?.email}');
            //   debugPrint('username: ${u?.username}');
            //   debugPrint('full_name: ${u?.fullName}');
            //   debugPrint('wallet: ${u?.wallet?.toMap()}');
            //   debugPrint('transactions count: ${u?.transactions.length}');
            //   for (var i = 0; i < u!.transactions.length; i++) {
            //     final t = u?.transactions[i];
            //     debugPrint('TX[$i] -> date raw: "<${t?.date}>"');
            //     debugPrint('TX[$i] codeUnits: ${t?.date.codeUnits}');
            //     debugPrint('TX[$i] runes: ${t?.date.runes.toList()}');
            //     debugPrint(
            //       'TX[$i] parsed via parseFlexibleDate: ${parseFlexibleDate(t?.date)}',
            //     );
            //   }
            //   debugPrint('--- END DUMP ---');
            // } catch (e, st) {
            //   debugPrint('DEBUG DUMP FAILED: $e');
            //   debugPrint(st.toString());
            // }
            // debug print
            if (u == null) {
              return const Center(
                child: Text('No Pennywise data found for this account.'),
              );
            }

            // ---------- PARSE AND SUMMARY LOGIC (unchanged) ----------
            DateTime _tryParse(String s) {
              return parseFlexibleDate(s);
            }

            final now = DateTime.now();
            final todayStart = DateTime(now.year, now.month, now.day);
            final yesterdayStart = todayStart.subtract(const Duration(days: 1));

            double todayIncome = 0, todayExpenses = 0;
            double yesterdayIncome = 0, yesterdayExpenses = 0;

            for (final tx in u.transactions) {
              final dt = _tryParse(tx.date);
              if (dt.isAfter(todayStart)) {
                if (tx.type == 'Income')
                  todayIncome += tx.amount;
                else
                  todayExpenses += tx.amount;
              } else if (dt.isAfter(yesterdayStart) &&
                  dt.isBefore(todayStart)) {
                if (tx.type == 'Income')
                  yesterdayIncome += tx.amount;
                else
                  yesterdayExpenses += tx.amount;
              }
            }

            final totalBudget = u.wallet.totalBudget;
            final totalIncome = u.wallet.totalIncome;
            final totalExpenses = u.wallet.totalExpenses;
            final currentBalance = u.wallet.totalBalance;

            double prevBalance = 0;
            try {
              prevBalance = (u.previousBalance['amount'] ?? 0).toDouble();
            } catch (_) {}

            // ---------- PERCENT HELPERS ----------
            Widget percentWidget(double todayVal, double yesterdayVal) {
              if (yesterdayVal == 0) {
                return const Text(
                  "vs yesterday · -",
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                );
              }

              final diff = todayVal - yesterdayVal;
              final pct = (diff / yesterdayVal) * 100;
              final isUp = pct > 0;
              final arrow = isUp ? "▲" : "▼";
              final clr = isUp ? Colors.greenAccent : Colors.redAccent;

              return Text(
                "$arrow ${pct.abs().toStringAsFixed(1)}% · vs yesterday",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: clr,
                ),
              );
            }

            Widget balancePct() {
              if (prevBalance == 0) {
                return const Text(
                  "vs previous · -",
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                );
              }
              final diff = currentBalance - prevBalance;
              final pct = (diff / prevBalance) * 100;
              final isUp = pct > 0;
              final arrow = isUp ? "▲" : "▼";
              final clr = isUp ? Colors.greenAccent : Colors.redAccent;
              return Text(
                "$arrow ${pct.abs().toStringAsFixed(1)}% · vs previous",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: clr,
                ),
              );
            }

            // ---------- CARD BUILDER ----------
            Widget statCard({
              required String title,
              required String value,
              required Widget sub,
              IconData? icon,
              Color? iconColor,
            }) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: NeumorphicCard(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              value,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            sub,
                          ],
                        ),
                      ),
                      if (icon != null)
                        Icon(
                          icon,
                          size: 38,
                          color: iconColor ?? AppColors.accent,
                        ),
                    ],
                  ),
                ),
              );
            }

            // ---------- FINAL UI ----------
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Overview",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  /// 👇 1 CARD PER ROW — NO OVERFLOW
                  statCard(
                    title: "Total Budget",
                    value: "₱${totalBudget.toStringAsFixed(2)}",
                    sub: const Text(
                      "Overall allocation",
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    icon: Icons.category,
                  ),

                  statCard(
                    title: "Total Income",
                    value: "₱${totalIncome.toStringAsFixed(2)}",
                    sub: percentWidget(todayIncome, yesterdayIncome),
                    icon: Icons.arrow_downward,
                    iconColor: Colors.greenAccent,
                  ),

                  statCard(
                    title: "Total Expenses",
                    value: "₱${totalExpenses.toStringAsFixed(2)}",
                    sub: percentWidget(todayExpenses, yesterdayExpenses),
                    icon: Icons.arrow_upward,
                    iconColor: Colors.redAccent,
                  ),

                  statCard(
                    title: "Current Balance",
                    value: "₱${currentBalance.toStringAsFixed(2)}",
                    sub: balancePct(),
                    icon: Icons.account_balance_wallet,
                  ),

                  const SizedBox(height: 8),
                  const Text(
                    "Percent changes compare today's totals vs yesterday using timestamps.",
                    style: TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text("Error: $e")),
        );

        break;

      case 1:
        // Transactions page — use TransactionTable widget
        body = Padding(
          padding: const EdgeInsets.all(12),
          child: TransactionTable(clerkId: clerkId),
        );
        break;

      case 2:
        body = const MarketPage();
        break;

      case 3:
        body = BudgetPage(clerkId: clerkId);
        break;

      case 4:
        body = Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              NeumorphicCard(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.accent,
                    child: Text(
                      clerkUser?.firstName?.substring(0, 1).toUpperCase() ??
                          'U',
                    ),
                  ),
                  title: Text(
                    clerkUser?.username ??
                        clerkUser?.publicMetadata?['username'] ??
                        'User',
                  ),
                  subtitle: Text(clerkUser?.email ?? ''),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  await ClerkAuth.of(context).signOut();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthWrapper()),
                  );
                },
                child: const Text('Sign out'),
              ),
            ],
          ),
        );
        break;

      case 5:
        body = CategoryPage(clerkId: clerkId);
        break;

      default:
        body = const SizedBox.shrink();
    }

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: body,
      floatingActionButtonLocation: FloatingActionButtonLocation.miniCenterDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddTransactionSheet(context, clerkId),
        backgroundColor: AppColors.cta,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 18,
        color: AppColors.surface,
        shadowColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // left side (2 icons)
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.home,
                        color: _selectedIndex == 0
                            ? AppColors.accent
                            : Colors.white70,
                      ),
                      onPressed: () => _onNavTap(0),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.list,
                        color: _selectedIndex == 1
                            ? AppColors.accent
                            : Colors.white70,
                      ),
                      onPressed: () => _onNavTap(1),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.category,
                        color: _selectedIndex == 5
                            ? AppColors.accent
                            : Colors.white70,
                      ),
                      onPressed: () => _onNavTap(5),
                    ),
                  ],
                ),
                // right side (2 icons)
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.store,
                        color: _selectedIndex == 2
                            ? AppColors.accent
                            : Colors.white70,
                      ),
                      onPressed: () => _onNavTap(2),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.pie_chart,
                        color: _selectedIndex == 3
                            ? AppColors.accent
                            : Colors.white70,
                      ),
                      onPressed: () => _onNavTap(3),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.person,
                        color: _selectedIndex == 4
                            ? AppColors.accent
                            : Colors.white70,
                      ),
                      onPressed: () => _onNavTap(4),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet widget for adding a transaction
class AddTransactionSheet extends StatefulWidget {
  final String clerkId;
  final FirebaseService firebaseSvc;
  const AddTransactionSheet({
    required this.clerkId,
    required this.firebaseSvc,
    super.key,
  });

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtl = TextEditingController();
  String _type = 'Expense';
  String _source = '';
  DateTime _picked = DateTime.now();
  final _notesCtl = TextEditingController();

  @override
  void dispose() {
    _amountCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final dt = await showDatePicker(
      context: context,
      initialDate: _picked,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => child ?? const SizedBox.shrink(),
    );
    if (dt != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_picked),
      );
      if (time != null) {
        setState(() {
          _picked = DateTime(dt.year, dt.month, dt.day, time.hour, time.minute);
        });
      } else {
        setState(
          () => _picked = DateTime(
            dt.year,
            dt.month,
            dt.day,
            _picked.hour,
            _picked.minute,
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amt = double.tryParse(_amountCtl.text.replaceAll(',', '')) ?? 0.0;
    final tx = {
      'amount': amt,
      'date': DateFormat('MM/dd/yyyy, hh:mm a').format(_picked),
      'source': _source.isNotEmpty
          ? _source
          : (_type == 'Income' ? 'Allowance' : 'Misc'),
      'type': _type,
      'notes': _notesCtl.text.trim(),
    };

    try {
      await widget.firebaseSvc.addTransactionAtomic(widget.clerkId, tx);
      if (mounted) {
        Navigator.pop(context); // close sheet
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transaction added')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // use padding to make the sheet go above keyboard
    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.36,
      maxChildSize: 0.95,
      builder: (context, sc) {
        return Container(
          padding: EdgeInsets.only(
            top: 18,
            left: 18,
            right: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: sc,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(height: 4, width: 40, color: Colors.white12),
                ),
                const SizedBox(height: 12),
                Text(
                  'Add Transaction',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _amountCtl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Amount'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Enter amount';
                          if (double.tryParse(v.replaceAll(',', '')) == null)
                            return 'Invalid number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _type,
                              items: const [
                                DropdownMenuItem(
                                  value: 'Expense',
                                  child: Text('Expense'),
                                ),
                                DropdownMenuItem(
                                  value: 'Income',
                                  child: Text('Income'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => _type = v);
                              },
                              decoration: const InputDecoration(
                                labelText: 'Type',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Source (e.g., Allowance)',
                              ),
                              onChanged: (v) => _source = v,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesCtl,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'Date: ${DateFormat.yMMMd().add_jm().format(_picked)}',
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _pickDate,
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submit,
                          child: const Text('Add Transaction'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
