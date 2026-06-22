import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:user_login_profile/userprofil.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final emailController = TextEditingController();
  final passController = TextEditingController();
  final confirmPassController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirmPass = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    nameController.dispose();
    addressController.dispose();
    emailController.dispose();
    passController.dispose();
    confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    final nameText = nameController.text.trim();
    final addressText = addressController.text.trim();
    final emailText = emailController.text.trim();
    final passwordText = passController.text;
    final confirmPasswordText = confirmPassController.text;

    if (nameText.isEmpty ||
        addressText.isEmpty ||
        emailText.isEmpty ||
        passwordText.isEmpty ||
        confirmPasswordText.isEmpty) {
      _showSnackBar('Please fill in all fields');
      return;
    }

    if (passwordText != confirmPasswordText) {
      _showSnackBar('Passwords do not match');
      return;
    }

    if (passwordText.length < 6) {
      _showSnackBar('Password must be at least 6 characters long');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Creates authentication credentials inside Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailText,
        password: passwordText,
      );

      User? user = userCredential.user;

      if (user != null) {
        await user.updateDisplayName(nameText);

        // 2. Safely maps and stores structural data profile records within Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'uid': user.uid,
          'name': nameText,
          'location': addressText,
          'email': emailText.toLowerCase(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        await user.reload();
      }

      if (!mounted) return;

      _showSnackBar('Registration successful!');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const UserProfileScreen(),
        ),
      );
    } on FirebaseAuthException catch (error) {
      _showSnackBar(error.message ?? 'Registration failed.');
    } catch (error) {
      _showSnackBar('An unexpected error occurred: ${error.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2D2B55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D0D1A),
              Color(0xFF12102B),
              Color(0xFF1A0A2E),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 20.0),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildHeader(),
                    const SizedBox(height: 36),
                    _buildFormCard(),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account? ',
                          style: TextStyle(
                              color: Color(0xFF8A8AB0), fontSize: 13),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              color: Color(0xFFA78BFA),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withOpacity(0.55),
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
              child: ClipOval(
                child: Image.asset(
                  'Assets/images/image1.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.person,
                    size: 44,
                    color: Color(0xFFA78BFA),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFA78BFA), Color(0xFFEC4899)],
          ).createShader(bounds),
          child: const Text(
            'Create Account',
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
          'Join us — it only takes a minute',
          style: TextStyle(
            color: Color(0xFF8A8AB0),
            fontSize: 13.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: const Color(0xFF1C1A3A).withOpacity(0.85),
        border: Border.all(
          color: const Color(0xFF7C3AED).withOpacity(0.22),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.12),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
      child: Column(
        children: [
          _buildField(
            controller: nameController,
            label: 'Full Name',
            icon: Icons.person_outline_rounded,
            inputType: TextInputType.name,
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: addressController,
            label: 'Address',
            icon: Icons.location_on_outlined,
            inputType: TextInputType.streetAddress,
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: emailController,
            label: 'Email',
            icon: Icons.mail_outline_rounded,
            inputType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          _buildPasswordField(
            controller: passController,
            label: 'Password',
            obscure: _obscurePass,
            onToggle: () => setState(() => _obscurePass = !_obscurePass),
          ),
          const SizedBox(height: 14),
          _buildPasswordField(
            controller: confirmPassController,
            label: 'Confirm Password',
            obscure: _obscureConfirmPass,
            onToggle: () =>
                setState(() => _obscureConfirmPass = !_obscureConfirmPass),
          ),
          const SizedBox(height: 28),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required TextInputType inputType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      style: const TextStyle(color: Colors.white, fontSize: 14.5),
      cursorColor: const Color(0xFFA78BFA),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(color: Color(0xFF8A8AB0), fontSize: 13.5),
        prefixIcon: Icon(icon, color: const Color(0xFFA78BFA), size: 20),
        filled: true,
        fillColor: const Color(0xFF0F0D24),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: const Color(0xFF7C3AED).withOpacity(0.18), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFA78BFA), width: 1.8),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontSize: 14.5),
      cursorColor: const Color(0xFFA78BFA),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(color: Color(0xFF8A8AB0), fontSize: 13.5),
        prefixIcon: const Icon(Icons.lock_outline_rounded,
            color: Color(0xFFA78BFA), size: 20),
        suffixIcon: GestureDetector(
          onTap: onToggle,
          child: Icon(
            obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: const Color(0xFF8A8AB0),
            size: 20,
          ),
        ),
        filled: true,
        fillColor: const Color(0xFF0F0D24),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: const Color(0xFF7C3AED).withOpacity(0.18), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFA78BFA), width: 1.8),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(Color(0xFFA78BFA)),
                strokeWidth: 2.5,
              ),
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withOpacity(0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _handleSignUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
    );
  }
}