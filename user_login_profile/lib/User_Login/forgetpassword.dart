import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController(); 
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _isEmailMethod = true;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // --- Show Dialog to collect the SMS Verification Code ---
  void _showOtpDialog(String verificationId, String cleaningPhoneNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Enter Verification Code',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the 6-digit OTP code sent to your phone number.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'OTP Code',
                labelStyle: const TextStyle(color: Colors.white60),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white30),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final smsCode = _otpController.text.trim();
              if (smsCode.isEmpty || smsCode.length < 6) return;

              Navigator.pop(context); // Close dialog
              setState(() => _isLoading = true);

              try {
                PhoneAuthCredential credential = PhoneAuthProvider.credential(
                  verificationId: verificationId,
                  smsCode: smsCode,
                );
                
                UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
                User? user = userCredential.user;

                if (user != null) {
                  await FirebaseFirestore.instance.collection('reset_requests').add({
                    'uid': user.uid,
                    'target': cleaningPhoneNumber,
                    'method': 'mobile',
                    'status': 'verified_and_authenticated',
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Phone verified & signed in successfully!')),
                  );
                  Navigator.pop(context); 
                }
              } on FirebaseAuthException catch (e) {
                _handleFirebaseError(e);
              } catch (e) {
                _showUnexpectedError(e.toString());
              } finally {                                          // FIX 1: was `final {`
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  void _handleFirebaseError(FirebaseAuthException e) {
    String userFriendlyMessage = 'An authentication error occurred.';
    if (e.code == 'user-not-found') {
      userFriendlyMessage = 'No registered account found with this email.';
    } else if (e.code == 'invalid-email') {
      userFriendlyMessage = 'The email address pattern is invalid.';
    } else if (e.code == 'network-request-failed') {
      userFriendlyMessage = 'Please verify your internet connection.';
    } else if (e.code == 'too-many-requests') {
      userFriendlyMessage = 'Too many attempts. Please try again later.';
    } else if (e.code == 'invalid-verification-code') {
      userFriendlyMessage = 'The OTP code entered is incorrect.';
    } else if (e.code == 'invalid-phone-number') {
      userFriendlyMessage = 'The phone number format is invalid.';
    } else if (e.message != null) {
      userFriendlyMessage = e.message!;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text(userFriendlyMessage)),
      );
    }
  }

  void _showUnexpectedError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text('Unexpected Error: $msg')),
      );
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isEmailMethod) {
        final String cleanEmail = _emailController.text.trim().toLowerCase();
        await FirebaseAuth.instance.sendPasswordResetEmail(email: cleanEmail);
        
        await FirebaseFirestore.instance.collection('reset_requests').add({
          'target': cleanEmail,
          'method': 'email',
          'status': 'link_sent',
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: Colors.green, content: Text('Password reset link sent! Check your email.')),
          );
          Navigator.pop(context);
        }
      } else {
        final String cleanPhone = _phoneController.text.trim();

        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: cleanPhone,
          verificationCompleted: (PhoneAuthCredential credential) async {
            UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
            User? user = userCredential.user;

            if (user != null) {
              await FirebaseFirestore.instance.collection('reset_requests').add({
                'uid': user.uid,
                'target': cleanPhone,
                'method': 'mobile',
                'status': 'auto_verified',
                'createdAt': FieldValue.serverTimestamp(),
              });
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Automatically verified and logged in!')),
              );
              Navigator.pop(context);
            }
          },
          verificationFailed: (FirebaseAuthException e) {
            setState(() => _isLoading = false);
            _handleFirebaseError(e);
          },
          codeSent: (String verificationId, int? resendToken) async {
            await FirebaseFirestore.instance.collection('reset_requests').add({
              'target': cleanPhone,
              'method': 'mobile',
              'status': 'otp_dispatched',
              'verificationId': verificationId,
              'createdAt': FieldValue.serverTimestamp(),
            });

            setState(() => _isLoading = false);
            _showOtpDialog(verificationId, cleanPhone); 
          },
          codeAutoRetrievalTimeout: (String verificationId) {},
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      _handleFirebaseError(e);
    } catch (e) {
      setState(() => _isLoading = false);
      _showUnexpectedError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Reset Password', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- Method Selector Tabs ---
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _TabButton(
                                title: 'Email',
                                isSelected: _isEmailMethod,
                                onTap: () => setState(() => _isEmailMethod = true),
                              ),
                            ),
                            Expanded(
                              child: _TabButton(
                                title: 'Mobile',
                                isSelected: !_isEmailMethod,
                                onTap: () => setState(() => _isEmailMethod = false),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        _isEmailMethod
                            ? 'Enter your email address and we\'ll send you a link to reset your password.'
                            : 'Enter your registered mobile number and we\'ll send you a security code.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.4),
                      ),
                      const SizedBox(height: 30),
                      
                      // --- Dynamic Inputs ---
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _isEmailMethod
                            ? TextFormField(
                                key: const ValueKey('emailField'),
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(color: Colors.white),
                                decoration: _buildInputDecoration(
                                  label: 'Email Address',
                                  prefixIcon: Icons.mail_outline_rounded,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty || !value.contains('@')) {
                                    return 'Please enter a valid email address';
                                  }
                                  return null;
                                },
                              )
                            : TextFormField(
                                key: const ValueKey('phoneField'),
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(color: Colors.white),
                                decoration: _buildInputDecoration(
                                  label: 'Mobile Number',
                                  hint: '+1234567890',
                                  prefixIcon: Icons.phone_android_rounded,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your mobile number';
                                  }
                                  if (!value.trim().startsWith('+')) {
                                    return 'Include country code (e.g., +1)';
                                  }
                                  return null;
                                },
                              ),
                      ),
                      const SizedBox(height: 35),
                      
                      // --- Submit Button ---
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: const Color(0xFF6366F1).withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _isLoading ? null : _resetPassword,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  _isEmailMethod ? 'Send Reset Link' : 'Send OTP',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String label, String? hint, required IconData prefixIcon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.white60, fontSize: 14),
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
      prefixIcon: Icon(prefixIcon, color: Colors.white60, size: 22),
      filled: true,
      fillColor: Colors.black12,
      errorStyle: TextStyle(color: Colors.red.shade400),           // FIX 2: was `Colors.shade400`
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
    );
  }
}

// --- Custom Sub-Widget for Tab Button Selection ---
class _TabButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({required this.title, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}