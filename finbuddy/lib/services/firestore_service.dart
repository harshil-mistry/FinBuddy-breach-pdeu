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

  // ─── Transaction Operations ────────────────────────────────────

  /// Add a new transaction
  Future<void> addTransaction(TransactionModel transaction) async {
    await _firestore.collection('transactions').add(transaction.toMap());
  }

  /// Get transactions for a user for the current month
  /// Sorting is done client-side to avoid needing a composite Firestore index
  Stream<List<TransactionModel>> getMonthlyTransactions(String uid) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return _firestore
        .collection('transactions')
        .where('uid', isEqualTo: uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
              .toList();
          // Sort by date descending on the client
          list.sort((a, b) => b.date.compareTo(a.date));
          return list;
        });
  }

  /// Get recent transactions (last 50), sorted client-side
  Stream<List<TransactionModel>> getRecentTransactions(String uid) {
    return _firestore
        .collection('transactions')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
              .toList();
          // Sort by date descending on the client
          list.sort((a, b) => b.date.compareTo(a.date));
          // Limit to 50 most recent
          return list.take(50).toList();
        });
  }

  /// Delete a transaction
  Future<void> deleteTransaction(String transactionId) async {
    await _firestore.collection('transactions').doc(transactionId).delete();
  }
}
