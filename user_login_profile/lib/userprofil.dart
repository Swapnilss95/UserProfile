import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:user_login_profile/User_Login/userloginpage.dart';
import 'package:user_login_profile/User_Services/add_to_cart.dart';
import 'package:user_login_profile/User_Services/all_services.dart';
import 'package:user_login_profile/User_Services/order_ststus.dart';
import 'package:user_login_profile/User_Services/reqest_screen.dart';

// ─── Theme Constants ─────────────────────────────────────────────────────────
const _kPrimaryDark  = Color(0xff0a1628);   // deep navy
const _kPrimaryMid   = Color(0xff1a3a7e);   // mid blue
const _kAccent       = Color(0xff1a5fc8);   // vivid blue accent
const _kBgPage       = Color(0xfff0f4ff);   // soft lavender-white
const _kBgCard       = Color(0xffffffff);
const _kBorderCard   = Color(0xffdde5f7);
const _kTextPrimary  = Color(0xff1a2a4e);
const _kTextMuted    = Color(0xff7a8db5);

const _kGradient = LinearGradient(
  colors: [_kPrimaryDark, _kPrimaryMid],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ─── Main Screen ─────────────────────────────────────────────────────────────
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  static void switchToServicesTab(BuildContext context) {
    final state = context.findAncestorStateOfType<_UserProfileScreenState>();
    state?.updateTabIndex(0);
  }

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  int _currentIndex = 0;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<DocumentSnapshot>? _userStream;
  User? _currentUser;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _initializeUserSession();
  }

  void updateTabIndex(int index) => setState(() => _currentIndex = index);

  void _initializeUserSession() {
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _userStream = _firestore.collection('users').doc(_currentUser!.uid).snapshots();
    }
    _authSubscription = _auth.userChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
          _userStream = user != null
              ? _firestore.collection('users').doc(user.uid).snapshots()
              : null;
        });
      }
    });
  }

  Future<void> _logoutUser(BuildContext context) async {
    try {
      await _authSubscription?.cancel();
      await _auth.signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const UserLogin()),
        (_) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error logging out: $e')));
    }
  }

  void _showEditProfileDialog(Map<String, dynamic> currentData) {
    final nameController = TextEditingController(
        text: currentData['name'] ?? _currentUser?.displayName ?? '');
    final mobileController = TextEditingController(
        text: currentData['mobile'] ?? currentData['phone'] ?? '');
    final locationController =
        TextEditingController(text: currentData['location'] ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Profile',
            style: TextStyle(fontWeight: FontWeight.bold, color: _kTextPrimary)),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildField(nameController, 'Full Name', Icons.person),
                const SizedBox(height: 12),
                _buildField(mobileController, 'Mobile Number', Icons.phone,
                    type: TextInputType.phone),
                const SizedBox(height: 12),
                _buildField(locationController, 'Location', Icons.location_on),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: _kTextMuted)),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
                gradient: _kGradient, borderRadius: BorderRadius.circular(10)),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate() && _currentUser != null) {
                  Navigator.pop(dialogContext);
                  try {
                    await _currentUser!
                        .updateDisplayName(nameController.text.trim());
                    await _firestore
                        .collection('users')
                        .doc(_currentUser!.uid)
                        .set({
                      'name': nameController.text.trim(),
                      'mobile': mobileController.text.trim(),
                      'location': locationController.text.trim(),
                      'email': _currentUser!.email,
                    }, SetOptions(merge: true));
                    await _currentUser!.reload();
                    if (!mounted) return;
                    setState(() => _currentUser = _auth.currentUser);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Profile updated successfully!')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update profile: $e')),
                    );
                  }
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  TextFormField _buildField(
      TextEditingController ctrl, String label, IconData icon,
      {TextInputType? type}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _kAccent),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kAccent),
        ),
      ),
      validator: label == 'Full Name'
          ? (v) => v!.trim().isEmpty ? 'Name cannot be empty' : null
          : null,
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const ServicesScreen(),
      const CartScreen(),
      const RequestsPage(),
      const PaymentScreen(isSuccess: true, transactionRef: 'N/A', amount: '0.00'),
    ];

    final List<String> titles = ['Services', 'Cart', 'Requests', 'Order Status'];

    return Scaffold(
      backgroundColor: _kBgPage,
      // ── App Bar ──────────────────────────────────────────────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(gradient: _kGradient),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.white,
            title: Text(
              titles[_currentIndex],
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.account_circle_outlined, size: 28),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, size: 24),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),

      // ── Drawer ───────────────────────────────────────────────────────────
      drawer: SizedBox(
        width: MediaQuery.of(context).size.width * 0.78,
        child: Drawer(
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.horizontal(right: Radius.circular(24))),
          child: _userStream == null
              ? _buildGuestOrLoadingDrawer(context)
              : StreamBuilder<DocumentSnapshot>(
                  stream: _userStream,
                  builder: (context, snapshot) {
                    String mobile = 'Not provided';
                    String location = 'Not provided';
                    String displayName =
                        _currentUser?.displayName ?? 'User';
                    Map<String, dynamic> rawData = {};

                    if (snapshot.hasError) log('Firestore error: ${snapshot.error}');

                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      if (data != null) {
                        rawData = data;
                        mobile =
                            data['mobile'] ?? data['phone'] ?? 'Not provided';
                        location = data['location'] ?? 'Not provided';
                        displayName =
                            data['name'] ?? _currentUser?.displayName ?? 'User';
                      }
                    }

                    final isLoading =
                        snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Gradient header
                        Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(gradient: _kGradient),
                          padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 62,
                                height: 62,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.18),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.4),
                                      width: 2),
                                ),
                                child: const Icon(Icons.person_outline,
                                    size: 34, color: Colors.white),
                              ),
                              const SizedBox(height: 12),
                              Text(displayName,
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                              const SizedBox(height: 2),
                              Text(
                                  _currentUser?.email ?? 'No email linked',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.65))),
                            ],
                          ),
                        ),

                        // Info tiles
                        const SizedBox(height: 8),
                        _drawerInfoTile(Icons.phone_outlined, 'Mobile',
                            isLoading ? null : mobile),
                        _drawerInfoTile(Icons.location_on_outlined, 'Location',
                            isLoading ? null : location),

                        const Divider(color: _kBorderCard, height: 24, indent: 16, endIndent: 16),

                        _drawerActionTile(
                          Icons.edit_outlined,
                          'Edit profile information',
                          _kAccent,
                          () {
                            Navigator.pop(context);
                            _showEditProfileDialog(rawData);
                          },
                        ),
                        _drawerActionTile(
                          Icons.settings_outlined,
                          'Settings',
                          _kTextPrimary,
                          () => Navigator.pop(context),
                        ),

                        const Spacer(),
                        const Divider(color: _kBorderCard, height: 1, indent: 16, endIndent: 16),

                        _drawerActionTile(
                          Icons.logout_outlined,
                          'Log Out',
                          const Color(0xffe05252),
                          () {
                            Navigator.pop(context);
                            _logoutUser(context);
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                ),
        ),
      ),

      // ── Body ─────────────────────────────────────────────────────────────
      body: IndexedStack(index: _currentIndex, children: screens),

      // ── Bottom Nav ───────────────────────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: _kBgCard,
          border: Border(top: BorderSide(color: _kBorderCard, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: _kAccent,
          unselectedItemColor: _kTextMuted,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.design_services_outlined),
                activeIcon: Icon(Icons.design_services),
                label: 'Services'),
            BottomNavigationBarItem(
                icon: Icon(Icons.shopping_cart_outlined),
                activeIcon: Icon(Icons.shopping_cart),
                label: 'Cart'),
            BottomNavigationBarItem(
                icon: Icon(Icons.assignment_turned_in_outlined),
                activeIcon: Icon(Icons.assignment_turned_in),
                label: 'Requests'),
            BottomNavigationBarItem(
                icon: Icon(Icons.check_circle_outline),
                activeIcon: Icon(Icons.check_circle),
                label: 'Order Status'),
          ],
        ),
      ),
    );
  }

  // ── Helper Widgets ────────────────────────────────────────────────────────

  Widget _drawerInfoTile(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _kTextMuted),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(fontSize: 11, color: _kTextMuted)),
              const SizedBox(height: 1),
              value == null
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _kAccent))
                  : Text(value,
                      style: const TextStyle(
                          fontSize: 13, color: _kTextPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _drawerActionTile(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color, size: 22),
      title: Text(label,
          style: TextStyle(
              color: color, fontSize: 14, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }

  Widget _buildGuestOrLoadingDrawer(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(gradient: _kGradient),
          padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.18),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.4), width: 2),
                ),
                child: const Icon(Icons.person_outline,
                    size: 34, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(_currentUser?.displayName ?? 'Loading...',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              const SizedBox(height: 2),
              Text(_currentUser?.email ?? '',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.65))),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(20),
          child: Center(
              child: CircularProgressIndicator(color: _kAccent)),
        ),
        const Spacer(),
        const Divider(color: _kBorderCard),
        _drawerActionTile(Icons.logout_outlined, 'Log Out',
            const Color(0xffe05252), () {
          Navigator.pop(context);
          _logoutUser(context);
        }),
        const SizedBox(height: 12),
      ],
    );
  }
}