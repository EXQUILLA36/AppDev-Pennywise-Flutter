// lib/page/category_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/firebase_providers.dart';
import '../services/firebase_service.dart';
import '../utils/constants.dart';
import '../widgets/neumorphic.dart';
import 'package:flutter/services.dart';

class CategoryPage extends ConsumerStatefulWidget {
  final String clerkId;
  const CategoryPage({required this.clerkId, super.key});

  @override
  ConsumerState<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends ConsumerState<CategoryPage>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // a small set of icon choices (string keys -> IconData)
  static const Map<String, IconData> _iconMap = {
    'wallet': Icons.account_balance_wallet,
    'shopping_cart': Icons.shopping_cart,
    'transport': Icons.directions_car,
    'food': Icons.fastfood,
    'salary': Icons.payments,
    'gift': Icons.card_giftcard,
    'home': Icons.home,
    'school': Icons.school,
    'misc': Icons.category,
    'piggy': Icons.savings,
  };

  @override
  void initState() {
    _tabController = TabController(length: 2, vsync: this);
    super.initState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // normalize entries - support old strings and new maps
  Map<String, dynamic> _normalizeEntry(dynamic raw) {
    if (raw == null) return {'label': '', 'icon': 'misc'};
    if (raw is String) return {'label': raw, 'icon': 'misc'};
    if (raw is Map) {
      final label = raw['label']?.toString() ?? raw['name']?.toString() ?? '';
      final icon = raw['icon']?.toString() ?? 'misc';
      return {'label': label, 'icon': icon};
    }
    // fallback
    return {'label': raw.toString(), 'icon': 'misc'};
  }

  // build ReorderableList items from normalized list
  Widget _buildList(List<dynamic> rawList, bool isIncome) {
    final normalized = rawList.map((r) => _normalizeEntry(r)).toList();

    if (normalized.isEmpty) {
      return Center(
        child: Text(
          isIncome ? 'No income categories yet.' : 'No expense categories yet.',
        ),
      );
    }

    return ReorderableListView.builder(
      physics: const BouncingScrollPhysics(),
      onReorder: (oldIndex, newIndex) async {
        final list = List<Map<String, dynamic>>.from(normalized);
        if (newIndex > oldIndex) newIndex -= 1;
        final item = list.removeAt(oldIndex);
        list.insert(newIndex, item);

        // persist the new order
        final svc = ref.read(firebaseServiceProvider);
        // Save maps (Firestore supports maps in arrays)
        await svc.updateCategoryList(widget.clerkId, list, isIncome: isIncome);
        setState(() {}); // refresh UI - stream should also pick up changes
      },
      itemCount: normalized.length,
      itemBuilder: (context, index) {
        final entry = normalized[index];
        final label = entry['label'] ?? '';
        final iconName = entry['icon'] ?? 'misc';
        final iconData = _iconMap[iconName] ?? Icons.category;

        return Dismissible(
          key: ValueKey('cat_${isIncome ? 'i' : 'e'}_${label}_$index'),
          background: Container(
            color: Colors.redAccent,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Delete category'),
                content: Text(
                  'Delete "$label"? This will remove it from the selection lists.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            return confirmed == true;
          },
          onDismissed: (direction) async {
            final svc = ref.read(firebaseServiceProvider);
            // remove by label; removeCategory attempts string and map removal
            await svc.removeCategory(widget.clerkId, label, isIncome: isIncome);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Removed "$label"'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () async {
                    // re-add (no icon known here) -> add without icon
                    await svc.addCategory(
                      widget.clerkId,
                      label,
                      isIncome: isIncome,
                    );
                  },
                ),
              ),
            );
          },
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.surface,
              child: Icon(iconData, color: AppColors.accent),
            ),
            title: Text(label),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () =>
                      _showEditDialog(context, label, iconName, isIncome),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.drag_handle),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddDialog(BuildContext context, bool isIncome) async {
    final svc = ref.read(firebaseServiceProvider);

    final _formKey = GlobalKey<FormState>();
    String name = '';
    String selectedIcon = 'misc';

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text('Add ${isIncome ? 'Income' : 'Expense'} Category'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Category name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                  onChanged: (v) => name = v,
                ),
                const SizedBox(height: 12),
                // simple icon picker dropdown
                DropdownButtonFormField<String>(
                  value: selectedIcon,
                  items: _iconMap.keys
                      .map(
                        (k) => DropdownMenuItem(
                          value: k,
                          child: Row(
                            children: [
                              Icon(_iconMap[k]),
                              const SizedBox(width: 8),
                              Text(k),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) selectedIcon = v;
                  },
                  decoration: const InputDecoration(labelText: 'Icon'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                // save as map with label + icon
                await svc.addCategory(
                  widget.clerkId,
                  name.trim(),
                  isIncome: isIncome,
                  iconName: selectedIcon,
                );
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    String oldLabel,
    String oldIcon,
    bool isIncome,
  ) async {
    final svc = ref.read(firebaseServiceProvider);

    final _formKey = GlobalKey<FormState>();
    String name = oldLabel;
    String selectedIcon = oldIcon;

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Edit Category'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: oldLabel,
                  decoration: const InputDecoration(labelText: 'Category name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                  onChanged: (v) => name = v,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedIcon,
                  items: _iconMap.keys
                      .map(
                        (k) => DropdownMenuItem(
                          value: k,
                          child: Row(
                            children: [
                              Icon(_iconMap[k]),
                              const SizedBox(width: 8),
                              Text(k),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) selectedIcon = v;
                  },
                  decoration: const InputDecoration(labelText: 'Icon'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;

                // Remove old item then add new item (Firestore arrayReplace not available)
                await svc.removeCategory(
                  widget.clerkId,
                  oldLabel,
                  isIncome: isIncome,
                );
                await svc.addCategory(
                  widget.clerkId,
                  name.trim(),
                  isIncome: isIncome,
                  iconName: selectedIcon,
                );
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userStreamProvider(widget.clerkId));
    final svc = ref.read(firebaseServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Income'),
            Tab(text: 'Expense'),
          ],
        ),
        actions: [
          // quick add action in app bar
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              final isIncomeTab = _tabController.index == 0;
              _showAddDialog(context, isIncomeTab);
            },
          ),
        ],
      ),

      // keep body as-is (existing TabBarView)
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('No data found'));
          }

          // fetch raw arrays (they might be strings or maps)
          final rawIncome = (user.incomeSource).map((e) => e).toList();
          final rawExpense = (user.expenseSource).map((e) => e).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              // Income tab
              Column(
                children: [
                  Expanded(child: _buildList(rawIncome, true)),
                  // keep the bottom add button as well (redundant but useful for keyboard/scroll)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add Income Category'),
                            onPressed: () => _showAddDialog(context, true),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Expense tab
              Column(
                children: [
                  Expanded(child: _buildList(rawExpense, false)),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add Expense Category'),
                            onPressed: () => _showAddDialog(context, false),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),

      // persistent FAB (always visible) — opens add dialog for the current tab
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        backgroundColor: AppColors.cta,
        onPressed: () {
          final isIncomeTab = _tabController.index == 0;
          _showAddDialog(context, isIncomeTab);
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
