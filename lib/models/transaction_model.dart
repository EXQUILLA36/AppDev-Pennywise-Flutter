class TransactionModel {
  final double amount;
  final String date; // ISO string
  final String source;
  final String type; // "Income" or "Expense"
  final String? notes;
  final String? id;

  TransactionModel({
    required this.amount,
    required this.date,
    required this.source,
    required this.type,
    this.notes,
    this.id,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> m, {String? id}) {
    return TransactionModel(
      amount: double.tryParse(m['amount']?.toString() ?? '0') ?? 0.0,
      date: m['date'] ?? '',
      source: m['source'] ?? '',
      type: m['type'] ?? 'Expense',
      notes: m['notes'],
      id: id,
    );
  }

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'date': date,
        'source': source,
        'type': type,
        if (notes != null) 'notes': notes,
      };
}
