import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:user_login_profile/userprofil.dart'; // Import for UserProfileScreen

// ─── Design Tokens ───────────────────────────────────────────────────────────
const Color _bgDeep = Color(0xFF080C14);
const Color _bgCard = Color(0xFF0F1624);
const Color _accentA = Color(0xFF00D4AA); // bright teal
const Color _accentB = Color(0xFF00A86B); // emerald
const Color _textPrimary = Color(0xFFE8F0FE);
const Color _textSecondary = Color(0xFF8899B0);
const Color _textMuted = Color(0xFF4A5A72);
// ─────────────────────────────────────────────────────────────────────────────

class InformationScreen extends StatefulWidget {
  const InformationScreen({super.key, required String jobDocId});

  @override
  State<InformationScreen> createState() => _InformationScreenState();
}

class _InformationScreenState extends State<InformationScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Text Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Date and Time tracking state variables
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSubmitting = false; // Tracks Firestore write state

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // Date Picker Engine (Themed Dark)
  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _accentA,
              onPrimary: _bgDeep,
              surface: _bgCard,
              onSurface: _textPrimary,
            ),
            dialogBackgroundColor: _bgDeep,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  // Time Picker Engine (Themed Dark)
  Future<void> _pickTime() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _accentA,
              onPrimary: _bgDeep,
              surface: _bgCard,
              onSurface: _textPrimary,
            ),
            dialogBackgroundColor: _bgDeep,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  // Commits details directly to Firestore and forwards user straight to UserProfileScreen
  Future<void> _submitAndGoToProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select both preferred service Date & Time"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      DocumentReference newRequestRef = _firestore.collection('requests').doc();
      String generatedId = newRequestRef.id;

      final String formattedDate = "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";
      final String formattedTime = _selectedTime!.format(context);

      Map<String, dynamic> requestPayload = {
        'requestId': generatedId,
        'userName': _nameController.text.trim(),
        'userPhone': _phoneController.text.trim(),
        'serviceAddress': _addressController.text.trim(),
        'scheduledDate': formattedDate, 
        'scheduledTime': formattedTime, 
        'status': 'pending',            
        'createdAt': FieldValue.serverTimestamp(),
      };

      await newRequestRef.set(requestPayload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Information submitted successfully!"),
            backgroundColor: _accentB,
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const UserProfileScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to process information details: ${e.toString()}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDeep,
      appBar: AppBar(
        title: const Text(
          "Information Details", 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _textPrimary),
        ),
        backgroundColor: _bgCard,
        foregroundColor: _textPrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.white.withOpacity(0.06),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Service Schedule Profile",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textPrimary),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Provide your contact details and availability below for Wahmitra verification.",
                  style: TextStyle(color: _textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 28),

                // Name Input
                _buildSectionHeader("Contact Info"),
                _buildTextField(
                  controller: _nameController,
                  label: "Full Name",
                  icon: Icons.person_outline,
                  validator: (v) => v!.isEmpty ? "Enter your name" : null,
                ),
                const SizedBox(height: 16),

                // Phone Input
                _buildTextField(
                  controller: _phoneController,
                  label: "Mobile Number",
                  icon: Icons.phone_android,
                  keyboardType: TextInputType.phone,
                  validator: (v) => v!.length < 10 ? "Enter a valid mobile number" : null,
                ),
                const SizedBox(height: 28),

                // Address Input
                _buildSectionHeader("Service Delivery Location"),
                _buildTextField(
                  controller: _addressController,
                  label: "Complete Store or Home Address",
                  icon: Icons.location_on_outlined,
                  maxLines: 3,
                  validator: (v) => v!.isEmpty ? "Address context is required" : null,
                ),
                const SizedBox(height: 28),

                // Scheduler Blocks
                _buildSectionHeader("Preferred Schedule Slots"),
                Row(
                  children: [
                    Expanded(
                      child: _buildPickerCard(
                        title: _selectedDate == null 
                            ? "Pick Date" 
                            : "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}",
                        icon: Icons.calendar_today_rounded,
                        onTap: _pickDate,
                        isActive: _selectedDate != null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildPickerCard(
                        title: _selectedTime == null 
                            ? "Pick Time" 
                            : _selectedTime!.format(context),
                        icon: Icons.access_time_rounded,
                        onTap: _pickTime,
                        isActive: _selectedTime != null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Action Call Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentA,
                      foregroundColor: _bgDeep,
                      disabledBackgroundColor: _accentA.withOpacity(0.3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _isSubmitting ? null : _submitAndGoToProfile,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(color: _bgDeep, strokeWidth: 2.5),
                          )
                        : const Text(
                            "Submit Details", 
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title, 
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _accentA, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: _textPrimary, fontSize: 15),
      cursorColor: _accentA,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: _textSecondary),
        filled: true,
        fillColor: _bgCard,
        labelStyle: const TextStyle(color: _textSecondary, fontSize: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), 
          borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), 
          borderSide: const BorderSide(color: _accentA, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), 
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), 
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildPickerCard({
    required String title, 
    required IconData icon, 
    required VoidCallback onTap, 
    required bool isActive,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? _accentA.withOpacity(0.06) : _bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? _accentA.withOpacity(0.6) : Colors.white.withOpacity(0.06), 
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon, 
              size: 18, 
              color: isActive ? _accentA : _textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              title, 
              style: TextStyle(
                fontSize: 13, 
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal, 
                color: isActive ? _accentA : _textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}