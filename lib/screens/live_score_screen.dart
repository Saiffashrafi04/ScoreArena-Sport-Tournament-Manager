import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/match_model.dart';
import '../models/tournament_model.dart';

class LiveScoreScreen extends StatefulWidget {
  final Tournament tournament;
  final MatchModel match;

  const LiveScoreScreen({
    super.key,
    required this.tournament,
    required this.match,
  });

  @override
  State<LiveScoreScreen> createState() => _LiveScoreScreenState();
}

class _LiveScoreScreenState extends State<LiveScoreScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _teamAScoreController;
  late final TextEditingController _teamBScoreController;
  final _firestore = FirebaseFirestore.instance;

  String selectedStatus = 'live';
  bool isSaving = false;

  final List<String> statuses = ['live', 'completed'];

  @override
  void initState() {
    super.initState();
    _teamAScoreController =
        TextEditingController(text: widget.match.teamAScore.toString());
    _teamBScoreController =
        TextEditingController(text: widget.match.teamBScore.toString());
    selectedStatus = widget.match.status == 'completed' ? 'completed' : 'live';
  }

  @override
  void dispose() {
    _teamAScoreController.dispose();
    _teamBScoreController.dispose();
    super.dispose();
  }

  Future<void> _saveScores() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await _firestore
          .collection('tournaments')
          .doc(widget.tournament.id)
          .collection('matches')
          .doc(widget.match.id)
          .update({
        'teamAScore': int.parse(_teamAScoreController.text.trim()),
        'teamBScore': int.parse(_teamBScoreController.text.trim()),
        'status': selectedStatus,
        'lastUpdatedAt': DateTime.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Live score updated successfully! ✅'),
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

  String _winnerText() {
    if (widget.match.teamAScore > widget.match.teamBScore) {
      return '${widget.match.teamAName} is currently leading';
    }
    if (widget.match.teamBScore > widget.match.teamAScore) {
      return '${widget.match.teamBName} is currently leading';
    }
    return 'Scores are tied';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Score Entry'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.match.teamAName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'vs ${widget.match.teamBName}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('Venue: ${widget.match.venue}'),
                    Text(
                      'Scheduled: ${widget.match.scheduledAt.toLocal().toString().split('.').first}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _winnerText(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
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
                        'Update Live Scores',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _teamAScoreController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: '${widget.match.teamAName} Score',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter score';
                                }
                                if (int.tryParse(value.trim()) == null) {
                                  return 'Invalid';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _teamBScoreController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: '${widget.match.teamBName} Score',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter score';
                                }
                                if (int.tryParse(value.trim()) == null) {
                                  return 'Invalid';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: InputDecoration(
                          labelText: 'Match Status',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        items: statuses
                            .map(
                              (status) => DropdownMenuItem<String>(
                                value: status,
                                child: Text(status.toUpperCase()),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedStatus = value ?? 'live';
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isSaving ? null : _saveScores,
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
                              : const Text('Save Live Score'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
