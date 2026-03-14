import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';
import '../models/pool_model.dart';
import '../models/shared_expense_model.dart';
import '../models/notification_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> completeOnboarding({
    required String uid,
    required String displayName,
    required String upiId,
    required List<RecurringIncome> incomes,
    required List<RecurringExpense> expenses,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'displayName': displayName,
      'upiId': upiId,
      'isSetupComplete': true,
      'recurringIncomes': incomes.map((e) => e.toMap()).toList(),
      'recurringExpenses': expenses.map((e) => e.toMap()).toList(),
    });
  }

  /// Update user profile
  Future<void> updateUserProfile({
    required String uid,
    required String displayName,
    required String upiId,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'displayName': displayName,
      'upiId': upiId,
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

  /// Request to join a pool — adds uid to `joinRequests` list (pending admin approval)
  /// Returns: 'ok' if request sent, 'already_member' if already in, 'not_found' if code invalid
  Future<String> requestToJoinPool(String inviteCode, String uid) async {
    final querySnapshot = await _firestore
        .collection('pools')
        .where('inviteCode', isEqualTo: inviteCode)
        .get();

    if (querySnapshot.docs.isEmpty) return 'not_found';

    final poolDoc = querySnapshot.docs.first;
    final data = poolDoc.data();
    final List<String> members = List<String>.from(data['members'] ?? []);
    final List<String> requests = List<String>.from(data['joinRequests'] ?? []);

    if (members.contains(uid)) return 'already_member';
    if (requests.contains(uid)) return 'ok'; // already requested

    await poolDoc.reference.update({
      'joinRequests': FieldValue.arrayUnion([uid]),
    });

    return 'ok';
  }

  /// Admin approves a join request
  Future<void> approveJoinRequest(String poolId, String uid) async {
    await _firestore.collection('pools').doc(poolId).update({
      'joinRequests': FieldValue.arrayRemove([uid]),
      'members': FieldValue.arrayUnion([uid]),
    });
  }

  /// Admin denies/dismisses a join request
  Future<void> denyJoinRequest(String poolId, String uid) async {
    await _firestore.collection('pools').doc(poolId).update({
      'joinRequests': FieldValue.arrayRemove([uid]),
    });
  }

  /// Admin kicks a member out of the pool
  Future<void> kickMember(String poolId, String uid) async {
    await _firestore.collection('pools').doc(poolId).update({
      'members': FieldValue.arrayRemove([uid]),
    });
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

    // Trigger Notifications
    try {
      final pool = await getPoolById(expense.poolId);
      final senderUser = await getUser(expense.paidBy);
      if (pool != null && senderUser != null) {
        for (String memberId in pool.members) {
          // Don't send a notification to the person who just added the expense
          if (memberId == expense.paidBy) continue;
          
          final targetUser = await getUser(memberId);
          if (targetUser == null) continue;
          
          // 1. Create In-App Notification Doc
          final docRef = _firestore.collection('notifications').doc();
          final notification = NotificationModel(
            id: docRef.id,
            toUid: memberId,
            fromUid: expense.paidBy,
            poolId: pool.id,
            amount: expense.amount,
            type: 'new_expense',
            isRead: false,
            createdAt: DateTime.now(),
          );
          await docRef.set(notification.toMap());

          // 2. Trigger Node FCM Server
          if (targetUser.fcmToken != null) {
            final url = Uri.parse('https://finbuddy-breach-pdeu.onrender.com/api/send-expense-notification');
            try {
              await http.post(
                url,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'fcmToken': targetUser.fcmToken,
                  'adderName': senderUser.displayName.isNotEmpty ? senderUser.displayName : 'Someone',
                  'amount': expense.amount,
                  'groupName': pool.name,
                }),
              );
            } catch (e) {
              // Ignore failure for one member
            }
          }
        }
      }
    } catch (e) {
      // Ignore background notification failure
    }
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

  /// Delete a shared expense and subtract from pool total
  Future<void> deleteSharedExpense(SharedExpenseModel expense) async {
    final batch = _firestore.batch();

    // Delete the expense doc
    final expenseRef = _firestore.collection('shared_expenses').doc(expense.id);
    batch.delete(expenseRef);

    // Subtract the amount from pool total (won't go below 0)
    final poolRef = _firestore.collection('pools').doc(expense.poolId);
    batch.update(poolRef, {
      'totalExpenses': FieldValue.increment(-expense.amount),
    });

    await batch.commit();
  }

  /// Leave a pool — removes the user from members list. Existing debts stay intact.
  Future<void> leavePool(String poolId, String uid) async {
    await _firestore.collection('pools').doc(poolId).update({
      'members': FieldValue.arrayRemove([uid]),
    });
  }

  /// Delete an entire pool and all its shared expenses (admin only).
  Future<void> deletePool(String poolId) async {
    // Delete all shared expenses for this pool first
    final expensesSnapshot = await _firestore
        .collection('shared_expenses')
        .where('poolId', isEqualTo: poolId)
        .get();

    final batch = _firestore.batch();
    for (final doc in expensesSnapshot.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_firestore.collection('pools').doc(poolId));
    await batch.commit();
  }

  // ─── Notifications & Nudges ──────────────────────────────────────

  /// Send a nudge (payment reminder) from creditor to debtor
  Future<void> sendNudge({
    required String fromUid,
    required String toUid,
    required String poolId,
    required double amount,
  }) async {
    // Check if an unread nudge already exists for this exact scenario
    final existingQuery = await _firestore
        .collection('notifications')
        .where('fromUid', isEqualTo: fromUid)
        .where('toUid', isEqualTo: toUid)
        .where('poolId', isEqualTo: poolId)
        .where('type', isEqualTo: 'nudge')
        .where('isRead', isEqualTo: false)
        .get();

    if (existingQuery.docs.isNotEmpty) {
      throw Exception('You have already nudged this person. Wait for them to respond.');
    }

    final docRef = _firestore.collection('notifications').doc();
    final notification = NotificationModel(
      id: docRef.id,
      toUid: toUid,
      fromUid: fromUid,
      poolId: poolId,
      amount: amount,
      type: 'nudge',
      isRead: false,
      createdAt: DateTime.now(),
    );

    await docRef.set(notification.toMap());

    // Trigger actual push notification via our Node js server using the target's FCM token
    final targetUser = await getUser(toUid);
    final senderUser = await getUser(fromUid);

    if (targetUser?.fcmToken != null) {
      final url = Uri.parse('https://finbuddy-breach-pdeu.onrender.com/api/send-nudge');
      try {
        await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'fcmToken': targetUser!.fcmToken,
            'senderName': senderUser?.displayName ?? 'Someone',
            'amount': amount,
          }),
        );
      } catch (e) {
        // We catch here so the base nudge still completes in Firestore even if the server is down
        print('Error sending FCM push HTTP request: $e');
      }
    }
  }

  /// Get stream of notifications for a user
  Stream<List<NotificationModel>> getNotifications(String uid) {
    return _firestore
        .collection('notifications')
        .where('toUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
  }
}

