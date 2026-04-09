import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tournament_model.dart';
import '../models/match_model.dart';
import '../models/team_standing_model.dart';

class LeaderboardScreen extends StatefulWidget {
  final Tournament tournament;

  const LeaderboardScreen({
    super.key,
    required this.tournament,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _firestore = FirebaseFirestore.instance;

  /// Calculate standings from completed matches
  Future<List<TeamStanding>> _calculateStandings() async {
    try {
      // Query all completed matches for this tournament
      final matchesSnapshot = await _firestore
          .collection('tournaments')
          .doc(widget.tournament.id)
          .collection('matches')
          .where('status', isEqualTo: 'completed')
          .get();

      // Map to store team records {teamId: {wins, losses, ties}}
      final teamRecords = <String, Map<String, dynamic>>{};

      // Process each completed match
      for (final doc in matchesSnapshot.docs) {
        final match = MatchModel.fromJson(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );

        // Initialize team records if not exists
        if (!teamRecords.containsKey(match.teamAId)) {
          teamRecords[match.teamAId] = {
            'name': match.teamAName,
            'wins': 0,
            'losses': 0,
            'ties': 0,
          };
        }
        if (!teamRecords.containsKey(match.teamBId)) {
          teamRecords[match.teamBId] = {
            'name': match.teamBName,
            'wins': 0,
            'losses': 0,
            'ties': 0,
          };
        }

        // Determine winner and update records
        if (match.teamAScore > match.teamBScore) {
          // Team A wins
          teamRecords[match.teamAId]!['wins']++;
          teamRecords[match.teamBId]!['losses']++;
        } else if (match.teamBScore > match.teamAScore) {
          // Team B wins
          teamRecords[match.teamBId]!['wins']++;
          teamRecords[match.teamAId]!['losses']++;
        } else {
          // Tie
          teamRecords[match.teamAId]!['ties']++;
          teamRecords[match.teamBId]!['ties']++;
        }
      }

      // Convert to TeamStanding objects
      final standings = <TeamStanding>[];
      teamRecords.forEach((teamId, record) {
        final wins = record['wins'] as int;
        final losses = record['losses'] as int;
        final ties = record['ties'] as int;
        final totalMatches = wins + losses + ties;
        final winRatio = totalMatches > 0 ? wins / totalMatches : 0.0;

        standings.add(
          TeamStanding(
            teamId: teamId,
            teamName: record['name'],
            wins: wins,
            losses: losses,
            ties: ties,
            totalMatches: totalMatches,
            winRatio: winRatio,
          ),
        );
      });

      // Sort by wins (descending), then by win ratio (descending), then by ties (descending)
      standings.sort((a, b) {
        if (a.wins != b.wins) {
          return b.wins.compareTo(a.wins);
        }
        if (a.winRatio != b.winRatio) {
          return b.winRatio.compareTo(a.winRatio);
        }
        return b.ties.compareTo(a.ties);
      });

      return standings;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Leaderboard"),
        elevation: 0,
      ),
      body: FutureBuilder<List<TeamStanding>>(
        future: _calculateStandings(),
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error state
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Error loading leaderboard: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // No data or empty standings
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 20),
                  Text(
                    "No completed matches yet",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Leaderboard will appear once matches are completed.",
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final standings = snapshot.data!;

          return Column(
            children: [
              // Tournament header
              Container(
                width: double.infinity,
                color: Colors.blue.shade50,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.tournament.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Sport: ${widget.tournament.sport}",
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // Standings list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: standings.length,
                  itemBuilder: (context, index) {
                    final standing = standings[index];
                    final rank = index + 1;

                    // Determine rank color and medal
                    Color rankColor = Colors.grey;
                    IconData rankMedal = Icons.circle;

                    if (rank == 1) {
                      rankColor = Colors.amber;
                      rankMedal = Icons.emoji_events;
                    } else if (rank == 2) {
                      rankColor = Colors.grey[400]!;
                      rankMedal = Icons.emoji_events;
                    } else if (rank == 3) {
                      rankColor = Colors.orange[700]!;
                      rankMedal = Icons.emoji_events;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: rank <= 3
                              ? Border(
                                  left: BorderSide(
                                    color: rankColor,
                                    width: 4,
                                  ),
                                )
                              : null,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          leading: Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                              color: rankColor,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: rank <= 3
                                  ? Icon(
                                      rankMedal,
                                      color: Colors.white,
                                      size: 24,
                                    )
                                  : Text(
                                      '$rank',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                            ),
                          ),
                          title: Text(
                            standing.teamName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              Chip(
                                label: Text(
                                  'W: ${standing.wins}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                                backgroundColor: Colors.green,
                                visualDensity: VisualDensity.compact,
                              ),
                              const SizedBox(width: 6),
                              Chip(
                                label: Text(
                                  'L: ${standing.losses}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                                backgroundColor: Colors.red,
                                visualDensity: VisualDensity.compact,
                              ),
                              const SizedBox(width: 6),
                              Chip(
                                label: Text(
                                  'T: ${standing.ties}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                                backgroundColor: Colors.orange,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${(standing.winRatio * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${standing.totalMatches} matches',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
