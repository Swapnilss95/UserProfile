// service_details_page.dart
// Save at: lib/User_Services/service_details_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const _kTextPrimary = Color(0xff1a2a4e);
const _kTextMuted   = Color(0xff7a8db5);
const _kAccent      = Color(0xff1a5fc8);
const _kBgPage      = Color(0xfff0f4ff);

class ServiceDetailsPage extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;

  const ServiceDetailsPage({
    super.key,
    required this.data,
    required this.docId,
  });

  // ── Same Firestore write as AllServicesView._addToCart ────────────────────
  // Path: users/{uid}/cart/{serviceDocId}
  Future<void> _addToCart(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add items to cart.')),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('cart')
        .doc(docId)
        .set({
      'title':   data['title']   ?? 'Unknown',
      'cost':    data['cost']    ?? 0,
      'time':    data['time']    ?? 'N/A',
      'image':   data['image']   ?? '',
      'area':    data['area']    ?? '0',
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final title    = (data['title'] as String?) ?? '';
    final imageUrl = (data['image'] as String?) ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(title.isNotEmpty ? title : 'Service Details'),
        backgroundColor: const Color(0xff0a1628),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  imageUrl,
                  height: 230,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    height: 230,
                    color: _kBgPage,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined,
                          size: 48, color: _kTextMuted),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _kTextPrimary),
            ),
            const SizedBox(height: 20),
            _info(Icons.category,       'Category', data['category']),
            _info(Icons.currency_rupee, 'Price',    data['cost']),
            _info(Icons.timer,          'Duration', data['time']),
            const SizedBox(height: 20),
            const Text(
              'Description',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _kTextPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              (data['description'] as String?) ?? 'No description available.',
              style: const TextStyle(
                  fontSize: 16, color: _kTextPrimary, height: 1.5),
            ),
            const SizedBox(height: 30),
            // ── Add to Cart button — uses the same Firestore write ────────
            _AddToCartButton(
              title: title,
              onTap: () => _addToCart(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: _kAccent),
          const SizedBox(width: 10),
          Text('$label : ',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: _kTextPrimary)),
          Expanded(
            child: Text(
              value?.toString() ?? 'N/A',
              style: const TextStyle(color: _kTextPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable stateful button: idle → spinner → tick ─────────────────────────
class _AddToCartButton extends StatefulWidget {
  final String title;
  final Future<void> Function() onTap;

  const _AddToCartButton({required this.title, required this.onTap});

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
      setState(() { _loading = false; _done = true; });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.title} added to cart'),
          duration: const Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _done = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add to cart: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: _loading
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Icon(_done ? Icons.check_circle_outline : Icons.add_shopping_cart_outlined),
        label: Text(_done ? 'Added to Cart!' : 'Add to Cart'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _done ? Colors.green : const Color(0xff1a5fc8),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _handle,
      ),
    );
  }
}
