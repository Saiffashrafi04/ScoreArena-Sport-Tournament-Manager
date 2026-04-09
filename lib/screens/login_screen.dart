import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();

  bool isLogin = true; // toggle login/signup
  UserRole selectedRole = UserRole.organizer; // default role for signup

  Future<void> authenticate() async {
    try {
      if (isLogin) {
        await _auth.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
      } else {
        // Signup: create auth user and save to Firestore
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        // Create UserModel and save to Firestore
        final userModel = UserModel(
          uid: userCredential.user!.uid,
          email: emailController.text.trim(),
          name: nameController.text.trim(),
          role: selectedRole,
          createdAt: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(userModel.uid)
            .set(userModel.toJson());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isLogin
                  ? 'Logged in successfully'
                  : 'Account created successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? "Error")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isLogin ? "Login 🔐" : "Signup 📝")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Name field (signup only)
              if (!isLogin)
                Column(
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: "Full Name",
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              // Email field
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 15),
              // Password field
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 15),
              // Role selector (signup only)
              if (!isLogin)
                Column(
                  children: [
                    DropdownButton<UserRole>(
                      value: selectedRole,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem(
                          value: UserRole.organizer,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: const [
                                Icon(Icons.admin_panel_settings, size: 20),
                                SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Organizer",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      "Create & manage tournaments",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: UserRole.viewer,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: const [
                                Icon(Icons.visibility, size: 20),
                                SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Viewer",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      "View tournaments & scores",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      onChanged: (UserRole? newRole) {
                        if (newRole != null) {
                          setState(() {
                            selectedRole = newRole;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              // Login/Signup button
              ElevatedButton(
                onPressed: authenticate,
                child: Text(isLogin ? "Login" : "Create Account"),
              ),
              // Toggle button
              TextButton(
                onPressed: () {
                  setState(() {
                    isLogin = !isLogin;
                    nameController.clear();
                  });
                },
                child: Text(
                  isLogin
                      ? "Don't have an account? Sign up"
                      : "Already have an account? Login",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
