import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tournament_model.dart';
import 'edit_tournament_screen.dart';
import 'manage_matches_screen.dart';
import 'manage_teams_screen.dart';
import 'leaderboard_screen.dart';

class TournamentsListScreen extends StatefulWidget {
  const TournamentsListScreen({super.key});

  @override
  State<TournamentsListScreen> createState() => _TournamentsListScreenState();
}

class _TournamentsListScreenState extends State<TournamentsListScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String _friendlyFirestoreError(Object error) {
    final message = error.toString();
    if (message.contains('failed-precondition')) {
      return 'Firestore index is missing for this query. Please create the index from Firebase Console, or refresh after simplifying query.';
    }
    if (message.contains('permission-denied')) {
      return 'Permission denied by Firestore rules. Please update rules to allow logged-in users to read their tournaments.';
    }
    return message;
  }

  // Function to delete tournament
  Future<void> deleteTournament(String tournamentId) async {
    try {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Delete Tournament?"),
          content: const Text(
            "Are you sure you want to delete this tournament? This action cannot be undone.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                await _firestore
                    .collection('tournaments')
                    .doc(tournamentId)
                    .delete();

                Navigator.pop(context);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tournament deleted successfully! ✅'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("My Tournaments"), elevation: 0),
        body: const Center(
          child: Text('Please login again to view tournaments.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("My Tournaments"), elevation: 0),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('tournaments')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error state
          if (snapshot.hasError && !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _friendlyFirestoreError(snapshot.error!),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // Empty state
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sports, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 20),
                  Text(
                    "No tournaments yet",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Create your first tournament to get started!",
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Create Tournament"),
                  ),
                ],
              ),
            );
          }

          // List of tournaments
          final tournaments = [...snapshot.data!.docs]
            ..sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;

              final aCreated = Tournament.fromJson(aData, a.id).createdAt;
              final bCreated = Tournament.fromJson(bData, b.id).createdAt;

              return bCreated.compareTo(aCreated);
            });

          return Column(
            children: [
              if (snapshot.hasError)
                Container(
                  width: double.infinity,
                  color: Colors.amber.shade100,
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    _friendlyFirestoreError(snapshot.error!),
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: tournaments.length,
                  itemBuilder: (context, index) {
                    final doc = tournaments[index];
                    final tournament = Tournament.fromJson(
                      doc.data() as Map<String, dynamic>,
                      doc.id,
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(15),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.sports,
                            color: Colors.blue,
                            size: 28,
                          ),
                        ),
                        title: Text(
                          tournament.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text(
                              "Sport: ${tournament.sport}",
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              "Teams: ${tournament.numberOfTeams}",
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              "Created: ${tournament.createdAt.toLocal().toString().split('.')[0]}",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'manage-matches') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ManageMatchesScreen(
                                    tournament: tournament,
                                  ),
                                ),
                              );
                            } else if (value == 'manage-teams') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ManageTeamsScreen(tournament: tournament),
                                ),
                              );
                            } else if (value == 'leaderboard') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      LeaderboardScreen(tournament: tournament),
                                ),
                              );
                            } else if (value == 'edit') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditTournamentScreen(
                                    tournament: tournament,
                                  ),
                                ),
                              );
                            } else if (value == 'delete' &&
                                tournament.id != null) {
                              deleteTournament(tournament.id!);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem<String>(
                              value: 'manage-matches',
                              child: Text("Schedule Matches"),
                            ),
                            PopupMenuItem<String>(
                              value: 'manage-teams',
                              child: Text("Manage Teams"),
                            ),
                            PopupMenuItem<String>(
                              value: 'leaderboard',
                              child: Text("View Leaderboard"),
                            ),
                            PopupMenuItem<String>(
                              value: 'edit',
                              child: Text("Edit"),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Text(
                                "Delete",
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Tournament Details"),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Name: ${tournament.name}"),
                                  const SizedBox(height: 8),
                                  Text("Sport: ${tournament.sport}"),
                                  const SizedBox(height: 8),
                                  Text("Teams: ${tournament.numberOfTeams}"),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Created: ${tournament.createdAt.toLocal().toString().split('.')[0]}",
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("Close"),
                                ),
                              ],
                            ),
                          );
                        },
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
