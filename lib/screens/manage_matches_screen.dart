import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/match_model.dart';
import '../models/team_model.dart';
import '../models/tournament_model.dart';
import 'live_score_screen.dart';

class ManageMatchesScreen extends StatefulWidget {
  final Tournament tournament;
  final bool isViewer;

  const ManageMatchesScreen({
    super.key,
    required this.tournament,
    this.isViewer = false,
  });

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
  bool isScheduleSectionExpanded = true;

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

  String _pairKey(String teamAId, String teamBId) {
    final ids = [teamAId, teamBId]..sort();
    return '${ids[0]}__${ids[1]}';
  }

  Future<void> _generateRoundRobinFixtures(List<Team> teams) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please login again.')));
      return;
    }

    if (teams.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least 2 teams to generate fixtures.'),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final matchesRef = _firestore
          .collection('tournaments')
          .doc(widget.tournament.id)
          .collection('matches');

      final existingSnapshot = await matchesRef.get();
      final existingPairs = <String>{};

      for (final doc in existingSnapshot.docs) {
        final data = doc.data();
        final teamAId = (data['teamAId'] ?? '').toString();
        final teamBId = (data['teamBId'] ?? '').toString();
        if (teamAId.isNotEmpty && teamBId.isNotEmpty) {
          existingPairs.add(_pairKey(teamAId, teamBId));
        }
      }

      final now = DateTime.now();
      final defaultStart = DateTime(
        now.year,
        now.month,
        now.day,
        10,
        0,
      ).add(const Duration(days: 1));
      final startAt = selectedDateTime ?? defaultStart;
      final venue = _venueController.text.trim().isEmpty
          ? 'TBD'
          : _venueController.text.trim();

      final batch = _firestore.batch();
      var createdCount = 0;
      var skippedCount = 0;
      var slotIndex = 0;

      for (var i = 0; i < teams.length - 1; i++) {
        for (var j = i + 1; j < teams.length; j++) {
          final teamA = teams[i];
          final teamB = teams[j];
          final teamAId = teamA.id ?? '';
          final teamBId = teamB.id ?? '';

          if (teamAId.isEmpty || teamBId.isEmpty) {
            continue;
          }

          final key = _pairKey(teamAId, teamBId);
          if (existingPairs.contains(key)) {
            skippedCount++;
            continue;
          }

          final scheduledAt = startAt.add(Duration(days: slotIndex));
          slotIndex++;

          final match = MatchModel(
            userId: user.uid,
            teamAId: teamAId,
            teamAName: teamA.name,
            teamBId: teamBId,
            teamBName: teamB.name,
            venue: venue,
            status: 'upcoming',
            scheduledAt: scheduledAt,
            createdAt: DateTime.now(),
          );

          batch.set(matchesRef.doc(), match.toJson());
          existingPairs.add(key);
          createdCount++;
        }
      }

      if (createdCount > 0) {
        await batch.commit();
      }

      if (!mounted) {
        return;
      }

      if (createdCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No new fixtures generated. All pairings already exist.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Generated $createdCount fixtures${skippedCount > 0 ? ' ($skippedCount skipped existing)' : ''}.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating fixtures: ${e.toString()}'),
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

  Future<void> _generateKnockoutFixtures(List<Team> teams) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please login again.')));
      return;
    }

    if (teams.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least 2 teams to generate knockout fixtures.'),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final matchesRef = _firestore
          .collection('tournaments')
          .doc(widget.tournament.id)
          .collection('matches');

      final existingSnapshot = await matchesRef.get();
      final existingPairs = <String>{};
      for (final doc in existingSnapshot.docs) {
        final data = doc.data();
        final teamAId = (data['teamAId'] ?? '').toString();
        final teamBId = (data['teamBId'] ?? '').toString();
        if (teamAId.isNotEmpty && teamBId.isNotEmpty) {
          existingPairs.add(_pairKey(teamAId, teamBId));
        }
      }

      final now = DateTime.now();
      final defaultStart = DateTime(
        now.year,
        now.month,
        now.day,
        10,
        0,
      ).add(const Duration(days: 1));
      final startAt = selectedDateTime ?? defaultStart;
      final venue = _venueController.text.trim().isEmpty
          ? 'TBD'
          : _venueController.text.trim();

      final shuffledTeams = [...teams]..shuffle();
      final byeTeams = <String>[];

      final batch = _firestore.batch();
      var createdCount = 0;
      var skippedCount = 0;
      var slotIndex = 0;

      for (var i = 0; i < shuffledTeams.length; i += 2) {
        if (i + 1 >= shuffledTeams.length) {
          byeTeams.add(shuffledTeams[i].name);
          break;
        }

        final teamA = shuffledTeams[i];
        final teamB = shuffledTeams[i + 1];
        final teamAId = teamA.id ?? '';
        final teamBId = teamB.id ?? '';

        if (teamAId.isEmpty || teamBId.isEmpty) {
          continue;
        }

        final key = _pairKey(teamAId, teamBId);
        if (existingPairs.contains(key)) {
          skippedCount++;
          continue;
        }

        final scheduledAt = startAt.add(Duration(days: slotIndex));
        slotIndex++;

        final match = MatchModel(
          userId: user.uid,
          teamAId: teamAId,
          teamAName: teamA.name,
          teamBId: teamBId,
          teamBName: teamB.name,
          venue: venue,
          status: 'upcoming',
          scheduledAt: scheduledAt,
          createdAt: DateTime.now(),
        );

        batch.set(matchesRef.doc(), match.toJson());
        existingPairs.add(key);
        createdCount++;
      }

      if (createdCount > 0) {
        await batch.commit();
      }

      if (!mounted) {
        return;
      }

      if (createdCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No new knockout fixtures generated. Pairings already exist.',
            ),
          ),
        );
      } else {
        final byeMessage = byeTeams.isEmpty
            ? ''
            : ' Bye: ${byeTeams.join(', ')}.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Generated $createdCount knockout fixtures${skippedCount > 0 ? ' ($skippedCount skipped existing)' : ''}.$byeMessage',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error generating knockout fixtures: ${e.toString()}',
            ),
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

  Future<void> _showFixtureGeneratorOptions(List<Team> teams) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.grid_on),
              title: const Text('Round Robin'),
              subtitle: const Text('Each team plays every other team once'),
              onTap: () => Navigator.pop(context, 'round_robin'),
            ),
            ListTile(
              leading: const Icon(Icons.account_tree_outlined),
              title: const Text('Knockout (Single Elimination)'),
              subtitle: const Text('Round 1 fixtures with random pairings'),
              onTap: () => Navigator.pop(context, 'knockout'),
            ),
          ],
        ),
      ),
    );

    if (choice == 'round_robin') {
      await _generateRoundRobinFixtures(teams);
    } else if (choice == 'knockout') {
      await _generateKnockoutFixtures(teams);
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
                // Show match creation form only for organizers
                if (!widget.isViewer)
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
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Schedule Match',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      isScheduleSectionExpanded =
                                          !isScheduleSectionExpanded;
                                    });
                                  },
                                  icon: Icon(
                                    isScheduleSectionExpanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                  ),
                                  label: Text(
                                    isScheduleSectionExpanded
                                        ? 'Minimize'
                                        : 'Expand',
                                  ),
                                ),
                              ],
                            ),
                            if (isScheduleSectionExpanded) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: isSaving || teams.length < 2
                                      ? null
                                      : () =>
                                            _showFixtureGeneratorOptions(teams),
                                  icon: const Icon(Icons.auto_awesome),
                                  label: const Text('Auto-Generate Fixtures'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tip: set date/time and venue first to use as default for generated matches.',
                                style: Theme.of(context).textTheme.bodySmall,
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
                            ] else ...[
                              const SizedBox(height: 8),
                              Text(
                                'Schedule panel minimized. Tap Expand to create or auto-generate fixtures.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                // Viewer-only info message
                if (widget.isViewer)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: const [
                            Icon(Icons.info_outline, color: Colors.blue),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'You are viewing matches as a viewer. Only organizers can schedule matches.',
                                style: TextStyle(color: Colors.blue),
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
                                  if (widget.tournament.sport
                                          .toLowerCase()
                                          .trim() ==
                                      'cricket') ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Scores: ${match.teamAName} ${match.teamAScore}${match.teamAWickets != null ? '/${match.teamAWickets}' : ''}${match.teamAOvers != null ? ' (${match.teamAOvers} overs)' : ''} | ${match.teamBName} ${match.teamBScore}${match.teamBWickets != null ? '/${match.teamBWickets}' : ''}${match.teamBOvers != null ? ' (${match.teamBOvers} overs)' : ''}',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
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
                                  if ((match.resultText ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Result: ${match.resultText}',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: widget.isViewer
                                  ? const Icon(
                                      Icons.visibility,
                                      color: Colors.grey,
                                      size: 20,
                                    )
                                  : PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (match.id == null) {
                                          return;
                                        }

                                        if (value == 'live-score') {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  LiveScoreScreen(
                                                    tournament:
                                                        widget.tournament,
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
