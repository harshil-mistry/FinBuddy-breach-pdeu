import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String toUid;
  final String fromUid;
  final String poolId;
  final double amount;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.toUid,
    required this.fromUid,
    required this.poolId,
    required this.amount,
    required this.type,
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'toUid': toUid,
      'fromUid': fromUid,
      'poolId': poolId,
      'amount': amount,
      'type': type,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      toUid: map['toUid'] ?? '',
      fromUid: map['fromUid'] ?? '',
      poolId: map['poolId'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      type: map['type'] ?? 'nudge',
      isRead: map['isRead'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
