import 'package:cloud_firestore/cloud_firestore.dart';

class Player {
  final String? id;
  final String userId;
  final String name;
  final String role;
  final int jerseyNumber;
  final DateTime createdAt;

  Player({
    this.id,
    required this.userId,
    required this.name,
    required this.role,
    required this.jerseyNumber,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'role': role,
      'jerseyNumber': jerseyNumber,
      'createdAt': createdAt,
    };
  }

  factory Player.fromJson(Map<String, dynamic> json, String documentId) {
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

    return Player(
      id: documentId,
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? 'Player',
      jerseyNumber: json['jerseyNumber'] ?? 0,
      createdAt: parsedCreatedAt,
    );
  }
}
