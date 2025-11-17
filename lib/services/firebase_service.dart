import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';
import '../utils/date_utils.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String usersCol = 'users';

  Future<UserModel?> fetchUserOnceByClerkId(String clerkId) async {
    final snap = await _db.collection(usersCol).doc(clerkId).get();
    if (!snap.exists) return null;
    return UserModel.fromMap(snap.data()!);
  }

  Stream<UserModel?> streamUserByClerkId(String clerkId) {
    return _db.collection(usersCol).doc(clerkId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserModel.fromMap(snap.data()!);
    });
  }

  /// Stream transactions by reading the embedded `transactions` array on the user doc.
  /// Emits a list sorted newest-first (by date). Falls back to empty list if none found.
  Stream<List<TransactionModel>> streamTransactionsByClerkId(
    String clerkId, {
    int limit = 100,
  }) {
    final controller = StreamController<List<TransactionModel>>();

    final userDocRef = _db.collection(usersCol).doc(clerkId);

    final sub = userDocRef.snapshots().listen(
      (snap) {
        try {
          final data = snap.data();
          if (data != null && data.containsKey('transactions')) {
            final raw = data['transactions'];
            if (raw is List) {
              // map array entries (maps) -> TransactionModel
              final list = raw.whereType<Map<String, dynamic>>().map((m) {
                final normalized = Map<String, dynamic>.from(m);
                return TransactionModel.fromMap(normalized, id: null);
              }).toList();

              // Sort by date newest-first using a safe parser (supports ISO and "MM/dd/yyyy, hh:mm a")
              list.sort((a, b) {
                final da = _tryParseDate(a.date);
                final db = _tryParseDate(b.date);
                return db.compareTo(da); // db - da for newest first
              });

              // optional: limit to `limit`
              final limited = list.length > limit
                  ? list.sublist(0, limit)
                  : list;
              controller.add(limited);
              return;
            }
          }
          // No embedded transactions -> emit empty list
          controller.add(<TransactionModel>[]);
        } catch (e, st) {
          controller.addError(e, st);
        }
      },
      onError: (e, st) {
        controller.addError(e, st);
      },
    );

    controller.onCancel = () async {
      await sub.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  Stream<List<BudgetModel>> streamBudgetsByClerkId(String clerkId) {
    return _db
        .collection(usersCol)
        .doc(clerkId)
        .collection('budgets')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => BudgetModel.fromMap(d.data(), id: d.id))
              .toList(),
        );
  }

  // Atomic add tx and update wallet
  // inside FirebaseService

Future<void> addTransactionAtomic(String clerkId, Map<String, dynamic> tx) async {
  final userDoc = _db.collection(usersCol).doc(clerkId);

  await _db.runTransaction((t) async {
    final snap = await t.get(userDoc);
    Map<String, dynamic> data = snap.exists && snap.data() != null ? Map<String, dynamic>.from(snap.data()!) : {};

    // ensure wallet exists
    final walletRaw = data['wallet'] ?? {
      'total_balance': 0,
      'total_income': 0,
      'total_expenses': 0,
      'total_budget': 0,
    };
    final wallet = Map<String, dynamic>.from(walletRaw);

    // parse amount defensively:
    double amount;
    final rawAmount = tx['amount'];
    if (rawAmount is num) {
      amount = rawAmount.toDouble();
    } else {
      amount = double.tryParse(rawAmount?.toString() ?? '') ?? 0.0;
    }

    final String type = (tx['type'] ?? 'Expense').toString();

    // Update totals safely
    double currentBalance = (wallet['total_balance'] is num) ? (wallet['total_balance'] as num).toDouble() : double.tryParse(wallet['total_balance']?.toString() ?? '') ?? 0.0;
    double currentIncome = (wallet['total_income'] is num) ? (wallet['total_income'] as num).toDouble() : double.tryParse(wallet['total_income']?.toString() ?? '') ?? 0.0;
    double currentExpenses = (wallet['total_expenses'] is num) ? (wallet['total_expenses'] as num).toDouble() : double.tryParse(wallet['total_expenses']?.toString() ?? '') ?? 0.0;

    final updatedBalance = type == 'Income' ? currentBalance + amount : currentBalance - amount;
    final updatedIncome = type == 'Income' ? currentIncome + amount : currentIncome;
    final updatedExpenses = type == 'Expense' ? currentExpenses + amount : currentExpenses;

    wallet['total_balance'] = updatedBalance;
    wallet['total_income'] = updatedIncome;
    wallet['total_expenses'] = updatedExpenses;

    // **Important:** append to embedded transactions array
    // Use a cleaned transaction map (avoid storing functions / complex objects)
    final Map<String, dynamic> txToStore = {
      'amount': amount,
      'date': tx['date'] ?? DateTime.now().toIso8601String(),
      'source': tx['source'] ?? '',
      'type': type,
      if (tx['notes'] != null) 'notes': tx['notes'],
    };

    // Use arrayUnion to append (Firestore will add unique object - duplicates allowed)
    t.set(userDoc, {
      'transactions': FieldValue.arrayUnion([txToStore]),
      'wallet': wallet,
      'lastUpdated': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));

    // Optional: also write a subcollection doc for historical reasons (comment out if undesired)
    // final txRef = userDoc.collection('transactions').doc();
    // t.set(txRef, txToStore);
  });
}



  // inside FirebaseService class

  /// Add a category string/object to incomeSource or expenseSource
  Future<void> addCategory(
    String clerkId,
    String categoryLabel, {
    required bool isIncome,
    String? iconName,
  }) async {
    final userDoc = _db.collection(usersCol).doc(clerkId);
    final entry = iconName == null
        ? categoryLabel
        : {'label': categoryLabel, 'icon': iconName};
    await userDoc.update({
      isIncome ? 'incomeSource' : 'expenseSource': FieldValue.arrayUnion([
        entry,
      ]),
    });
  }

  /// Remove a category (supports existing plain string entries and new map entries)
  // inside FirebaseService class (ensure imports include cloud_firestore and intl if already used)
  // Replace existing removeCategory with:

  /// Remove a category by label. Works for both legacy string entries and map entries.
  /// It reads the current array, filters items matching the label, and writes the filtered list back.
  Future<void> removeCategory(
    String clerkId,
    String categoryLabel, {
    required bool isIncome,
  }) async {
    final userDoc = _db.collection(usersCol).doc(clerkId);

    // Read the current document once
    final snap = await userDoc.get();
    if (!snap.exists) return;

    final data = snap.data();
    if (data == null) return;

    final rawList = data[isIncome ? 'incomeSource' : 'expenseSource'];
    if (rawList == null || rawList is! List) return;

    // Build new list filtering out items whose label matches categoryLabel.
    final List<dynamic> newList = [];

    for (final item in rawList) {
      // If item is plain string, skip those equal to label
      if (item is String) {
        if (item != categoryLabel) newList.add(item);
        continue;
      }

      // If item is a map-like, try to get .label or .name or 'label' field
      if (item is Map) {
        final label = item['label']?.toString() ?? item['name']?.toString();
        if (label == null || label != categoryLabel) {
          newList.add(item);
        } else {
          // filtered out (deleted)
        }
        continue;
      }

      // fallback: keep it if not obviously matching
      if (item.toString() != categoryLabel) newList.add(item);
    }

    // Persist the filtered list (overwrite the array)
    await userDoc.update({
      isIncome ? 'incomeSource' : 'expenseSource': newList,
    });
  }

  /// Overwrite the entire category array (useful when user reorders)
  Future<void> updateCategoryList(
    String clerkId,
    List<dynamic> newList, {
    required bool isIncome,
  }) async {
    final userDoc = _db.collection(usersCol).doc(clerkId);

    // Write the new array (ensure we set, not union)
    await userDoc.update({
      isIncome ? 'incomeSource' : 'expenseSource': newList,
    });
  }
}

/// Safe date parser which supports ISO date strings and "MM/dd/yyyy, hh:mm a" (e.g. "11/09/2025, 10:23 PM")
DateTime _tryParseDate(String s) {
  return parseFlexibleDate(s);
}
