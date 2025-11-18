class BudgetModel {
  final String budgetSource;
  final String amountAllocated; // keep string per your spec
  double amountUsed;
  final String icons;
  final String resets;
  final String? id;

  BudgetModel({
    required this.budgetSource,
    required this.amountAllocated,
    required this.amountUsed,
    required this.icons,
    required this.resets,
    this.id,
  });

  factory BudgetModel.fromMap(Map<String, dynamic> m, {String? id}) {
    return BudgetModel(
      budgetSource: m['budgetSource'] ?? '',
      amountAllocated: (m['amountAllocated'] ?? '0').toString(),
      amountUsed: (m['amountUsed'] ?? 0).toDouble(),
      icons: m['icons'] ?? '',
      resets: m['resets'] ?? '',
      id: id,
    );
  }

  Map<String, dynamic> toMap() => {
        'budgetSource': budgetSource,
        'amountAllocated': amountAllocated,
        'amountUsed': amountUsed,
        'icons': icons,
        'resets': resets,
      };
}
