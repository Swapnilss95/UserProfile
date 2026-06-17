import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:user_login_profile/userprofil.dart'; 

class OtpPage extends StatefulWidget {
  final String verificationId;
  const OtpPage({super.key, required this.verificationId});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user?.phoneNumber != null) {
      _mobileController.text = user!.phoneNumber!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _saveProfileToFirestore() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Trim strings to prevent trailing whitespaces from corrupting index evaluations
        final String cleanName = _nameController.text.trim();
        final String cleanMobile = _mobileController.text.trim();
        final String cleanLocation = _locationController.text.trim();

        await user.updateDisplayName(cleanName);

        // Writing payload safely into 'users' collection using user.uid as Document ID
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': cleanName,
          'mobile': cleanMobile,
          'location': cleanLocation,
          'email': (user.email != null && user.email!.isNotEmpty) 
              ? user.email!.toLowerCase().trim() 
              : "No Email Linked",
          'createdAt': FieldValue.serverTimestamp(), // Crucial field for chronological indexing
        }, SetOptions(merge: true));

        await user.reload();

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const UserProfileScreen()),
          (route) => false,
        );
      } else {
        throw Exception("No authenticated active session user found.");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving details: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xffb8cbb8), Color(0xff005bea)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Complete Your Profile",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xff005bea)),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person)),
                        validator: (v) => v!.trim().isEmpty ? "Enter your name" : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _mobileController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Mobile Number', prefixIcon: Icon(Icons.phone)),
                        validator: (v) => v!.trim().isEmpty ? "Enter mobile number" : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(labelText: 'Location / Address', prefixIcon: Icon(Icons.location_on)),
                        validator: (v) => v!.trim().isEmpty ? "Enter location" : null,
                      ),
                      const SizedBox(height: 24),
                      _isSaving
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: _saveProfileToFirestore,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 14),
                                backgroundColor: const Color(0xff005bea),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Save & Continue', style: TextStyle(fontSize: 16)),
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
}