import 'package:cloud_firestore/cloud_firestore.dart';

class Team {
  final String? id;
  final String userId;
  final String name;
  final String captainName;
  final DateTime createdAt;

  Team({
    this.id,
    required this.userId,
    required this.name,
    required this.captainName,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'captainName': captainName,
      'createdAt': createdAt,
    };
  }

  factory Team.fromJson(Map<String, dynamic> json, String documentId) {
    final createdAtRaw = json['createdAt'];
    DateTime parsedCreatedAt;

    if (createdAtRaw is DateTime) {
      parsedCreatedAt = createdAtRaw;
    } else if (createdAtRaw is Timestamp) {
      parsedCreatedAt = createdAtRaw.toDate();
    } else if (createdAtRaw is String) {
      parsedCreatedAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return Team(
      id: documentId,
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      captainName: json['captainName'] ?? '',
      createdAt: parsedCreatedAt,
    );
  }
}
