import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:user_login_profile/User_Login/userloginpage.dart';
import 'package:user_login_profile/User_Services/add_to_cart.dart';
import 'package:user_login_profile/User_Services/box_details.dart';
import 'package:user_login_profile/User_Services/order_ststus.dart';

// ── Cosmic Theme (copied from login page) ────────────────────────────
const Color bgDeep    = Color(0xFF0D0D1A);
const Color bgCard    = Color(0xFF1C1A3A);
const Color bgSurface = Color(0xFF0F0D24);

const Color accentA    = Color(0xFFA78BFA);
const Color accentB    = Color(0xFFEC4899);
const Color accentGlow = Color(0xFF7C3AED);

const Color textPrimary   = Color(0xFFE8F0FE);
const Color textSecondary = Color(0xFF8A8AB0);
const Color textMuted     = Color(0xFF5D5A85);

const Color cosmicSuccess = Color(0xFF34D399);
const Color cosmicDanger  = Color(0xFFF87171);

const BoxDecoration cosmicBackgroundDecoration = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bgDeep, Color(0xFF12102B), Color(0xFF1A0A2E)],
    stops: [0.0, 0.5, 1.0],
  ),
);

BoxDecoration buildCosmicCardDecoration() => BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      color: bgCard.withOpacity(0.85),
      border: Border.all(color: accentGlow.withOpacity(0.22), width: 1.4),
      boxShadow: [
        BoxShadow(
          color: accentGlow.withOpacity(0.12),
          blurRadius: 40,
          offset: const Offset(0, 16),
        ),
      ],
    );

InputDecoration buildCosmicInputDecoration({
  required String labelText,
  required IconData prefixIcon,
  Widget? suffixIcon,
}) =>
    InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: textSecondary, fontSize: 13.5),
      prefixIcon: Icon(prefixIcon, color: accentA, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: bgSurface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            BorderSide(color: accentGlow.withOpacity(0.18), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: accentA, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            BorderSide(color: cosmicDanger.withOpacity(0.6), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: cosmicDanger, width: 1.8),
      ),
    );

BoxDecoration buildCosmicButtonDecoration() => BoxDecoration(
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

// Safely converts any Firestore field to a display-ready cost string
String _safeCost(dynamic v) {
  if (v == null) return '0';
  if (v is num) return v.toStringAsFixed(v % 1 == 0 ? 0 : 2);
  return v.toString();
}

// ─── Main Screen Container ────────────────────────────────────────────────────
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  static void switchToTab(BuildContext context, int index) {
    context
        .findAncestorStateOfType<_UserProfileScreenState>()
        ?.updateTabIndex(index);
  }

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  int _currentIndex = 0;

  final _auth      = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Stream<DocumentSnapshot>? _userStream;
  User?                      _currentUser;
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  void updateTabIndex(int i) {
    if (mounted) setState(() => _currentIndex = i);
  }

  void _initSession() {
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _userStream =
          _firestore.collection('users').doc(_currentUser!.uid).snapshots();
    }
    _authSub = _auth.userChanges().listen((u) {
      if (mounted) {
        setState(() {
          _currentUser = u;
          _userStream  = u != null
              ? _firestore.collection('users').doc(u.uid).snapshots()
              : null;
        });
      }
    });
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await _auth.signOut();
      await _authSub?.cancel();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const UserLogin()),
        (_) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Logout error: $e')));
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(color: textPrimary)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: bgCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> current) {
    final nameCtrl = TextEditingController(
        text: current['name'] ?? _currentUser?.displayName ?? '');
    final mobileCtrl = TextEditingController(
        text: current['mobile'] ?? current['phone'] ?? '');
    final locationCtrl =
        TextEditingController(text: current['location'] ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: bgCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border:
                Border.all(color: accentGlow.withOpacity(0.22), width: 1.4),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dialog header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                            colors: [accentGlow, accentB]),
                      ),
                      child: const Icon(Icons.edit_outlined,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    ShaderMask(
                      shaderCallback: (b) => const LinearGradient(
                              colors: [accentA, accentB])
                          .createShader(b),
                      child: const Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _cosmicField(nameCtrl, 'Full Name', Icons.person),
                      const SizedBox(height: 14),
                      _cosmicField(
                          mobileCtrl, 'Mobile Number', Icons.phone,
                          type: TextInputType.phone),
                      const SizedBox(height: 14),
                      _cosmicField(
                          locationCtrl, 'Location', Icons.location_on),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: textSecondary, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 44,
                      child: DecoratedBox(
                        decoration: buildCosmicButtonDecoration(),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24),
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
                                setState(
                                    () => _currentUser = _auth.currentUser);
                                _showMessage('Profile updated successfully!');
                              } catch (e) {
                                if (!mounted) return;
                                _showMessage('Update failed: $e');
                              }
                            }
                          },
                          child: const Text(
                            'Save',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextFormField _cosmicField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? type,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: type,
        style: const TextStyle(color: textPrimary, fontSize: 14.5),
        cursorColor: accentA,
        decoration: buildCosmicInputDecoration(
            labelText: label, prefixIcon: icon),
        validator: label == 'Full Name'
            ? (v) => v!.trim().isEmpty ? 'Name cannot be empty' : null
            : null,
      );

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const AllServicesView(),
      const CartScreen(),
      const OrderStatusScreen(),
    ];

    final List<String> titles = [
      'Services',
      'Cart',
      'Order Status',
    ];

    return Scaffold(
      backgroundColor: bgDeep,
      // ── AppBar ──────────────────────────────────────────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [bgDeep, Color(0xFF12102B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border(
              bottom: BorderSide(
                  color: Color(0xFF7C3AED), // accentGlow
                  width: 0.5),
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: textPrimary,
            title: ShaderMask(
              shaderCallback: (b) =>
                  const LinearGradient(colors: [accentA, accentB])
                      .createShader(b),
              child: Text(
                titles[_currentIndex],
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.account_circle_outlined,
                    size: 28, color: accentA),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    size: 24, color: textSecondary),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),

      // ── Drawer ──────────────────────────────────────────────────────
      drawer: SizedBox(
        width: MediaQuery.of(context).size.width * 0.78,
        child: Drawer(
          backgroundColor: bgDeep,
          shape: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.horizontal(right: Radius.circular(24))),
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

                    if (snap.hasData && snap.data!.exists) {
                      final d = snap.data!.data();
                      if (d != null && d is Map<String, dynamic>) {
                        raw      = d;
                        mobile   = (d['mobile'] ?? d['phone'])
                                ?.toString() ??
                            'Not provided';
                        location =
                            d['location']?.toString() ?? 'Not provided';
                        name     = d['name']?.toString() ??
                            _currentUser?.displayName ??
                            'User';
                      }
                    }

                    final loading =
                        snap.connectionState == ConnectionState.waiting &&
                            !snap.hasData;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _drawerHeader(name),
                        const SizedBox(height: 8),
                        _infoTile(Icons.phone_outlined, 'Mobile',
                            loading ? null : mobile),
                        _infoTile(Icons.location_on_outlined, 'Location',
                            loading ? null : location),
                        Divider(
                            color: accentGlow.withOpacity(0.18),
                            height: 24,
                            indent: 16,
                            endIndent: 16),
                        _actionTile(
                            Icons.edit_outlined, 'Edit profile', accentA,
                            () {
                          Navigator.pop(context);
                          _showEditDialog(raw);
                        }),
                        _actionTile(Icons.settings_outlined, 'Settings',
                            textSecondary,
                            () => Navigator.pop(context)),
                        const Spacer(),
                        Divider(
                            color: accentGlow.withOpacity(0.18),
                            height: 1,
                            indent: 16,
                            endIndent: 16),
                        _actionTile(Icons.logout_outlined, 'Log Out',
                            cosmicDanger, () {
                          Navigator.pop(context);
                          _logout(context);
                        }),
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                ),
        ),
      ),

      body: Container(
        decoration: cosmicBackgroundDecoration,
        child: IndexedStack(
          index: _currentIndex.clamp(0, screens.length - 1),
          children: screens,
        ),
      ),

      // ── Bottom Nav ───────────────────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: bgCard,
          border: Border(
              top: BorderSide(color: accentGlow.withOpacity(0.22), width: 0.8)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex.clamp(0, titles.length - 1),
          onTap: (i) => setState(() => _currentIndex = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: accentA,
          unselectedItemColor: textMuted,
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
                icon: Icon(Icons.receipt_long_outlined),
                activeIcon: Icon(Icons.receipt_long),
                label: 'Order Status'),
          ],
        ),
      ),
    );
  }

  // ── Drawer Widgets ─────────────────────────────────────────────────
  Widget _drawerHeader(String name) => Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [bgDeep, Color(0xFF1A0A2E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border(
            bottom: BorderSide(color: Color(0xFF7C3AED), width: 0.5),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar ring (matches login page style)
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [accentGlow, accentB],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentGlow.withOpacity(0.5),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: bgDeep,
                  ),
                  child: const Icon(Icons.person,
                      size: 32, color: accentA),
                ),
              ),
            ),
            const SizedBox(height: 14),
            ShaderMask(
              shaderCallback: (b) =>
                  const LinearGradient(colors: [accentA, accentB])
                      .createShader(b),
              child: Text(
                name,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _currentUser?.email ?? 'No email linked',
              style: const TextStyle(fontSize: 12, color: textMuted),
            ),
          ],
        ),
      );

  Widget _infoTile(IconData icon, String label, String? value) => Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: accentGlow),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(fontSize: 11, color: textMuted)),
                const SizedBox(height: 2),
                value == null
                    ? const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: accentA))
                    : Text(value,
                        style: const TextStyle(
                            fontSize: 13, color: textPrimary)),
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
                child: CircularProgressIndicator(color: accentA)),
          ),
          const Spacer(),
          Divider(color: accentGlow.withOpacity(0.18)),
          _actionTile(Icons.logout_outlined, 'Log Out', cosmicDanger, () {
            Navigator.pop(context);
            _logout(context);
          }),
          const SizedBox(height: 12),
        ],
      );
}

// ─── Services Category-Wise View ──────────────────────────────────────────────
class AllServicesView extends StatelessWidget {
  const AllServicesView({super.key});

  Future<void> _addToCart(
    BuildContext context,
    String docId,
    Map<String, dynamic> serviceData,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showCosmicSnack(context, 'Please log in to add items to cart.');
      return;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('cart')
        .doc(docId)
        .set({
      'title':   serviceData['title'] ?? 'Unknown',
      'cost':    serviceData['cost'] ?? 0,
      'time':    serviceData['time'] ?? 'N/A',
      'image':   serviceData['image'] ?? '',
      'area':    serviceData['area'] ?? '0',
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  void _showCosmicSnack(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(color: textPrimary)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('services').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: textSecondary)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: accentA));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.layers_clear_outlined,
                    size: 48, color: textMuted.withOpacity(0.6)),
                const SizedBox(height: 12),
                const Text('No services found.',
                    style: TextStyle(color: textSecondary, fontSize: 14)),
              ],
            ),
          );
        }

        final Map<String, List<QueryDocumentSnapshot>> categorizedData = {};
        for (var doc in docs) {
          final raw = doc.data();
          if (raw is! Map<String, dynamic>) continue;
          final category = (raw['category'] as String?) ?? 'General';
          categorizedData.putIfAbsent(category, () => []).add(doc);
        }

        if (categorizedData.isEmpty) {
          return const Center(
            child: Text('No valid services found.',
                style: TextStyle(color: textSecondary, fontSize: 14)),
          );
        }

        final categories = categorizedData.keys.toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: categories.length,
          itemBuilder: (context, catIndex) {
            final categoryTitle = categories[catIndex];
            final items         = categorizedData[categoryTitle]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category label with cosmic gradient accent
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 16,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: const LinearGradient(
                            colors: [accentA, accentB],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                                colors: [accentA, accentB])
                            .createShader(b),
                        child: Text(
                          categoryTitle.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 148,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final doc      = items[index];
                      final data     = doc.data() as Map<String, dynamic>;
                      final title    = (data['title'] as String?) ?? 'Unknown';
                      final cost     = _safeCost(data['cost']);
                      final duration = (data['time'] as String?) ?? 'N/A';
                      final imageUrl =
                          (data['image'] as String?)?.trim() ?? '';

                      return Container(
                        width: 300,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: bgCard.withOpacity(0.85),
                          border: Border.all(
                              color: accentGlow.withOpacity(0.2),
                              width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: accentGlow.withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            splashColor: accentGlow.withOpacity(0.15),
                            highlightColor: accentGlow.withOpacity(0.05),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ServiceDetailsPage(
                                    data: data,
                                    docId: doc.id,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Service image
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: imageUrl.isNotEmpty
                                        ? Image.network(
                                            imageUrl,
                                            width: 75,
                                            height: 75,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) =>
                                                Container(
                                              width: 75,
                                              height: 75,
                                              color: bgSurface,
                                              child: const Icon(
                                                  Icons.broken_image_outlined,
                                                  color: textMuted),
                                            ),
                                            loadingBuilder:
                                                (c, child, progress) {
                                              if (progress == null) {
                                                return child;
                                              }
                                              return Container(
                                                width: 75,
                                                height: 75,
                                                color: bgSurface,
                                                child: const Center(
                                                  child: SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: accentA,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          )
                                        : Container(
                                            width: 75,
                                            height: 75,
                                            color: bgSurface,
                                            child: const Icon(
                                                Icons.image_outlined,
                                                color: textMuted),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: textPrimary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 5),
                                        Row(
                                          children: [
                                            const Icon(Icons.access_time,
                                                size: 12,
                                                color: textMuted),
                                            const SizedBox(width: 4),
                                            Text(duration,
                                                style: const TextStyle(
                                                    color: textMuted,
                                                    fontSize: 11)),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        ShaderMask(
                                          shaderCallback: (b) =>
                                              const LinearGradient(
                                                      colors: [accentA, accentB])
                                                  .createShader(b),
                                          child: Text(
                                            '₹$cost',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _AddToCartButton(
                                    title: title,
                                    onTap: () =>
                                        _addToCart(context, doc.id, data),
                                    onViewCart: () {
                                      UserProfileScreen.switchToTab(
                                          context, 1);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        );
      },
    );
  }
}

// ─── Stateful cart button ─────────────────────────────────────────────────────
class _AddToCartButton extends StatefulWidget {
  final String title;
  final Future<void> Function() onTap;
  final VoidCallback onViewCart;

  const _AddToCartButton({
    required this.title,
    required this.onTap,
    required this.onViewCart,
  });

  @override
  State<_AddToCartButton> createState() => _AddToCartButtonState();
}

class _AddToCartButtonState extends State<_AddToCartButton> {
  bool _loading = false;
  bool _done    = false;

  Future<void> _handle() async {
    if (_loading || _done) return;
    setState(() => _loading = true);

    try {
      await widget.onTap();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _done    = true;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.title} added to cart',
              style: const TextStyle(color: textPrimary)),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: bgCard,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          action: SnackBarAction(
            label: 'View Cart',
            textColor: accentA,
            onPressed: widget.onViewCart,
          ),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _done = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add to cart: $e',
              style: const TextStyle(color: textPrimary)),
          backgroundColor: bgCard,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _done
              ? cosmicSuccess.withOpacity(0.5)
              : accentGlow.withOpacity(0.3),
          width: 1,
        ),
        color: bgSurface,
      ),
      child: IconButton(
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: accentA),
              )
            : Icon(
                _done
                    ? Icons.check_circle_outline
                    : Icons.add_shopping_cart_outlined,
                color: _done ? cosmicSuccess : accentA,
                size: 22,
              ),
        padding: const EdgeInsets.all(8),
        onPressed: _handle,
      ),
    );
  }
}