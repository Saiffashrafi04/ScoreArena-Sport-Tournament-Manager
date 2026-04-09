import 'package:cloud_firestore/cloud_firestore.dart';

class MatchModel {
  final String? id;
  final String userId;
  final String teamAId;
  final String teamAName;
  final String teamBId;
  final String teamBName;
  final String venue;
  final String status;
  final DateTime scheduledAt;
  final DateTime createdAt;

  MatchModel({
    this.id,
    required this.userId,
    required this.teamAId,
    required this.teamAName,
    required this.teamBId,
    required this.teamBName,
    required this.venue,
    required this.status,
    required this.scheduledAt,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'teamAId': teamAId,
      'teamAName': teamAName,
      'teamBId': teamBId,
      'teamBName': teamBName,
      'venue': venue,
      'status': status,
      'scheduledAt': scheduledAt,
      'createdAt': createdAt,
    };
  }

  factory MatchModel.fromJson(Map<String, dynamic> json, String documentId) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) {
        return value;
      }
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return MatchModel(
      id: documentId,
      userId: json['userId'] ?? '',
      teamAId: json['teamAId'] ?? '',
      teamAName: json['teamAName'] ?? '',
      teamBId: json['teamBId'] ?? '',
      teamBName: json['teamBName'] ?? '',
      venue: json['venue'] ?? '',
      status: json['status'] ?? 'upcoming',
      scheduledAt: parseDate(json['scheduledAt']),
      createdAt: parseDate(json['createdAt']),
    );
  }
}
