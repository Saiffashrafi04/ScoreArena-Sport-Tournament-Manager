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
  final int teamAScore;
  final int teamBScore;
  final int? teamAWickets;
  final int? teamBWickets;
  final String? teamAOvers;
  final String? teamBOvers;
  final String? winnerTeamId;
  final String? resultText;
  final String? cricketResultType;
  final int? cricketResultMargin;
  final DateTime? lastUpdatedAt;
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
    this.teamAScore = 0,
    this.teamBScore = 0,
    this.teamAWickets,
    this.teamBWickets,
    this.teamAOvers,
    this.teamBOvers,
    this.winnerTeamId,
    this.resultText,
    this.cricketResultType,
    this.cricketResultMargin,
    this.lastUpdatedAt,
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
      'teamAScore': teamAScore,
      'teamBScore': teamBScore,
      'teamAWickets': teamAWickets,
      'teamBWickets': teamBWickets,
      'teamAOvers': teamAOvers,
      'teamBOvers': teamBOvers,
      'winnerTeamId': winnerTeamId,
      'resultText': resultText,
      'cricketResultType': cricketResultType,
      'cricketResultMargin': cricketResultMargin,
      'lastUpdatedAt': lastUpdatedAt,
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

    int parseInt(dynamic value, {int fallback = 0}) {
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        return int.tryParse(value) ?? fallback;
      }
      return fallback;
    }

    int? parseNullableInt(dynamic value) {
      if (value == null) {
        return null;
      }
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        return int.tryParse(value);
      }
      return null;
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
      teamAScore: parseInt(json['teamAScore']),
      teamBScore: parseInt(json['teamBScore']),
      teamAWickets: parseNullableInt(json['teamAWickets']),
      teamBWickets: parseNullableInt(json['teamBWickets']),
      teamAOvers: json['teamAOvers']?.toString(),
      teamBOvers: json['teamBOvers']?.toString(),
      winnerTeamId: json['winnerTeamId']?.toString(),
      resultText: json['resultText']?.toString(),
      cricketResultType: json['cricketResultType']?.toString(),
      cricketResultMargin: parseNullableInt(json['cricketResultMargin']),
      lastUpdatedAt: json['lastUpdatedAt'] != null
          ? parseDate(json['lastUpdatedAt'])
          : null,
      scheduledAt: parseDate(json['scheduledAt']),
      createdAt: parseDate(json['createdAt']),
    );
  }
}
