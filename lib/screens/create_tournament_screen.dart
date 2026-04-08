import 'package:flutter/material.dart';

class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  final _formKey = GlobalKey<FormState>();

  String tournamentName = '';
  String sportType = 'Cricket';
  int numberOfTeams = 2;

  final List<String> sports = ['Cricket', 'Football', 'Badminton', 'Kabaddi'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Tournament")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Tournament Name
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Tournament Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter tournament name';
                  }
                  return null;
                },
                onSaved: (value) {
                  tournamentName = value!;
                },
              ),

              const SizedBox(height: 15),

              // Sport Dropdown
              DropdownButtonFormField(
                value: sportType,
                items: sports.map((sport) {
                  return DropdownMenuItem(value: sport, child: Text(sport));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    sportType = value!;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Select Sport',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 15),

              // Number of Teams
              TextFormField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of Teams',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter number of teams';
                  }
                  return null;
                },
                onSaved: (value) {
                  numberOfTeams = int.parse(value!);
                },
              ),

              const SizedBox(height: 20),

              // Create Button
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();

                    // For now just print (later Firebase)
                    print("Tournament: $tournamentName");
                    print("Sport: $sportType");
                    print("Teams: $numberOfTeams");

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Tournament Created!")),
                    );
                  }
                },
                child: const Text("Create"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
