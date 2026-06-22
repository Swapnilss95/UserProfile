import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:user_login_profile/User_Login/userloginpage.dart';
import 'package:user_login_profile/userprofil.dart';
// Note: Keeping your existing imports as reference
// import 'package:user_login_profile/User_Services/add_to_cart.dart';
// import 'package:user_login_profile/User_Services/allservices.dart';
// import 'package:user_login_profile/User_Services/box_details.dart';
// import 'package:user_login_profile/User_Services/order_ststus.dart';
// import 'package:user_login_profile/User_Services/reqest_screen.dart';

class AllServicesView extends StatelessWidget {
  const AllServicesView({super.key});

  // FIX: Class-level constants must be marked as 'static const'
  static const Color bgDeep = Color(0xFF0D0D1A);
  static const Color bgCard = Color(0xFF1C1A3A);
  static const Color bgSurface = Color(0xFF0F0D24);

  static const Color accentA = Color(0xFFA78BFA);
  static const Color accentB = Color(0xFFEC4899);
  static const Color accentGlow = Color(0xFF7C3AED);

  static const Color textPrimary = Color(0xFFE8F0FE);
  static const Color textSecondary = Color(0xFF8A8AB0);
  static const Color textMuted = Color(0xFF5D5A85);

  static const Color cosmicSuccess = Color(0xFF34D399);
  static const Color cosmicDanger = Color(0xFFF87171);

  static const BoxDecoration cosmicBackgroundDecoration = BoxDecoration(
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
        border: Border.all(color: accentGlow.cd(0.22), width: 1.4),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accentGlow.withOpacity(0.18), width: 1.2),
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
      'title': serviceData['title'] ?? 'Unknown',
      'cost': serviceData['cost'] ?? 0,
      'time': serviceData['time'] ?? 'N/A',
      'image': serviceData['image'] ?? '',
      'area': serviceData['area'] ?? '0',
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

  // FIX: Added the missing _safeCost utility function
  String _safeCost(dynamic costValue) {
    if (costValue == null) return '0';
    return costValue.toString();
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
          return const Center(child: CircularProgressIndicator(color: accentA));
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
            final items = categorizedData[categoryTitle]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        shaderCallback: (b) =>
                            const LinearGradient(colors: [accentA, accentB])
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
                      final doc = items[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final title = (data['title'] as String?) ?? 'Unknown';
                      final cost = _safeCost(data['cost']);
                      final duration = (data['time'] as String?) ?? 'N/A';
                      final imageUrl = (data['image'] as String?)?.trim() ?? '';

                      return Container(
                        width: 300,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: bgCard.withOpacity(0.85),
                          border: Border.all(
                              color: accentGlow.withOpacity(0.2), width: 1.2),
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
                              // Ensure ServiceDetailsPage widget exists in your project setup
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
                                                size: 12, color: textMuted),
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
                                              const LinearGradient(colors: [
                                            accentA,
                                            accentB
                                          ]).createShader(b),
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
                                    onTap: () => _addToCart(
                                        context, doc.id, data),
                                    onViewCart: () {
                                      UserProfileScreen.switchToTab(context, 1);
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

// ─── STUB FOR MISSING WIDGET ──────────────────────────────────────────────────
// Make sure to implement your actual _AddToCartButton state management widget below 
class _AddToCartButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final VoidCallback onViewCart;

  const _AddToCartButton({
    required this.title,
    required this.onTap,
    required this.onViewCart,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.add_shopping_cart, color: AllServicesView.accentA),
      onPressed: onTap,
    );
  }
}

// ─── STUB FOR MISSING DETAILS PAGE ────────────────────────────────────────────
class ServiceDetailsPage extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  const ServiceDetailsPage({super.key, required this.data, required this.docId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(data['title'] ?? 'Details')));
  }
}