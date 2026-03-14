import 'package:cloud_firestore/cloud_firestore.dart';

class PoolModel {
  final String id;
  final String name;
  final String description;
  final String inviteCode;
  final String ownerId;
  final List<String> members;
  final List<String> joinRequests;
  final DateTime createdAt;
  final double totalExpenses;

  PoolModel({
    required this.id,
    required this.name,
    required this.description,
    required this.inviteCode,
    required this.ownerId,
    required this.members,
    this.joinRequests = const [],
    required this.createdAt,
    this.totalExpenses = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'inviteCode': inviteCode,
      'ownerId': ownerId,
      'members': members,
      'createdAt': Timestamp.fromDate(createdAt),
      'totalExpenses': totalExpenses,
    };
  }

  factory PoolModel.fromMap(Map<String, dynamic> map, String id) {
    return PoolModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      inviteCode: map['inviteCode'] ?? '',
      ownerId: map['ownerId'] ?? '',
      members: List<String>.from(map['members'] ?? []),
      joinRequests: List<String>.from(map['joinRequests'] ?? []),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      totalExpenses: (map['totalExpenses'] ?? 0.0).toDouble(),
    );
  }
}
