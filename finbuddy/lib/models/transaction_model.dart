import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String uid;
  final String description;
  final double amount;
  final String category;
  final String tag; // 'Need' or 'Want'
  final String type; // 'expense', 'income', 'savings', 'investment'
  final String? poolId;
  final DateTime date;
  final DateTime? createdAt;

  TransactionModel({
    required this.id,
    required this.uid,
    required this.description,
    required this.amount,
    required this.category,
    required this.tag,
    required this.type,
    this.poolId,
    required this.date,
    this.createdAt,
  });

  // Auto-tagging logic: categories mapped to Need or Want
  static const Map<String, String> categoryTags = {
    // Needs
    'Rent': 'Need',
    'Groceries': 'Need',
    'Utilities': 'Need',
    'Transport': 'Need',
    'Healthcare': 'Need',
    'Insurance': 'Need',
    'Education': 'Need',
    'Phone/Internet': 'Need',
    'EMI/Loan': 'Need',
    'Settlements': 'Need',
    // Wants
    'Food & Dining': 'Want',
    'Shopping': 'Want',
    'Entertainment': 'Want',
    'Travel': 'Want',
    'Subscriptions': 'Want',
    'Personal Care': 'Want',
    'Gifts': 'Want',
    'Other': 'Want',
  };

  static String getTagForCategory(String category) {
    return categoryTags[category] ?? 'Want';
  }

  static List<String> get allCategories => categoryTags.keys.toList();

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'description': description,
      'amount': amount,
      'category': category,
      'tag': tag,
      'type': type,
      'poolId': poolId,
      'date': Timestamp.fromDate(date),
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map, String id) {
    return TransactionModel(
      id: id,
      uid: map['uid'] ?? '',
      description: map['description'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? '',
      tag: map['tag'] ?? 'Want',
      type: map['type'] ?? 'expense',
      poolId: map['poolId'],
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
