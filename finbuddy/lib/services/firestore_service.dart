import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── User Operations ───────────────────────────────────────────

  /// Update user document after onboarding is complete
  Future<void> completeOnboarding({
    required String uid,
    required List<RecurringIncome> incomes,
    required List<RecurringExpense> expenses,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'isSetupComplete': true,
      'recurringIncomes': incomes.map((e) => e.toMap()).toList(),
      'recurringExpenses': expenses.map((e) => e.toMap()).toList(),
    });
  }

  /// Fetch user data
  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  /// Stream user data
  Stream<UserModel?> getUserStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    });
  }

  /// Update recurring incomes
  Future<void> updateRecurringIncomes(String uid, List<RecurringIncome> incomes) async {
    await _firestore.collection('users').doc(uid).update({
      'recurringIncomes': incomes.map((e) => e.toMap()).toList(),
    });
  }

  /// Update recurring expenses
  Future<void> updateRecurringExpenses(String uid, List<RecurringExpense> expenses) async {
    await _firestore.collection('users').doc(uid).update({
      'recurringExpenses': expenses.map((e) => e.toMap()).toList(),
    });
  }

  // ─── Transaction Operations ────────────────────────────────────

  /// Add a new transaction
  Future<void> addTransaction(TransactionModel transaction) async {
    await _firestore.collection('transactions').add(transaction.toMap());
  }

  /// Get ALL transactions for a user — single where clause = no index needed.
  /// All filtering (date ranges, limits) is done client-side.
  Stream<List<TransactionModel>> _getUserTransactions(String uid) {
    return _firestore
        .collection('transactions')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => b.date.compareTo(a.date));
          return list;
        });
  }

  /// Get transactions for a user for the current month (filtered client-side)
  Stream<List<TransactionModel>> getMonthlyTransactions(String uid) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return _getUserTransactions(uid).map((list) => list
        .where((t) =>
            t.date.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) &&
            t.date.isBefore(endOfMonth.add(const Duration(seconds: 1))))
        .toList());
  }

  /// Get recent transactions (last 50), sorted client-side
  Stream<List<TransactionModel>> getRecentTransactions(String uid) {
    return _getUserTransactions(uid)
        .map((list) => list.take(50).toList());
  }

  /// Delete a transaction
  Future<void> deleteTransaction(String transactionId) async {
    await _firestore.collection('transactions').doc(transactionId).delete();
  }
}
