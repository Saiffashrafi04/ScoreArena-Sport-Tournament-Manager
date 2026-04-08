import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text("Firebase Test 🚀")),
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('test').add({
                'message': 'Hello from app',
              });
            },
            child: const Text("Send Data to Firebase"),
          ),
        ),
      ),
    );
  }
}
