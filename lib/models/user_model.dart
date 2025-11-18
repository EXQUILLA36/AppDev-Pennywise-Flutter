// lib/models/user_model.dart

import 'wallet_model.dart';
import 'transaction_model.dart';
import 'budget_model.dart';
import 'dart:convert';

class UserModel {
  final String userId;
  final String email;
  final String username;
  final String fullName;
  final String lastUpdated;
  WalletModel wallet;
  Map<String, double> balanceHistory;
  Map<String, dynamic> previousBalance;
  List<BudgetModel> budgets;
  List<TransactionModel> transactions;

  // NEW: categories arrays (can be strings or maps)
  List<dynamic> incomeSource;
  List<dynamic> expenseSource;

  UserModel({
    required this.userId,
    required this.email,
    required this.username,
    required this.fullName,
    required this.lastUpdated,
    required this.wallet,
    required this.balanceHistory,
    required this.previousBalance,
    required this.budgets,
    required this.transactions,
    required this.incomeSource,
    required this.expenseSource,
  });

  factory UserModel.fromMap(Map<String, dynamic> m) {
    final bh = <String, double>{};
    if (m['balanceHistory'] is Map) {
      (m['balanceHistory'] as Map).forEach((k, v) {
        try {
          bh[k.toString()] = (v as num).toDouble();
        } catch (_) {}
      });
    }

    // read categories safely (may be missing)
    final rawIncome = m['incomeSource'];
    final rawExpense = m['expenseSource'];

    List<dynamic> incomeList() {
      if (rawIncome == null) return <dynamic>[];
      if (rawIncome is List) return rawIncome.map((e) => e).toList();
      // if accidentally stored as JSON string, try decode
      if (rawIncome is String) {
        try {
          final decoded = jsonDecode(rawIncome);
          if (decoded is List) return decoded;
        } catch (_) {}
      }
      return <dynamic>[];
    }

    List<dynamic> expenseList() {
      if (rawExpense == null) return <dynamic>[];
      if (rawExpense is List) return rawExpense.map((e) => e).toList();
      if (rawExpense is String) {
        try {
          final decoded = jsonDecode(rawExpense);
          if (decoded is List) return decoded;
        } catch (_) {}
      }
      return <dynamic>[];
    }

    return UserModel(
      userId: m['userId'] ?? (m['clerk_id'] ?? ''), // tolerate clerk_id field
      email: m['email'] ?? '',
      username: m['username'] ?? '',
      fullName: m['full_name'] ?? '',
      lastUpdated: m['lastUpdated'] ?? '',
      wallet: WalletModel.fromMap(Map<String, dynamic>.from(m['wallet'] ?? {})),
      balanceHistory: bh,
      previousBalance: Map<String, dynamic>.from(m['previousBalance'] ?? {}),
      budgets: (m['budgets'] ?? []).map<BudgetModel>((b) => BudgetModel.fromMap(Map<String, dynamic>.from(b))).toList(),
      transactions: (m['transactions'] ?? []).map<TransactionModel>((t) => TransactionModel.fromMap(Map<String, dynamic>.from(t))).toList(),
      incomeSource: incomeList(),
      expenseSource: expenseList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'email': email,
        'username': username,
        'full_name': fullName,
        'lastUpdated': lastUpdated,
        'wallet': wallet.toMap(),
        'balanceHistory': balanceHistory,
        'previousBalance': previousBalance,
        'budgets': budgets.map((b) => b.toMap()).toList(),
        'transactions': transactions.map((t) => t.toMap()).toList(),
        'incomeSource': incomeSource,
        'expenseSource': expenseSource,
      };

  @override
  String toString() {
    return 'UserModel(userId:$userId, username:$username, txs:${transactions.length}, income:${incomeSource.length}, expense:${expenseSource.length})';
  }
}
