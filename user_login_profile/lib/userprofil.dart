import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:user_login_profile/User_Login/userloginpage.dart';
import 'package:user_login_profile/User_Services/add_to_cart.dart';
import 'package:user_login_profile/User_Services/all_services.dart';
import 'package:user_login_profile/User_Services/reqest_screen.dart';
import 'package:user_login_profile/User_Services/order_ststus.dart';   // keep if you have RequestsPage here

// ─── Theme ────────────────────────────────────────────────────────────────────
const _kPrimaryDark = Color(0xff0a1628);
const _kPrimaryMid  = Color(0xff1a3a7e);
const _kAccent      = Color(0xff1a5fc8);
const _kBgPage      = Color(0xfff0f4ff);
const _kBgCard      = Color(0xffffffff);
const _kBorderCard  = Color(0xffdde5f7);
const _kTextPrimary = Color(0xff1a2a4e);
const _kTextMuted   = Color(0xff7a8db5);

const _kGradient = LinearGradient(
  colors: [_kPrimaryDark, _kPrimaryMid],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ─── Screen ───────────────────────────────────────────────────────────────────
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  static void switchToServicesTab(BuildContext context) {
    context
        .findAncestorStateOfType<_UserProfileScreenState>()
        ?.updateTabIndex(0);
  }

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  int _currentIndex = 0;

  final _auth      = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Stream<DocumentSnapshot>?     _userStream;
  User?                         _currentUser;
  StreamSubscription<User?>?    _authSub;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  void updateTabIndex(int i) => setState(() => _currentIndex = i);

  void _initSession() {
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _userStream = _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .snapshots();
    }
    _authSub = _auth.userChanges().listen((u) {
      if (mounted) {
        setState(() {
          _currentUser = u;
          _userStream = u != null
              ? _firestore.collection('users').doc(u.uid).snapshots()
              : null;
        });
      }
    });
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await _authSub?.cancel();
      await _auth.signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const UserLogin()),
        (_) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout error: $e')));
    }
  }

  void _showEditDialog(Map<String, dynamic> current) {
    final nameCtrl     = TextEditingController(text: current['name'] ?? _currentUser?.displayName ?? '');
    final mobileCtrl   = TextEditingController(text: current['mobile'] ?? current['phone'] ?? '');
    final locationCtrl = TextEditingController(text: current['location'] ?? '');
    final formKey      = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Profile',
            style: TextStyle(fontWeight: FontWeight.bold, color: _kTextPrimary)),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(nameCtrl, 'Full Name', Icons.person),
                const SizedBox(height: 12),
                _field(mobileCtrl, 'Mobile Number', Icons.phone,
                    type: TextInputType.phone),
                const SizedBox(height: 12),
                _field(locationCtrl, 'Location', Icons.location_on),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: _kTextMuted)),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
                gradient: _kGradient,
                borderRadius: BorderRadius.circular(10)),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate() &&
                    _currentUser != null) {
                  Navigator.pop(ctx);
                  try {
                    await _currentUser!
                        .updateDisplayName(nameCtrl.text.trim());
                    await _firestore
                        .collection('users')
                        .doc(_currentUser!.uid)
                        .set({
                      'name':     nameCtrl.text.trim(),
                      'mobile':   mobileCtrl.text.trim(),
                      'location': locationCtrl.text.trim(),
                      'email':    _currentUser!.email,
                    }, SetOptions(merge: true));
                    await _currentUser!.reload();
                    if (!mounted) return;
                    setState(() => _currentUser = _auth.currentUser);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Profile updated successfully!')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text('Update failed: $e')));
                  }
                }
              },
              child: const Text('Save',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  TextFormField _field(
      TextEditingController ctrl, String label, IconData icon,
      {TextInputType? type}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _kAccent),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ PaymentScreen now uses clean constructor (no extra required params)
    final List<Widget> screens = [
      const ServicesScreen(),
      const CartScreen(),
      const RequestServiceScreen(jobDocId: '',),
      const PaymentScreen(),   // ✅ FIXED
    ];

    final List<String> titles = [
      'Services', 'Cart', 'Requests', 'Order Status'
    ];

    return Scaffold(
      backgroundColor: _kBgPage,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(gradient: _kGradient),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.white,
            title: Text(titles[_currentIndex],
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 18)),
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.account_circle_outlined,
                    size: 28),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    size: 24),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),

      // ── Drawer ─────────────────────────────────────────────────────────
      drawer: SizedBox(
        width: MediaQuery.of(context).size.width * 0.78,
        child: Drawer(
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.horizontal(
                  right: Radius.circular(24))),
          child: _userStream == null
              ? _guestDrawer(context)
              : StreamBuilder<DocumentSnapshot>(
                  stream: _userStream,
                  builder: (context, snap) {
                    String mobile   = 'Not provided';
                    String location = 'Not provided';
                    String name     =
                        _currentUser?.displayName ?? 'User';
                    Map<String, dynamic> raw = {};

                    if (snap.hasError) {
                      log('Firestore drawer error: ${snap.error}');
                    }
                    if (snap.hasData && snap.data!.exists) {
                      final d = snap.data!.data()
                          as Map<String, dynamic>?;
                      if (d != null) {
                        raw      = d;
                        mobile   = d['mobile'] ?? d['phone'] ?? 'Not provided';
                        location = d['location'] ?? 'Not provided';
                        name     = d['name'] ?? _currentUser?.displayName ?? 'User';
                      }
                    }

                    final loading =
                        snap.connectionState ==
                            ConnectionState.waiting &&
                        !snap.hasData;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _drawerHeader(name),
                        const SizedBox(height: 8),
                        _infoTile(Icons.phone_outlined, 'Mobile',
                            loading ? null : mobile),
                        _infoTile(Icons.location_on_outlined,
                            'Location',
                            loading ? null : location),
                        const Divider(
                            color: _kBorderCard,
                            height: 24,
                            indent: 16,
                            endIndent: 16),
                        _actionTile(
                          Icons.edit_outlined,
                          'Edit profile',
                          _kAccent,
                          () {
                            Navigator.pop(context);
                            _showEditDialog(raw);
                          },
                        ),
                        _actionTile(
                          Icons.settings_outlined,
                          'Settings',
                          _kTextPrimary,
                          () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        const Divider(
                            color: _kBorderCard,
                            height: 1,
                            indent: 16,
                            endIndent: 16),
                        _actionTile(
                          Icons.logout_outlined,
                          'Log Out',
                          const Color(0xffe05252),
                          () {
                            Navigator.pop(context);
                            _logout(context);
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                ),
        ),
      ),

      // ── Body ────────────────────────────────────────────────────────────
      body: IndexedStack(index: _currentIndex, children: screens),

      // ── Bottom Nav ──────────────────────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: _kBgCard,
          border: Border(
              top: BorderSide(color: _kBorderCard, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: _kAccent,
          unselectedItemColor: _kTextMuted,
          selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 11),
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

  // ── Drawer helpers ─────────────────────────────────────────────────────────
  Widget _drawerHeader(String name) => Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: _kGradient),
        padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 62, height: 62,
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
            Text(name,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
            const SizedBox(height: 2),
            Text(_currentUser?.email ?? 'No email linked',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.65))),
          ],
        ),
      );

  Widget _infoTile(IconData icon, String label, String? value) =>
      Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _kTextMuted),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: _kTextMuted)),
                const SizedBox(height: 1),
                value == null
                    ? const SizedBox(
                        height: 14, width: 14,
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

  Widget _actionTile(
          IconData icon, String label, Color color, VoidCallback onTap) =>
      ListTile(
        dense: true,
        leading: Icon(icon, color: color, size: 22),
        title: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        onTap: onTap,
      );

  Widget _guestDrawer(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _drawerHeader(_currentUser?.displayName ?? 'Loading...'),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
                child: CircularProgressIndicator(color: _kAccent)),
          ),
          const Spacer(),
          const Divider(color: _kBorderCard),
          _actionTile(
              Icons.logout_outlined, 'Log Out',
              const Color(0xffe05252), () {
            Navigator.pop(context);
            _logout(context);
          }),
          const SizedBox(height: 12),
        ],
      );
}
