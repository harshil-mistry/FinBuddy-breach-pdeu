import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';
import '../models/pool_model.dart';
import '../models/shared_expense_model.dart';

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

  // ─── Pool Operations ───────────────────────────────────────────

  /// Create a new pool
  Future<String> createPool(PoolModel pool) async {
    final docRef = await _firestore.collection('pools').add(pool.toMap());
    return docRef.id;
  }

  /// Join a pool using an invite code
  Future<bool> joinPool(String inviteCode, String uid) async {
    final querySnapshot = await _firestore
        .collection('pools')
        .where('inviteCode', isEqualTo: inviteCode)
        .get();

    if (querySnapshot.docs.isEmpty) return false;

    final poolDoc = querySnapshot.docs.first;
    List<String> members = List<String>.from(poolDoc.data()['members'] ?? []);

    if (!members.contains(uid)) {
      members.add(uid);
      await poolDoc.reference.update({'members': members});
    }

    return true; // Successfully joined
  }

  /// Stream pools that the user is a member of
  Stream<List<PoolModel>> getPools(String uid) {
    return _firestore
        .collection('pools')
        .where('members', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => PoolModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Get a specific pool by ID
  Stream<PoolModel?> getPoolStream(String poolId) {
    return _firestore.collection('pools').doc(poolId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return PoolModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    });
  }
  
  Future<PoolModel?> getPoolById(String poolId) async {
    final doc = await _firestore.collection('pools').doc(poolId).get();
    if (!doc.exists) return null;
    return PoolModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  /// Add a shared expense and update pool total
  Future<void> addSharedExpense(SharedExpenseModel expense) async {
    final batch = _firestore.batch();
    
    // Add the expense
    final expenseRef = _firestore.collection('shared_expenses').doc();
    batch.set(expenseRef, expense.toMap());

    // Update the pool's total expenses
    final poolRef = _firestore.collection('pools').doc(expense.poolId);
    batch.update(poolRef, {
      'totalExpenses': FieldValue.increment(expense.amount),
    });

    await batch.commit();
  }

  /// Stream shared expenses for a specific pool
  Stream<List<SharedExpenseModel>> getSharedExpenses(String poolId) {
    return _firestore
        .collection('shared_expenses')
        .where('poolId', isEqualTo: poolId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => SharedExpenseModel.fromMap(doc.data(), doc.id))
          .toList();
      // Client-side sort to avoid composite index requirements
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }
}
