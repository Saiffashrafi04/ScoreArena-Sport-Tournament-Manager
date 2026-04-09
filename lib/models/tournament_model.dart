class Tournament {
  final String? id; // Firestore document ID
  final String userId; // Creator's user ID
  final String name;
  final String sport;
  final int numberOfTeams;
  final DateTime createdAt;

  Tournament({
    this.id,
    required this.userId,
    required this.name,
    required this.sport,
    required this.numberOfTeams,
    required this.createdAt,
  });

  // Convert Tournament object to JSON (for saving to Firestore)
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'sport': sport,
      'numberOfTeams': numberOfTeams,
      'createdAt': createdAt,
    };
  }

  // Convert JSON from Firestore to Tournament object
  factory Tournament.fromJson(Map<String, dynamic> json, String documentId) {
    return Tournament(
      id: documentId,
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      sport: json['sport'] ?? '',
      numberOfTeams: json['numberOfTeams'] ?? 0,
      createdAt: (json['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }
}
