class WalletModel {
  double totalBalance;
  double totalBudget;
  double totalExpenses;
  double totalIncome;

  WalletModel({
    required this.totalBalance,
    required this.totalBudget,
    required this.totalExpenses,
    required this.totalIncome,
  });

  factory WalletModel.fromMap(Map<String, dynamic> m) => WalletModel(
        totalBalance: (m['total_balance'] ?? 0).toDouble(),
        totalBudget: (m['total_budget'] ?? 0).toDouble(),
        totalExpenses: (m['total_expenses'] ?? 0).toDouble(),
        totalIncome: (m['total_income'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'total_balance': totalBalance,
        'total_budget': totalBudget,
        'total_expenses': totalExpenses,
        'total_income': totalIncome,
      };
}
