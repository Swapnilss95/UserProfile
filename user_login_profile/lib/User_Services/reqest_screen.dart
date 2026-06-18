import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:user_login_profile/userprofil.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
const Color _bgDeep      = Color(0xFF080C14);
const Color _bgCard      = Color(0xFF0F1624);
const Color _accentA     = Color(0xFF00D4AA);
const Color _accentB     = Color(0xFF00A86B);
const Color _textPrimary   = Color(0xFFE8F0FE);
const Color _textSecondary = Color(0xFF8899B0);

class RequestServiceScreen extends StatefulWidget {
  final String jobDocId;
  const RequestServiceScreen({super.key, required this.jobDocId});

  @override
  State<RequestServiceScreen> createState() => _RequestServiceScreenState();
}

class _RequestServiceScreenState extends State<RequestServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController     = TextEditingController();
  final _phoneController    = TextEditingController();
  final _addressController  = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) => Theme(
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
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      builder: (context, child) => Theme(
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
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both Date & Time'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final formattedDate =
          '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
      final formattedTime = _selectedTime!.format(context);

      // ✅ Update the existing Jobs document with schedule details
      await FirebaseFirestore.instance
          .collection('Jobs')
          .doc(widget.jobDocId)
          .update({
        'scheduledDate':    formattedDate,
        'scheduledTime':    formattedTime,
        'contactName':      _nameController.text.trim(),
        'contactPhone':     _phoneController.text.trim(),
        'serviceAddress':   _addressController.text.trim(),
        'scheduleUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request submitted successfully!'),
          backgroundColor: _accentB,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const UserProfileScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDeep,
      appBar: AppBar(
        title: const Text('Book Service',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: _textPrimary)),
        backgroundColor: _bgCard,
        foregroundColor: _textPrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
              height: 1, color: Colors.white.withOpacity(0.06)),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Schedule Your Service',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary)),
                const SizedBox(height: 6),
                const Text(
                    'Confirm your contact details and pick a convenient slot.',
                    style: TextStyle(
                        color: _textSecondary, fontSize: 13)),
                const SizedBox(height: 28),

                _sectionLabel('Contact Info'),
                _field(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person_outline,
                  validator: (v) =>
                      v!.trim().isEmpty ? 'Enter your name' : null,
                ),
                const SizedBox(height: 14),
                _field(
                  controller: _phoneController,
                  label: 'Mobile Number',
                  icon: Icons.phone_android,
                  keyboard: TextInputType.phone,
                  validator: (v) => v!.trim().length < 10
                      ? 'Enter a valid number'
                      : null,
                ),
                const SizedBox(height: 26),

                _sectionLabel('Service Location'),
                _field(
                  controller: _addressController,
                  label: 'Complete Address',
                  icon: Icons.location_on_outlined,
                  maxLines: 3,
                  validator: (v) =>
                      v!.trim().isEmpty ? 'Address is required' : null,
                ),
                const SizedBox(height: 26),

                _sectionLabel('Preferred Slot'),
                Row(
                  children: [
                    Expanded(
                      child: _pickerCard(
                        title: _selectedDate == null
                            ? 'Pick Date'
                            : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                        icon: Icons.calendar_today_rounded,
                        isActive: _selectedDate != null,
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _pickerCard(
                        title: _selectedTime == null
                            ? 'Pick Time'
                            : _selectedTime!.format(context),
                        icon: Icons.access_time_rounded,
                        isActive: _selectedTime != null,
                        onTap: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentA,
                      foregroundColor: _bgDeep,
                      disabledBackgroundColor:
                          _accentA.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 22, width: 22,
                            child: CircularProgressIndicator(
                                color: _bgDeep, strokeWidth: 2.5),
                          )
                        : const Text('Confirm Booking',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _accentA,
                letterSpacing: 0.6)),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboard,
        validator: validator,
        style: const TextStyle(color: _textPrimary, fontSize: 14.5),
        cursorColor: _accentA,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: _textSecondary),
          filled: true,
          fillColor: _bgCard,
          labelStyle:
              const TextStyle(color: _textSecondary, fontSize: 13.5),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: _accentA, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Colors.redAccent),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
        ),
      );

  Widget _pickerCard({
    required String title,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(
              vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: isActive ? _accentA.withOpacity(0.06) : _bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? _accentA.withOpacity(0.6)
                  : Colors.white.withOpacity(0.06),
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 17,
                  color: isActive ? _accentA : _textSecondary),
              const SizedBox(width: 7),
              Flexible(
                child: Text(title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isActive ? _accentA : _textPrimary,
                    )),
              ),
            ],
          ),
        ),
      );
}
