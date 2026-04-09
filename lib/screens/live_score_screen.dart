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
  final _firestore = FirebaseFirestore.instance;

  late final TextEditingController _teamAScoreController;
  late final TextEditingController _teamBScoreController;
  late final TextEditingController _teamAWicketsController;
  late final TextEditingController _teamBWicketsController;
  late final TextEditingController _teamAOversController;
  late final TextEditingController _teamBOversController;
  late final TextEditingController _resultMarginController;

  String selectedStatus = 'live';
  String selectedWinner = 'teamA';
  String selectedCricketResultType = 'runs';
  bool isSaving = false;

  List<String> get statuses => const ['live', 'completed'];

  bool get _isCricket =>
      widget.tournament.sport.toLowerCase().trim() == 'cricket';

  @override
  void initState() {
    super.initState();
    _teamAScoreController = TextEditingController(
      text: widget.match.teamAScore.toString(),
    );
    _teamBScoreController = TextEditingController(
      text: widget.match.teamBScore.toString(),
    );
    _teamAWicketsController = TextEditingController(
      text: widget.match.teamAWickets?.toString() ?? '',
    );
    _teamBWicketsController = TextEditingController(
      text: widget.match.teamBWickets?.toString() ?? '',
    );
    _teamAOversController = TextEditingController(
      text: widget.match.teamAOvers ?? '',
    );
    _teamBOversController = TextEditingController(
      text: widget.match.teamBOvers ?? '',
    );
    _resultMarginController = TextEditingController(
      text: widget.match.cricketResultMargin?.toString() ?? '',
    );

    selectedStatus = widget.match.status == 'completed' ? 'completed' : 'live';

    if (widget.match.winnerTeamId == widget.match.teamAId) {
      selectedWinner = 'teamA';
    } else if (widget.match.winnerTeamId == widget.match.teamBId) {
      selectedWinner = 'teamB';
    } else {
      final result = (widget.match.resultText ?? '').toLowerCase();
      if (result.contains('tied')) {
        selectedWinner = 'tie';
      } else if (result.contains('no result')) {
        selectedWinner = 'no-result';
      }
    }

    if (widget.match.cricketResultType == 'wickets') {
      selectedCricketResultType = 'wickets';
    }
  }

  @override
  void dispose() {
    _teamAScoreController.dispose();
    _teamBScoreController.dispose();
    _teamAWicketsController.dispose();
    _teamBWicketsController.dispose();
    _teamAOversController.dispose();
    _teamBOversController.dispose();
    _resultMarginController.dispose();
    super.dispose();
  }

  String _scoreLabel(String teamName) {
    return _isCricket ? '$teamName Runs' : '$teamName Score';
  }

  String _wicketsLabel(String teamName) => '$teamName Wickets';

  String _oversLabel(String teamName) => '$teamName Overs';

  bool _isValidOvers(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return true;
    }
    return RegExp(r'^\d+(?:\.[0-5])?$').hasMatch(text);
  }

  bool get _needsCricketMargin {
    return _isCricket &&
        selectedStatus == 'completed' &&
        (selectedWinner == 'teamA' || selectedWinner == 'teamB');
  }

  String _formatScorecardLine(
    String teamName,
    int runs,
    int? wickets,
    String? overs,
  ) {
    final wicketsText = wickets != null ? '/$wickets' : '';
    final oversText = overs != null && overs.isNotEmpty
        ? ' in $overs overs'
        : '';
    return '$teamName $runs$wicketsText$oversText';
  }

  String? _buildCricketScorecardText() {
    if (!_isCricket || selectedStatus != 'completed') {
      return null;
    }

    if (selectedWinner == 'tie') {
      final teamA = _formatScorecardLine(
        widget.match.teamAName,
        int.tryParse(_teamAScoreController.text.trim()) ??
            widget.match.teamAScore,
        int.tryParse(_teamAWicketsController.text.trim()) ??
            widget.match.teamAWickets,
        _teamAOversController.text.trim().isEmpty
            ? widget.match.teamAOvers
            : _teamAOversController.text.trim(),
      );
      final teamB = _formatScorecardLine(
        widget.match.teamBName,
        int.tryParse(_teamBScoreController.text.trim()) ??
            widget.match.teamBScore,
        int.tryParse(_teamBWicketsController.text.trim()) ??
            widget.match.teamBWickets,
        _teamBOversController.text.trim().isEmpty
            ? widget.match.teamBOvers
            : _teamBOversController.text.trim(),
      );
      return '$teamA tied with $teamB';
    }

    if (selectedWinner == 'no-result') {
      return 'No result';
    }

    final margin = int.tryParse(_resultMarginController.text.trim());
    if (margin == null || margin <= 0) {
      return null;
    }

    final winnerTeamA = selectedWinner == 'teamA';
    final winnerName = winnerTeamA
        ? widget.match.teamAName
        : widget.match.teamBName;
    final loserName = winnerTeamA
        ? widget.match.teamBName
        : widget.match.teamAName;

    final winnerRuns =
        int.tryParse(
          winnerTeamA
              ? _teamAScoreController.text.trim()
              : _teamBScoreController.text.trim(),
        ) ??
        (winnerTeamA ? widget.match.teamAScore : widget.match.teamBScore);
    final loserRuns =
        int.tryParse(
          winnerTeamA
              ? _teamBScoreController.text.trim()
              : _teamAScoreController.text.trim(),
        ) ??
        (winnerTeamA ? widget.match.teamBScore : widget.match.teamAScore);
    final winnerWickets =
        int.tryParse(
          winnerTeamA
              ? _teamAWicketsController.text.trim()
              : _teamBWicketsController.text.trim(),
        ) ??
        (winnerTeamA ? widget.match.teamAWickets : widget.match.teamBWickets);
    final loserWickets =
        int.tryParse(
          winnerTeamA
              ? _teamBWicketsController.text.trim()
              : _teamAWicketsController.text.trim(),
        ) ??
        (winnerTeamA ? widget.match.teamBWickets : widget.match.teamAWickets);
    final winnerOvers =
        (winnerTeamA
                ? _teamAOversController.text.trim()
                : _teamBOversController.text.trim())
            .isEmpty
        ? (winnerTeamA ? widget.match.teamAOvers : widget.match.teamBOvers)
        : (winnerTeamA
              ? _teamAOversController.text.trim()
              : _teamBOversController.text.trim());
    final loserOvers =
        (winnerTeamA
                ? _teamBOversController.text.trim()
                : _teamAOversController.text.trim())
            .isEmpty
        ? (winnerTeamA ? widget.match.teamBOvers : widget.match.teamAOvers)
        : (winnerTeamA
              ? _teamBOversController.text.trim()
              : _teamAOversController.text.trim());

    final winnerLine = _formatScorecardLine(
      winnerName,
      winnerRuns,
      winnerWickets,
      winnerOvers,
    );
    final loserLine = _formatScorecardLine(
      loserName,
      loserRuns,
      loserWickets,
      loserOvers,
    );
    final unit = selectedCricketResultType == 'wickets' ? 'wickets' : 'runs';

    return '$winnerLine beat $loserLine by $margin $unit';
  }

  String? _buildCricketResultText() {
    if (!_isCricket || selectedStatus != 'completed') {
      return null;
    }

    if (selectedWinner == 'tie') {
      return 'Match tied';
    }

    if (selectedWinner == 'no-result') {
      return 'No result';
    }

    return _buildCricketScorecardText();
  }

  String _winnerText() {
    final a =
        int.tryParse(_teamAScoreController.text.trim()) ??
        widget.match.teamAScore;
    final b =
        int.tryParse(_teamBScoreController.text.trim()) ??
        widget.match.teamBScore;

    if (a > b) {
      return '${widget.match.teamAName} is currently leading';
    }
    if (b > a) {
      return '${widget.match.teamBName} is currently leading';
    }
    return 'Scores are tied';
  }

  Future<void> _saveScores() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final teamARuns = int.parse(_teamAScoreController.text.trim());
    final teamBRuns = int.parse(_teamBScoreController.text.trim());
    final teamAWickets = int.tryParse(_teamAWicketsController.text.trim());
    final teamBWickets = int.tryParse(_teamBWicketsController.text.trim());

    String? winnerTeamId;
    String? resultText;
    String? resultType;
    int? resultMargin;
    String? teamAOvers;
    String? teamBOvers;

    if (_isCricket) {
      teamAOvers = _teamAOversController.text.trim().isEmpty
          ? null
          : _teamAOversController.text.trim();
      teamBOvers = _teamBOversController.text.trim().isEmpty
          ? null
          : _teamBOversController.text.trim();

      resultText = _buildCricketResultText();
      if (selectedStatus == 'completed' && resultText == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter valid cricket result details.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (selectedStatus == 'completed') {
        if (selectedWinner == 'teamA') {
          winnerTeamId = widget.match.teamAId;
        } else if (selectedWinner == 'teamB') {
          winnerTeamId = widget.match.teamBId;
        }

        if (selectedWinner == 'teamA' || selectedWinner == 'teamB') {
          resultType = selectedCricketResultType;
          resultMargin = int.tryParse(_resultMarginController.text.trim());
        }
      }
    } else {
      if (selectedStatus == 'completed') {
        if (teamARuns > teamBRuns) {
          winnerTeamId = widget.match.teamAId;
          resultText = '${widget.match.teamAName} won';
        } else if (teamBRuns > teamARuns) {
          winnerTeamId = widget.match.teamBId;
          resultText = '${widget.match.teamBName} won';
        } else {
          winnerTeamId = null;
          resultText = 'Match tied';
        }
      }
    }

    setState(() {
      isSaving = true;
    });

    try {
      final payload = <String, dynamic>{
        'teamAScore': teamARuns,
        'teamBScore': teamBRuns,
        'status': selectedStatus,
        'lastUpdatedAt': DateTime.now(),
      };

      if (_isCricket) {
        payload['teamAWickets'] = teamAWickets;
        payload['teamBWickets'] = teamBWickets;
        payload['teamAOvers'] = teamAOvers;
        payload['teamBOvers'] = teamBOvers;
        payload['winnerTeamId'] = winnerTeamId;
        payload['resultText'] = resultText;
        payload['cricketResultType'] = resultType;
        payload['cricketResultMargin'] = resultMargin;
      } else {
        payload['winnerTeamId'] = winnerTeamId;
        payload['resultText'] = resultText;
      }

      await _firestore
          .collection('tournaments')
          .doc(widget.tournament.id)
          .collection('matches')
          .doc(widget.match.id)
          .update(payload);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Score Entry'), elevation: 0),
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
                    if (_isCricket &&
                        (widget.match.teamAWickets != null ||
                            widget.match.teamBWickets != null)) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Wickets: ${widget.match.teamAName}${widget.match.teamAWickets != null ? ' ${widget.match.teamAWickets}' : ''}${widget.match.teamBWickets != null ? ' | ${widget.match.teamBName} ${widget.match.teamBWickets}' : ''}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (_isCricket &&
                        (widget.match.teamAOvers != null ||
                            widget.match.teamBOvers != null)) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Overs: ${widget.match.teamAName}${widget.match.teamAOvers != null ? ' ${widget.match.teamAOvers}' : ''}${widget.match.teamBOvers != null ? ' | ${widget.match.teamBName} ${widget.match.teamBOvers}' : ''}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if ((widget.match.resultText ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Result: ${widget.match.resultText}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _teamAScoreController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: _scoreLabel(widget.match.teamAName),
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
                                labelText: _scoreLabel(widget.match.teamBName),
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
                      if (_isCricket) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _teamAWicketsController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: _wicketsLabel(
                                    widget.match.teamAName,
                                  ),
                                  helperText: 'Optional 0 to 10',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return null;
                                  }
                                  final wickets = int.tryParse(value.trim());
                                  if (wickets == null ||
                                      wickets < 0 ||
                                      wickets > 10) {
                                    return 'Use 0 to 10';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _teamBWicketsController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: _wicketsLabel(
                                    widget.match.teamBName,
                                  ),
                                  helperText: 'Optional 0 to 10',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return null;
                                  }
                                  final wickets = int.tryParse(value.trim());
                                  if (wickets == null ||
                                      wickets < 0 ||
                                      wickets > 10) {
                                    return 'Use 0 to 10';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _teamAOversController,
                                keyboardType: TextInputType.text,
                                decoration: InputDecoration(
                                  labelText: _oversLabel(
                                    widget.match.teamAName,
                                  ),
                                  helperText: 'Optional format: 20 or 19.3',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return null;
                                  }
                                  if (!_isValidOvers(value)) {
                                    return 'Use format like 20 or 19.3';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _teamBOversController,
                                keyboardType: TextInputType.text,
                                decoration: InputDecoration(
                                  labelText: _oversLabel(
                                    widget.match.teamBName,
                                  ),
                                  helperText: 'Optional format: 20 or 19.3',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return null;
                                  }
                                  if (!_isValidOvers(value)) {
                                    return 'Use format like 20 or 19.3';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedWinner,
                          decoration: InputDecoration(
                            labelText: 'Result Winner',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'teamA',
                              child: Text(widget.match.teamAName),
                            ),
                            DropdownMenuItem(
                              value: 'teamB',
                              child: Text(widget.match.teamBName),
                            ),
                            const DropdownMenuItem(
                              value: 'tie',
                              child: Text('Match Tied'),
                            ),
                            const DropdownMenuItem(
                              value: 'no-result',
                              child: Text('No Result'),
                            ),
                          ],
                          onChanged: selectedStatus == 'completed'
                              ? (value) {
                                  setState(() {
                                    selectedWinner = value ?? 'teamA';
                                  });
                                }
                              : null,
                        ),
                        if (_needsCricketMargin) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: selectedCricketResultType,
                                  decoration: InputDecoration(
                                    labelText: 'Won By',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'runs',
                                      child: Text('Runs'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'wickets',
                                      child: Text('Wickets'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      selectedCricketResultType =
                                          value ?? 'runs';
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _resultMarginController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Margin',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (!_needsCricketMargin) {
                                      return null;
                                    }
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Enter margin';
                                    }
                                    final parsed = int.tryParse(value.trim());
                                    if (parsed == null || parsed <= 0) {
                                      return 'Invalid';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          selectedStatus == 'completed'
                              ? (_buildCricketScorecardText() ??
                                    'Result preview will appear here')
                              : 'Set match status to COMPLETED to save final cricket result.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
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
