import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/match_model.dart';
import '../models/team_model.dart';
import '../models/tournament_model.dart';
import 'live_score_screen.dart';

class ManageMatchesScreen extends StatefulWidget {
  final Tournament tournament;

  const ManageMatchesScreen({super.key, required this.tournament});

  @override
  State<ManageMatchesScreen> createState() => _ManageMatchesScreenState();
}

class _ManageMatchesScreenState extends State<ManageMatchesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _venueController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Team? selectedTeamA;
  Team? selectedTeamB;
  DateTime? selectedDateTime;
  bool isSaving = false;

  @override
  void dispose() {
    _venueController.dispose();
    super.dispose();
  }

  String _friendlyFirestoreError(Object error) {
    final message = error.toString();
    if (message.contains('permission-denied')) {
      return 'Firestore rules are blocking match access. Add nested rules for matches.';
    }
    return message;
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
      initialDate: selectedDateTime ?? now,
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selectedDateTime ?? now),
    );

    if (pickedTime == null) {
      return;
    }

    setState(() {
      selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _scheduleMatch() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please login again.')));
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedTeamA == null || selectedTeamB == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both teams.')),
      );
      return;
    }

    if (selectedTeamA!.id == selectedTeamB!.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team A and Team B must be different.')),
      );
      return;
    }

    if (selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose match date and time.')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final match = MatchModel(
        userId: user.uid,
        teamAId: selectedTeamA!.id ?? '',
        teamAName: selectedTeamA!.name,
        teamBId: selectedTeamB!.id ?? '',
        teamBName: selectedTeamB!.name,
        venue: _venueController.text.trim(),
        status: 'upcoming',
        scheduledAt: selectedDateTime!,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('tournaments')
          .doc(widget.tournament.id)
          .collection('matches')
          .add(match.toJson());

      _venueController.clear();
      setState(() {
        selectedTeamA = null;
        selectedTeamB = null;
        selectedDateTime = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Match scheduled successfully! ✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteMatch(String matchId) async {
    try {
      await _firestore
          .collection('tournaments')
          .doc(widget.tournament.id)
          .collection('matches')
          .doc(matchId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Match deleted successfully! ✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
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

  Future<void> _updateStatus(String matchId, String newStatus) async {
    try {
      await _firestore
          .collection('tournaments')
          .doc(widget.tournament.id)
          .collection('matches')
          .doc(matchId)
          .update({'status': newStatus});
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

  Color _statusColor(String status) {
    if (status == 'live') {
      return Colors.red;
    }
    if (status == 'completed') {
      return Colors.green;
    }
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.tournament.name)),
        body: const Center(
          child: Text('Please login again to manage matches.'),
        ),
      );
    }

    final teamsStream = _firestore
        .collection('tournaments')
        .doc(widget.tournament.id)
        .collection('teams')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text('Matches - ${widget.tournament.name}'),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: teamsStream,
        builder: (context, teamSnapshot) {
          if (teamSnapshot.connectionState == ConnectionState.waiting &&
              !teamSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (teamSnapshot.hasError && !teamSnapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _friendlyFirestoreError(teamSnapshot.error!),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final teams = (teamSnapshot.data?.docs ?? [])
              .map(
                (doc) =>
                    Team.fromJson(doc.data() as Map<String, dynamic>, doc.id),
              )
              .toList();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Schedule Match',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          if (teams.length < 2)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 10),
                              child: Text(
                                'Add at least 2 teams first to schedule matches.',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          DropdownButtonFormField<String>(
                            value: selectedTeamA?.id,
                            decoration: InputDecoration(
                              labelText: 'Team A',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              prefixIcon: const Icon(Icons.shield),
                            ),
                            items: teams
                                .map(
                                  (team) => DropdownMenuItem<String>(
                                    value: team.id,
                                    child: Text(team.name),
                                  ),
                                )
                                .toList(),
                            onChanged: teams.length < 2
                                ? null
                                : (value) {
                                    setState(() {
                                      selectedTeamA = teams.firstWhere(
                                        (team) => team.id == value,
                                      );
                                    });
                                  },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: selectedTeamB?.id,
                            decoration: InputDecoration(
                              labelText: 'Team B',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              prefixIcon: const Icon(Icons.shield_outlined),
                            ),
                            items: teams
                                .map(
                                  (team) => DropdownMenuItem<String>(
                                    value: team.id,
                                    child: Text(team.name),
                                  ),
                                )
                                .toList(),
                            onChanged: teams.length < 2
                                ? null
                                : (value) {
                                    setState(() {
                                      selectedTeamB = teams.firstWhere(
                                        (team) => team.id == value,
                                      );
                                    });
                                  },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _venueController,
                            decoration: InputDecoration(
                              labelText: 'Venue',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              prefixIcon: const Icon(Icons.location_on),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter venue';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: teams.length < 2
                                  ? null
                                  : _pickDateTime,
                              icon: const Icon(Icons.calendar_month),
                              label: Text(
                                selectedDateTime == null
                                    ? 'Choose Match Date & Time'
                                    : selectedDateTime!
                                          .toLocal()
                                          .toString()
                                          .split('.')
                                          .first,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: (isSaving || teams.length < 2)
                                  ? null
                                  : _scheduleMatch,
                              child: isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text('Schedule Match'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('tournaments')
                        .doc(widget.tournament.id)
                        .collection('matches')
                        .snapshots(),
                    builder: (context, matchSnapshot) {
                      if (matchSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          !matchSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (matchSnapshot.hasError && !matchSnapshot.hasData) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _friendlyFirestoreError(matchSnapshot.error!),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      if (!matchSnapshot.hasData ||
                          matchSnapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_note,
                                size: 80,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No matches scheduled',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                        );
                      }

                      final matches = [...matchSnapshot.data!.docs]
                        ..sort((a, b) {
                          final aData = a.data() as Map<String, dynamic>;
                          final bData = b.data() as Map<String, dynamic>;
                          final aTime = MatchModel.fromJson(
                            aData,
                            a.id,
                          ).scheduledAt;
                          final bTime = MatchModel.fromJson(
                            bData,
                            b.id,
                          ).scheduledAt;
                          return aTime.compareTo(bTime);
                        });

                      return ListView.builder(
                        itemCount: matches.length,
                        itemBuilder: (context, index) {
                          final doc = matches[index];
                          final match = MatchModel.fromJson(
                            doc.data() as Map<String, dynamic>,
                            doc.id,
                          );

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(
                                '${match.teamAName} vs ${match.teamBName}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Venue: ${match.venue}'),
                                  Text(
                                    'When: ${match.scheduledAt.toLocal().toString().split('.').first}',
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _statusColor(match.status),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      match.status.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (match.id == null) {
                                    return;
                                  }

                                  if (value == 'live-score') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => LiveScoreScreen(
                                          tournament: widget.tournament,
                                          match: match,
                                        ),
                                      ),
                                    );
                                  } else if (value == 'upcoming' ||
                                      value == 'live' ||
                                      value == 'completed') {
                                    _updateStatus(match.id!, value);
                                  } else if (value == 'delete') {
                                    _deleteMatch(match.id!);
                                  }
                                },
                                itemBuilder: (context) => const [
                                    PopupMenuItem<String>(
                                      value: 'live-score',
                                      child: Text('Live Score Entry'),
                                    ),
                                  PopupMenuItem<String>(
                                    value: 'upcoming',
                                    child: Text('Set Upcoming'),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'live',
                                    child: Text('Set Live'),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'completed',
                                    child: Text('Set Completed'),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
