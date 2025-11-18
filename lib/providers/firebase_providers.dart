import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_service.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';

final firebaseServiceProvider = Provider<FirebaseService>((ref) => FirebaseService());

final userStreamProvider = StreamProvider.family.autoDispose<UserModel?, String>((ref, clerkId) {
  final svc = ref.watch(firebaseServiceProvider);
  return svc.streamUserByClerkId(clerkId);
});

final transactionsStreamProvider = StreamProvider.family.autoDispose<List<TransactionModel>, String>((ref, clerkId) {
  final svc = ref.watch(firebaseServiceProvider);
  return svc.streamTransactionsByClerkId(clerkId);
});

final budgetsStreamProvider = StreamProvider.family.autoDispose<List<BudgetModel>, String>((ref, clerkId) {
  final svc = ref.watch(firebaseServiceProvider);
  return svc.streamBudgetsByClerkId(clerkId);
});
