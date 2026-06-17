import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:user_login_profile/User_Login/forgetpassword.dart';
import 'package:user_login_profile/User_Login/user_signup_page.dart';
import 'package:user_login_profile/userprofil.dart';
// Make sure to import your shared theme file here:
// import 'package:user_login_profile/cosmic_theme.dart';

// ── Shared Cosmic Theme Definitions ──────────────────────────────────
const Color bgDeep = Color(0xFF0D0D1A);       // Near-black cosmic indigo
const Color bgCard = Color(0xFF1C1A3A);       // Rich deep slate/navy
const Color bgSurface = Color(0xFF0F0D24);    // Inner field dark background

const Color accentA = Color(0xFFA78BFA);      // Electric lavender/purple
const Color accentB = Color(0xFFEC4899);      // Hot cyber pink
const Color accentGlow = Color(0xFF7C3AED);   // Deep violet base glow

const Color textPrimary = Color(0xFFE8F0FE);   // Crisp starlight white
const Color textSecondary = Color(0xFF8A8AB0); // Cool slate mute
const Color textMuted = Color(0xFF5D5A85);     // Deep structural placeholder

const BoxDecoration cosmicBackgroundDecoration = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      bgDeep,
      Color(0xFF12102B),
      Color(0xFF1A0A2E),
    ],
    stops: [0.0, 0.5, 1.0],
  ),
);

BoxDecoration buildCosmicCardDecoration() {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(28),
    color: bgCard.withOpacity(0.85),
    border: Border.all(
      color: accentGlow.withOpacity(0.22),
      width: 1.4,
    ),
    boxShadow: [
      BoxShadow(
        color: accentGlow.withOpacity(0.12),
        blurRadius: 40,
        offset: const Offset(0, 16),
      ),
    ],
  );
}

InputDecoration buildCosmicInputDecoration({
  required String labelText,
  required IconData prefixIcon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: labelText,
    labelStyle: const TextStyle(color: textSecondary, fontSize: 13.5),
    prefixIcon: Icon(prefixIcon, color: accentA, size: 20),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: bgSurface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: accentGlow.withOpacity(0.18),
        width: 1.2,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: accentA, width: 1.8),
    ),
  );
}

BoxDecoration buildCosmicButtonDecoration() {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    gradient: const LinearGradient(
      colors: [accentGlow, accentB],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    boxShadow: [
      BoxShadow(
        color: accentGlow.withOpacity(0.45),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

// ── Screen Code ──────────────────────────────────────────────────────
class UserLogin extends StatefulWidget {
  const UserLogin({super.key});

  @override
  State<UserLogin> createState() => _UserLoginState();
}

class _UserLoginState extends State<UserLogin> {
  final email = TextEditingController();
  final pass = TextEditingController();

  bool loading = false;
  bool obscure = true;

  Future<void> loginUser() async {
    final userEmail = email.text.trim().toLowerCase();
    final password = pass.text.trim();

    if (userEmail.isEmpty || password.isEmpty) {
      showMessage("Enter email and password");
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final result = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: userEmail,
        password: password,
      );

      final user = result.user;

      if (user != null) {
        await FirebaseFirestore.instance.collection("login_history").add({
          "uid": user.uid,
          "email": user.email,
          "method": "password",
          "status": "success",
          "time": FieldValue.serverTimestamp()
        });
      }

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const UserProfileScreen(),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print(e);
      }

      String msg;

      switch (e.code) {
        case "user-not-found":
          msg = "User not found";
          break;
        case "wrong-password":
          msg = "Wrong password";
          break;
        case "invalid-email":
          msg = "Invalid email";
          break;
        default:
          msg = e.message ?? "Login failed";
      }

      showMessage(msg);
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> sendEmailOTP() async {
    final userEmail = email.text.trim();

    if (userEmail.isEmpty) {
      showMessage("Enter email first");
      return;
    }

    try {
      await FirebaseAuth.instance.sendSignInLinkToEmail(
        email: userEmail,
        actionCodeSettings: ActionCodeSettings(
          url: "https://YOUR_PROJECT.firebaseapp.com",
          handleCodeInApp: true,
          androidPackageName: "com.example.app",
          androidInstallApp: true,
          androidMinimumVersion: "21",
        ),
      );

      showMessage("Link sent to $userEmail");
    } catch (e) {
      showMessage(e.toString());
    }
  }

  void showMessage(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2D2B55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: cosmicBackgroundDecoration,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                children: [
                  // Glowing avatar ring matching Sign Up Header
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [accentGlow, accentB],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentGlow.withOpacity(0.55),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3.5),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF12102B),
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 44,
                          color: accentA,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [accentA, accentB],
                    ).createShader(bounds),
                    child: const Text(
                      "Welcome Back",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Login to continue",
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Form Card using global structural decoration settings
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
                    decoration: buildCosmicCardDecoration(),
                    child: Column(
                      children: [
                        TextField(
                          controller: email,
                          style: const TextStyle(color: Colors.white, fontSize: 14.5),
                          cursorColor: accentA,
                          decoration: buildCosmicInputDecoration(
                            labelText: "Email",
                            prefixIcon: Icons.email_outlined,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: pass,
                          obscureText: obscure,
                          style: const TextStyle(color: Colors.white, fontSize: 14.5),
                          cursorColor: accentA,
                          decoration: buildCosmicInputDecoration(
                            labelText: "Password",
                            prefixIcon: Icons.lock_outline_rounded,
                            suffixIcon: GestureDetector(
                              onTap: () {
                                setState(() {
                                  obscure = !obscure;
                                });
                              },
                              child: Icon(
                                obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: textSecondary,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              "Forgot Password?",
                              style: TextStyle(
                                color: accentA,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        
                        // Submit button using structural gradient and glow setup
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: loading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(accentA),
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : DecoratedBox(
                                  decoration: buildCosmicButtonDecoration(),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed: loginUser,
                                    child: const Text(
                                      "Login",
                                      style: TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: sendEmailOTP,
                          child: const Text(
                            "Login with Email Link",
                            style: TextStyle(
                              color: accentB,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account? ",
                              style: TextStyle(color: textSecondary, fontSize: 13),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SignUpScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                "Sign Up",
                                style: TextStyle(
                                  color: accentA,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}