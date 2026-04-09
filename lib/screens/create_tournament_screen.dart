import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tournament_model.dart';

class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String tournamentName = '';
  String sportType = 'Cricket';
  int numberOfTeams = 2;
  bool isLoading = false;

  final List<String> sports = [
    'Cricket',
    'Football',
    'Badminton',
    'Kabaddi',
    'Tennis',
    'Volleyball',
  ];

  // Function to create tournament in Firestore
  Future<void> createTournament() async {
    try {
      // Validate form
      if (!_formKey.currentState!.validate()) {
        return;
      }

      // Save form data
      _formKey.currentState!.save();

      // Set loading state
      setState(() {
        isLoading = true;
      });

      // Get current user
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception("User not logged in");
      }

      // Create tournament object
      final tournament = Tournament(
        userId: user.uid,
        name: tournamentName,
        sport: sportType,
        numberOfTeams: numberOfTeams,
        createdAt: DateTime.now(),
      );

      // Save to Firestore
      await _firestore.collection('tournaments').add(tournament.toJson());

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tournament created successfully! ✅'),
            backgroundColor: Colors.green,
          ),
        );

        // Wait 2 seconds then go back to home
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pop(context);
        }
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
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Tournament ⚽"), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tournament Name
              const Text(
                "Tournament Name",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'e.g., City Cricket Championship',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.sports),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter tournament name';
                  }
                  return null;
                },
                onSaved: (value) {
                  tournamentName = value!;
                },
              ),

              const SizedBox(height: 20),

              // Sport Type
              const Text(
                "Select Sport",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: sportType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.category),
                ),
                items: sports.map((sport) {
                  return DropdownMenuItem(value: sport, child: Text(sport));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    sportType = value!;
                  });
                },
              ),

              const SizedBox(height: 20),

              // Number of Teams
              const Text(
                "Number of Teams",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextFormField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'e.g., 8, 16, 32',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.groups),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter number of teams';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  int teams = int.parse(value);
                  if (teams < 2) {
                    return 'Minimum 2 teams required';
                  }
                  return null;
                },
                onSaved: (value) {
                  numberOfTeams = int.parse(value!);
                },
              ),

              const SizedBox(height: 30),

              // Create Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : createTournament,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          "Create Tournament",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
