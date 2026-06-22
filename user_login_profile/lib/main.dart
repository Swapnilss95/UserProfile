import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:user_login_profile/User_Login/userloginpage.dart';
import 'package:user_login_profile/userprofil.dart';

// Note: Replace this with your project's configuration if needed
import 'firebase_options.dart'; 

// ─────────────────────────────────────────────────────────────────────────────
// 1. MAIN ENTRY POINT & AUTHENTICATION ROUTER
// ─────────────────────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      // Setting AuthWrapper as home checks for an active session automatically
      home: AuthWrapper(), 
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. AUTHENTICATION WRAPPER (PERSISTENCE LAYER)
// ─────────────────────────────────────────────────────────────────────────────
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If the stream is active, evaluate the login state
        if (snapshot.connectionState == ConnectionState.active) {
          final User? user = snapshot.data;
          if (user == null) {
            // No active user found -> Show Login Screen
            return const UserLogin();
          } else {
            // Active user session found -> Show Profile Screen directly
            return const UserProfileScreen();
          }
        }

        // Deep cosmic loading splash matching your theme design
        return const Scaffold(
          backgroundColor: Color(0xFF0D0D1A), // bgDeep
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA78BFA)), // accentA
              strokeWidth: 2.5,
            ),
          ),
        );
      },
    );
  }
}