import 'package:cloud_firestore/cloud_firestore.dart';

class RecurringIncome {
  final String source;
  final double amount;
  final int dayOfMonth;

  RecurringIncome({
    required this.source,
    required this.amount,
    required this.dayOfMonth,
  });

  Map<String, dynamic> toMap() {
    return {
      'source': source,
      'amount': amount,
      'dayOfMonth': dayOfMonth,
    };
  }

  factory RecurringIncome.fromMap(Map<String, dynamic> map) {
    return RecurringIncome(
      source: map['source'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      dayOfMonth: map['dayOfMonth'] ?? 1,
    );
  }
}

class RecurringExpense {
  final String name;
  final double amount;
  final String tag;
  final int dayOfMonth;

  RecurringExpense({
    required this.name,
    required this.amount,
    required this.tag,
    required this.dayOfMonth,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
      'tag': tag,
      'dayOfMonth': dayOfMonth,
    };
  }

  factory RecurringExpense.fromMap(Map<String, dynamic> map) {
    return RecurringExpense(
      name: map['name'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      tag: map['tag'] ?? 'Need',
      dayOfMonth: map['dayOfMonth'] ?? 1,
    );
  }
}

class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String photoUrl;
  final String upiId;
  final List<RecurringIncome> recurringIncomes;
  final List<RecurringExpense> recurringExpenses;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    this.upiId = '',
    this.recurringIncomes = const [],
    this.recurringExpenses = const [],
    this.createdAt,
    this.lastLogin,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'upiId': upiId,
      'recurringIncomes': recurringIncomes.map((x) => x.toMap()).toList(),
      'recurringExpenses': recurringExpenses.map((x) => x.toMap()).toList(),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : FieldValue.serverTimestamp(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      uid: id,
      displayName: map['displayName'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      upiId: map['upiId'] ?? '',
      recurringIncomes: map['recurringIncomes'] != null
          ? List<RecurringIncome>.from(map['recurringIncomes']?.map((x) => RecurringIncome.fromMap(x)))
          : [],
      recurringExpenses: map['recurringExpenses'] != null
          ? List<RecurringExpense>.from(map['recurringExpenses']?.map((x) => RecurringExpense.fromMap(x)))
          : [],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      lastLogin: (map['lastLogin'] as Timestamp?)?.toDate(),
    );
  }
}
