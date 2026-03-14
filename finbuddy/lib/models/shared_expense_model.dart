import 'package:cloud_firestore/cloud_firestore.dart';

class SharedExpenseModel {
  final String id;
  final String poolId;
  final String description;
  final double amount;
  final String paidBy; // uid of the person who paid
  final DateTime date;
  final Map<String, double> splits; // uid -> exact amount owed

  SharedExpenseModel({
    required this.id,
    required this.poolId,
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.date,
    required this.splits,
  });

  Map<String, dynamic> toMap() {
    return {
      'poolId': poolId,
      'description': description,
      'amount': amount,
      'paidBy': paidBy,
      'date': Timestamp.fromDate(date),
      'splits': splits,
    };
  }

  factory SharedExpenseModel.fromMap(Map<String, dynamic> map, String id) {
    return SharedExpenseModel(
      id: id,
      poolId: map['poolId'] ?? '',
      description: map['description'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      paidBy: map['paidBy'] ?? '',
      date: map['date'] != null
          ? (map['date'] as Timestamp).toDate()
          : DateTime.now(),
      splits: Map<String, double>.from(
          (map['splits'] as Map?)?.map((k, v) => MapEntry(k, (v as num).toDouble())) ?? {}),
    );
  }
}
