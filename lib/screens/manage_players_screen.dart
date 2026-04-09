import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/player_model.dart';
import '../models/team_model.dart';
import '../models/tournament_model.dart';

class ManagePlayersScreen extends StatefulWidget {
  final Tournament tournament;
  final Team team;

  const ManagePlayersScreen({
    super.key,
    required this.tournament,
    required this.team,
  });

  @override
  State<ManagePlayersScreen> createState() => _ManagePlayersScreenState();
}

class _ManagePlayersScreenState extends State<ManagePlayersScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _jerseyNumberController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool isSaving = false;
  late String selectedRole;

  List<String> get roles {
    final sport = widget.tournament.sport.toLowerCase().trim();

    if (sport == 'cricket') {
      return ['Batsman', 'Bowler', 'All-Rounder', 'Wicketkeeper', 'Captain'];
    }

    if (sport == 'football') {
      return ['Goalkeeper', 'Defender', 'Midfielder', 'Forward', 'Captain'];
    }

    return ['Player', 'Captain'];
  }

  @override
  void initState() {
    super.initState();
    selectedRole = roles.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _jerseyNumberController.dispose();
    super.dispose();
  }

  String _friendlyFirestoreError(Object error) {
    final message = error.toString();
    if (message.contains('permission-denied')) {
      return 'Firestore rules are blocking player access. Update the nested players rules.';
    }
    return message;
  }

  Future<void> _addPlayer() async {
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

    setState(() {
      isSaving = true;
    });

    try {
      final player = Player(
        userId: user.uid,
        name: _nameController.text.trim(),
        role: selectedRole,
        jerseyNumber: int.parse(_jerseyNumberController.text.trim()),
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('tournaments')
          .doc(widget.tournament.id)
          .collection('teams')
          .doc(widget.team.id)
          .collection('players')
          .add(player.toJson());

      _nameController.clear();
      _jerseyNumberController.clear();
      setState(() {
        selectedRole = roles.first;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Player added successfully! ✅'),
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

  Future<void> _deletePlayer(String playerId) async {
    try {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Player?'),
          content: const Text('This player will be removed from the team.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await _firestore
                    .collection('tournaments')
                    .doc(widget.tournament.id)
                    .collection('teams')
                    .doc(widget.team.id)
                    .collection('players')
                    .doc(playerId)
                    .delete();

                Navigator.pop(context);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Player deleted successfully! ✅'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
        appBar: AppBar(title: Text(widget.team.name)),
        body: const Center(
          child: Text('Please login again to manage players.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Players - ${widget.team.name}'),
        elevation: 0,
      ),
      body: Padding(
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
                        'Add Player',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Player Name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter player name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(Icons.badge),
                        ),
                        items: roles
                            .map(
                              (role) => DropdownMenuItem<String>(
                                value: role,
                                child: Text(role),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedRole = value ?? roles.first;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _jerseyNumberController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Jersey Number',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(Icons.numbers),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter jersey number';
                          }
                          final parsed = int.tryParse(value.trim());
                          if (parsed == null || parsed < 0) {
                            return 'Enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isSaving ? null : _addPlayer,
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
                              : const Text('Add Player'),
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
                    .collection('teams')
                    .doc(widget.team.id)
                    .collection('players')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

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

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 80,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No players yet',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add your first player using the form above.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    );
                  }

                  final players = [...snapshot.data!.docs]
                    ..sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aCreated = Player.fromJson(aData, a.id).createdAt;
                      final bCreated = Player.fromJson(bData, b.id).createdAt;
                      return bCreated.compareTo(aCreated);
                    });

                  return ListView.builder(
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      final doc = players[index];
                      final player = Player.fromJson(
                        doc.data() as Map<String, dynamic>,
                        doc.id,
                      );

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.shade100,
                            child: const Icon(
                              Icons.person,
                              color: Colors.green,
                            ),
                          ),
                          title: Text(
                            player.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Role: ${player.role}   |   Jersey: ${player.jerseyNumber}',
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'delete' && player.id != null) {
                                _deletePlayer(player.id!);
                              }
                            },
                            itemBuilder: (context) => const [
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
      ),
    );
  }
}
