import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/user_model.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/viewer_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<UserRole> _ensureAndGetUserRole(User firebaseUser) async {
    try {
      final users = FirebaseFirestore.instance.collection('users');
      final tournaments = FirebaseFirestore.instance.collection('tournaments');
      final doc = await users.doc(firebaseUser.uid).get();

      if (doc.exists) {
        final user = UserModel.fromJson(doc.data()!);
        return user.role;
      }

      // Backward compatibility: if user already owns tournaments, treat as organizer.
      final existingOwnedTournament = await tournaments
          .where('userId', isEqualTo: firebaseUser.uid)
          .limit(1)
          .get();

      final inferredRole = existingOwnedTournament.docs.isNotEmpty
          ? UserRole.organizer
          : UserRole.viewer;

      final migratedUser = UserModel(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        name: firebaseUser.displayName ?? '',
        role: inferredRole,
        createdAt: DateTime.now(),
      );

      await users.doc(firebaseUser.uid).set(migratedUser.toJson());
      return inferredRole;
    } catch (e) {
      debugPrint('Error fetching user role: $e');
    }
    return UserRole.viewer;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ScoreArena',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // If user is logged in, fetch role and show appropriate dashboard
          if (snapshot.connectionState == ConnectionState.active) {
            if (snapshot.data != null) {
              return FutureBuilder<UserRole>(
                future: _ensureAndGetUserRole(snapshot.data!),
                builder: (context, roleSnapshot) {
                  if (roleSnapshot.connectionState == ConnectionState.done) {
                    final role = roleSnapshot.data ?? UserRole.viewer;

                    if (role == UserRole.organizer) {
                      return const HomeScreen(); // Organizer dashboard
                    } else {
                      return const ViewerDashboard(); // Viewer dashboard
                    }
                  }
                  // Show loading while fetching role
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                },
              );
            } else {
              return const LoginScreen();
            }
          }
          // Show loading while checking auth state
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}
