import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:user_login_profile/userprofil.dart';

// ─── Design Tokens ───────────────────────────────────────────────────────────
const Color _bgDeep = Color(0xFF080C14);
const Color _bgCard = Color(0xFF0F1624);
const Color _accentA = Color(0xFF00D4AA);
const Color _accentB = Color(0xFF00A86B);
const Color _textPrimary = Color(0xFFE8F0FE);
const Color _textSecondary = Color(0xFF8899B0);
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

  // State variables
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSubmitting = false;
  
  // Profile Checklist Logic
  bool _hasExistingProfile = false;
  bool _isLoadingProfile = true;
  bool _isEditing = false; // Tracks if an existing profile is being modified

  // Location state
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _checkForExistingProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // ── Checks Firestore for any prior submissions ─────────────────────────────
  Future<void> _checkForExistingProfile() async {
    try {
      final querySnapshot = await _firestore
          .collection('requests')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty && mounted) {
        final lastRequest = querySnapshot.docs.first.data();
        
        setState(() {
          _nameController.text = lastRequest['userName'] ?? '';
          _phoneController.text = lastRequest['userPhone'] ?? '';
          _addressController.text = lastRequest['serviceAddress'] ?? '';
          
          if (lastRequest['latitude'] != null && lastRequest['longitude'] != null) {
            _currentPosition = Position(
              latitude: (lastRequest['latitude'] as num).toDouble(),
              longitude: (lastRequest['longitude'] as num).toDouble(),
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
            );
          }
          _hasExistingProfile = true;
        });
      }
    } catch (e) {
      debugPrint("Error checking profile status: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  // ── Opens map picker bottom sheet ──────────────────────────────────────────
  Future<void> _openMapPicker() async {
    if (_hasExistingProfile && !_isEditing) return; 

    // Pass the current pinned location to the sheet so it initializes where the user left off
    final LatLng? picked = await showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _bgDeep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MapPickerSheet(
        initialLocation: _currentPosition != null 
            ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
            : const LatLng(20.5937, 78.9629),
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        _currentPosition = Position(
          latitude: picked.latitude,
          longitude: picked.longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
            );
          });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Location pinned successfully!"),
          backgroundColor: _accentB,
        ),
      );
    }
  }

  // ── Date Picker ────────────────────────────────────────────────────────────
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
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // ── Time Picker ────────────────────────────────────────────────────────────
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
    if (picked != null) setState(() => _selectedTime = picked);
  }

  // ── Submit to Firestore ────────────────────────────────────────────────────
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

      final String formattedDate =
          "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";
      final String formattedTime = _selectedTime!.format(context);

      // CRITICAL FIX: The current map position values are explicitly parsed into payload data coordinates
      Map<String, dynamic> requestPayload = {
        'requestId': generatedId,
        'userName': _nameController.text.trim(),
        'userPhone': _phoneController.text.trim(),
        'serviceAddress': _addressController.text.trim(),
        'scheduledDate': formattedDate,
        'scheduledTime': formattedTime,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'latitude': _currentPosition?.latitude,
        'longitude': _currentPosition?.longitude,
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
            content: Text("Failed to process details: ${e.toString()}"),
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
    bool isFieldEditable = !_hasExistingProfile || _isEditing;

    return Scaffold(
      backgroundColor: _bgDeep,
      appBar: AppBar(
        title: const Text(
          "Information Details",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: _textPrimary,
          ),
        ),
        backgroundColor: _bgCard,
        elevation: 0,
        actions: [
          if (_hasExistingProfile)
            TextButton.icon(
              icon: Icon(_isEditing ? Icons.close : Icons.edit, color: _accentA, size: 18),
              label: Text(
                _isEditing ? "Cancel" : "Edit Details",
                style: const TextStyle(color: _accentA, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                setState(() {
                  _isEditing = !_isEditing;
                });
              },
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoadingProfile
            ? const Center(child: CircularProgressIndicator(color: _accentA))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _hasExistingProfile ? "Schedule Next Service" : "Service Schedule Profile",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _hasExistingProfile && !_isEditing
                            ? "Your profile details are loaded. Tap 'Edit Details' above to modify them, or choose a new schedule slot below."
                            : "Provide your contact details and availability below for Washmitra verification.",
                        style: const TextStyle(color: _textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 28),

                      _buildSectionHeader("Contact Info"),
                      _buildTextField(
                        controller: _nameController,
                        label: "Full Name",
                        icon: Icons.person_outline,
                        enabled: isFieldEditable,
                        validator: (v) => v!.isEmpty ? "Enter your name" : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _phoneController,
                        label: "Mobile Number",
                        icon: Icons.phone_android,
                        keyboardType: TextInputType.phone,
                        enabled: isFieldEditable,
                        validator: (v) =>
                            v!.length < 10 ? "Enter a valid mobile number" : null,
                      ),
                      const SizedBox(height: 28),

                      _buildSectionHeader("Service Delivery Location"),
                      _buildTextField(
                        controller: _addressController,
                        label: "Complete Store or Home Address",
                        icon: Icons.location_on_outlined,
                        maxLines: 3,
                        enabled: isFieldEditable,
                        validator: (v) =>
                            v!.isEmpty ? "Address context is required" : null,
                      ),
                      const SizedBox(height: 16),

                      IgnorePointer(
                        ignoring: !isFieldEditable,
                        child: _buildLocationCard(isFieldEditable),
                      ),
                      const SizedBox(height: 28),

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

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentA,
                            foregroundColor: _bgDeep,
                            disabledBackgroundColor: _accentA.withOpacity(0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isSubmitting ? null : _submitAndGoToProfile,
                          child: _isSubmitting
                              ? const CircularProgressIndicator(
                                  color: _bgDeep, strokeWidth: 2.5)
                              : Text(
                                  _isEditing 
                                      ? "Update & Confirm" 
                                      : (_hasExistingProfile ? "Confirm Booking" : "Submit Details"),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
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

  Widget _buildLocationCard(bool editable) {
    bool hasLocation = _currentPosition != null;
    return InkWell(
      onTap: _openMapPicker,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: hasLocation ? _accentB.withOpacity(0.06) : (editable ? _bgCard : _bgCard.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasLocation
                ? _accentB.withOpacity(0.6)
                : Colors.white.withOpacity(0.06),
            width: hasLocation ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasLocation
                  ? Icons.my_location_rounded
                  : Icons.map_outlined,
              color: hasLocation ? _accentB : _textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasLocation
                        ? "Location Pinned on Map"
                        : "Open Map & Pin Location",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: hasLocation ? _accentB : (editable ? _textPrimary : _textPrimary.withOpacity(0.5)),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasLocation
                        ? "Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, Lon: ${_currentPosition!.longitude.toStringAsFixed(4)}"
                        : (!editable ? "Location confirmed via profile — Tap 'Edit Details' to change" : "Tap to open map — drag pin or auto-detect GPS"),
                    style: const TextStyle(color: _textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              hasLocation ? Icons.check_circle_rounded : Icons.chevron_right,
              color: hasLocation ? _accentB : _textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: _accentA,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        color: enabled ? _textPrimary : _textPrimary.withOpacity(0.5), 
        fontSize: 15
      ),
      cursorColor: _accentA,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: _textSecondary),
        filled: true,
        fillColor: enabled ? _bgCard : _bgCard.withOpacity(0.4),
        labelStyle: const TextStyle(color: _textSecondary, fontSize: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.02)),
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
            color: isActive
                ? _accentA.withOpacity(0.6)
                : Colors.white.withOpacity(0.06),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isActive ? _accentA : _textSecondary),
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

// ─── Map Picker Bottom Sheet ──────────────────────────────────────────────────
class _MapPickerSheet extends StatefulWidget {
  final LatLng initialLocation;
  const _MapPickerSheet({required this.initialLocation});

  @override
  State<_MapPickerSheet> createState() => _MapPickerSheetState();
}

class _MapPickerSheetState extends State<_MapPickerSheet> {
  late LatLng _center;
  bool _isFetchingGPS = false;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _center = widget.initialLocation;
  }

  Future<void> _autoDetect() async {
    setState(() => _isFetchingGPS = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Location services are disabled.';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permission denied.';
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied.';
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final newLatLng = LatLng(pos.latitude, pos.longitude);
      setState(() => _center = newLatLng);
      _mapController.move(newLatLng, 16);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingGPS = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.88,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Pin Your Location",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Drag the map to move the pin",
                        style: TextStyle(fontSize: 12, color: _textSecondary),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _isFetchingGPS ? null : _autoDetect,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _accentA.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _accentA.withOpacity(0.5)),
                    ),
                    child: _isFetchingGPS
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              color: _accentA,
                              strokeWidth: 2,
                            ),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.my_location, color: _accentA, size: 14),
                              SizedBox(width: 6),
                              Text(
                                "Auto-detect",
                                style: TextStyle(
                                  color: _accentA,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 14,
                    onPositionChanged: (position, hasGesture) {
                      if (hasGesture && position.center != null) {
                        setState(() => _center = position.center!);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.washmitra.app',
                    ),
                  ],
                ),
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_pin,
                        color: _accentA,
                        size: 48,
                        shadows: [Shadow(blurRadius: 10, color: Colors.black54)],
                      ),
                      SizedBox(height: 28),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 12,
                  right: 12,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: _bgCard.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        "📍  ${_center.latitude.toStringAsFixed(5)},  ${_center.longitude.toStringAsFixed(5)}",
                        style: const TextStyle(color: _textPrimary, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentA,
                  foregroundColor: _bgDeep,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text(
                  "Confirm This Location",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: () => Navigator.pop(context, _center),
              ),
            ),
          ),
        ],
      ),
    );
  }
}