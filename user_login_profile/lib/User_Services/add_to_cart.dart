// add_to_cart.dart  (CartScreen)
// Save at: lib/User_Services/add_to_cart.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:user_login_profile/UserInformation/information.dart';

const Color _bgDeep        = Color(0xFF080C14);
const Color _bgCard        = Color(0xFF0F1624);
const Color _bgSurface     = Color(0xFF141E2E);
const Color _accentA       = Color(0xFF00D4AA);
const Color _accentB       = Color(0xFF00A86B);
const Color _textPrimary   = Color(0xFFE8F0FE);
const Color _textSecondary = Color(0xFF8899B0);
const Color _textMuted     = Color(0xFF4A5A72);
const Color _errorColor    = Color(0xFFFF5C6E);

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isProcessingPayment = false;

  // ── Remove item ────────────────────────────────────────────────────────────
  Future<void> _removeFromCart(
    BuildContext context,
    String userId,
    String docId,
    String itemTitle,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cart')
          .doc(docId)
          .delete();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$itemTitle removed from cart.'),
          backgroundColor: const Color(0xFF1C2A3A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove: $e'),
          backgroundColor: _errorColor.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  double _parseCost(dynamic costField) {
    if (costField == null) return 0.0;
    if (costField is num) return costField.toDouble();
    final costStr = costField.toString().replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(costStr) ?? 0.0;
  }

  String _formatCost(dynamic costField) {
    if (costField == null) return '₹0';
    if (costField is num) return '₹${costField.toStringAsFixed(0)}';
    final s = costField.toString().trim();
    return s.startsWith('₹') ? s : '₹$s';
  }

  // FIX: small helper so every SnackBar call is guarded by mounted/context.mounted
  // and so we can never have a "swallowed" failure with zero feedback.
  void _showSnack(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? _errorColor : const Color(0xFF1C2A3A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Checkout ───────────────────────────────────────────────────────────────
  Future<void> _initiateCheckout(double totalAmount, String userId) async {
    debugPrint('CHECKOUT: tapped, totalAmount=$totalAmount userId=$userId');

    if (totalAmount <= 0) {
      _showSnack('Cart total must be greater than ₹0.');
      return;
    }

    setState(() => _isProcessingPayment = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final userData = userDoc.data() ?? {};
      debugPrint('CHECKOUT: userData=$userData');

      final String mobile  = userData['mobile']?.toString() ?? '';
      final String address = userData['location'] ?? userData['address'] ?? '';

      if (!mounted) return;
      setState(() => _isProcessingPayment = false);

      if (mobile.isNotEmpty && address.isNotEmpty) {
        _showDateTimePickerOverlay(userId, totalAmount);
      } else {
        final String txnRef    = "TXN_${DateTime.now().millisecondsSinceEpoch}";
        final String amountStr = totalAmount.toStringAsFixed(2);
        _showPaymentConfirmationDialog(userId, txnRef, amountStr,
            isReturning: false);
      }
    } catch (e, st) {
      debugPrint('CHECKOUT ERROR: $e\n$st');
      if (!mounted) return;
      setState(() => _isProcessingPayment = false);
      _showSnack('Checkout error: $e', isError: true);
    }
  }

  // ── Schedule picker ────────────────────────────────────────────────────────
  void _showDateTimePickerOverlay(String userId, double totalAmount) {
    DateTime selectedDate =
        DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);

    showModalBottomSheet(
      context: context,
      backgroundColor: _bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  24, 24, 24,
                  MediaQuery.of(sheetContext).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Schedule',
                      style: TextStyle(
                          color: _textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text(
                      'Your address and contact details are securely loaded from your profile.',
                      style: TextStyle(
                          color: _textSecondary, fontSize: 13)),
                  const SizedBox(height: 20),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_rounded,
                        color: _accentA),
                    title: const Text('Service Date',
                        style: TextStyle(
                            color: _textSecondary, fontSize: 13)),
                    subtitle: Text(
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.arrow_drop_down,
                        color: _textSecondary),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: sheetContext,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now()
                            .add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                  ),
                  const Divider(color: Colors.white10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time_rounded,
                        color: _accentA),
                    title: const Text('Preferred Time Slot',
                        style: TextStyle(
                            color: _textSecondary, fontSize: 13)),
                    subtitle: Text(selectedTime.format(sheetContext),
                        style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.arrow_drop_down,
                        color: _textSecondary),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: sheetContext,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setModalState(() => selectedTime = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                            colors: [_accentB, _accentA]),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          debugPrint('CHECKOUT: Proceed to Payment tapped');
                          Navigator.pop(sheetContext);
                          final String txnRef =
                              "TXN_${DateTime.now().millisecondsSinceEpoch}";
                          final String amountStr =
                              totalAmount.toStringAsFixed(2);
                          _showPaymentConfirmationDialog(
                            userId,
                            txnRef,
                            amountStr,
                            isReturning: true,
                            customSchedule:
                                "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}"
                                " at ${selectedTime.format(sheetContext)}",
                          );
                        },
                        child: const Text('Proceed to Payment',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Place order ────────────────────────────────────────────────────────────
  Future<void> _processOrderPlacement(
    String userId,
    String txnRef,
    String amount, {
    required bool isReturning,
    String? scheduledTime,
  }) async {
    debugPrint('ORDER: _processOrderPlacement start userId=$userId txnRef=$txnRef amount=$amount');
    final firestore = FirebaseFirestore.instance;

    try {
      final cartSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('cart')
          .get();

      debugPrint('ORDER: cart fetched, ${cartSnapshot.docs.length} items');

      // FIX: was a silent `return` with zero feedback if the cart looked
      // empty at write time — that is exactly what produces "nothing
      // visible happens at all". Now it always tells the user.
      if (cartSnapshot.docs.isEmpty) {
        debugPrint('ORDER: ABORTED — cart is empty at write time');
        _showSnack('Your cart is empty — nothing to order.', isError: true);
        return;
      }

      final userDoc =
          await firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? {};

      final String clientName    = userData['name']     ?? 'Unknown';
      final String clientMobile  = userData['mobile']?.toString() ?? '';
      final String clientAddress =
          userData['location'] ?? userData['address'] ?? '';

      final List<Map<String, dynamic>> orderItems =
          cartSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'cartItemId': doc.id,
          'title': data['title']  ?? 'Unknown Item',
          'cost':  _formatCost(data['cost']),
          'area':  data['area']   ?? '0',
          'time':  scheduledTime ?? data['time'] ?? 'N/A',
          'image': data['image']  ?? '',
        };
      }).toList();

      debugPrint('ORDER: writing Jobs doc with ${orderItems.length} items, address="$clientAddress"');

      final docRef = await firestore.collection('Jobs').add({
        'userId':         userId,
        'clientName':     clientName,
        'mobile':         clientMobile,
        'address':        clientAddress,
        'serviceType':    orderItems.isNotEmpty
            ? orderItems[0]['title']
            : 'Multiple Services',
        'items':          orderItems,
        'totalAmount':    amount,
        'transactionRef': txnRef,
        'washmitraId':    null,
        'status':         'request',
        'orderStatus':    'Pending Approval',
        'createdAt':      FieldValue.serverTimestamp(),
      });

      debugPrint('ORDER: Jobs doc written successfully, id=${docRef.id}');

      // Delete all cart items atomically
      final WriteBatch batch = firestore.batch();
      for (final doc in cartSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      debugPrint('ORDER: cart cleared');

      if (!mounted) {
        debugPrint('ORDER: widget unmounted after write — order WAS saved (id=${docRef.id}), just no UI feedback shown');
        return;
      }

      if (isReturning) {
        _showSnack('Order placed successfully! Check job tracker.');
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                InformationScreen(jobDocId: docRef.id),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('ORDER ERROR: $e\n$st');
      if (!mounted) return;
      _showSnack('Order failed: $e', isError: true);
    }
  }

  // ── Payment confirmation dialog ────────────────────────────────────────────
  void _showPaymentConfirmationDialog(
    String userId,
    String txnRef,
    String amount, {
    required bool isReturning,
    String? customSchedule,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (dialogContext) => Dialog(
        backgroundColor: _bgCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accentA.withOpacity(0.12),
                  border: Border.all(
                      color: _accentA.withOpacity(0.3), width: 1.5),
                ),
                child: const Icon(Icons.payment_rounded,
                    color: _accentA, size: 30),
              ),
              const SizedBox(height: 16),
              const Text('Confirm Payment',
                  style: TextStyle(
                      color: _textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Simulation mode · Ref: $txnRef',
                  style: const TextStyle(
                      color: _textMuted, fontSize: 11),
                  textAlign: TextAlign.center),
              if (customSchedule != null) ...[
                const SizedBox(height: 8),
                Text('Scheduled: $customSchedule',
                    style: const TextStyle(
                        color: _textSecondary, fontSize: 12),
                    textAlign: TextAlign.center),
              ],
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _accentA.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _accentA.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    const Text('Amount Due',
                        style: TextStyle(
                            color: _textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('₹$amount',
                        style: const TextStyle(
                            color: _accentA,
                            fontSize: 28,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _errorColor,
                        side: BorderSide(
                            color: _errorColor.withOpacity(0.5)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel',
                          style:
                              TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                            colors: [_accentB, _accentA]),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          // FIX: the whole body is now wrapped in try/catch
                          // so any synchronous error (e.g. a bad context,
                          // a null somewhere) always surfaces a SnackBar
                          // instead of silently doing nothing.
                          debugPrint('ORDER: Pay Now tapped');
                          try {
                            Navigator.pop(dialogContext);
                            if (!mounted) return;
                            setState(() => _isProcessingPayment = true);
                            await _processOrderPlacement(
                              userId, txnRef, amount,
                              isReturning: isReturning,
                              scheduledTime: customSchedule,
                            );
                          } catch (e, st) {
                            debugPrint('ORDER: Pay Now handler error: $e\n$st');
                            if (mounted) {
                              _showSnack('Something went wrong: $e', isError: true);
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isProcessingPayment = false);
                            }
                          }
                        },
                        child: const Text('Pay Now',
                            style: TextStyle(
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: _bgDeep,
        body: Center(
          child: Text('Please log in to view your cart.',
              style: TextStyle(color: _textSecondary)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bgDeep,
      appBar: AppBar(
        backgroundColor: _bgCard,
        foregroundColor: _textPrimary,
        elevation: 0,
        centerTitle: false,
        title: const Text('My Cart',
            style: TextStyle(
                color: _textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
              height: 1, color: Colors.white.withOpacity(0.06)),
        ),
      ),
      body: _isProcessingPayment
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 56, height: 56,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          _accentA),
                      backgroundColor: _accentA.withOpacity(0.12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Processing payment...',
                      style: TextStyle(
                          color: _textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('cart')
                  .orderBy('addedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Error: ${snapshot.error}',
                          style:
                              const TextStyle(color: _errorColor)));
                }
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                            _accentA)),
                  );
                }

                final cartDocs = snapshot.data?.docs ?? [];

                if (cartDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _accentA.withOpacity(0.08),
                          ),
                          child: const Icon(
                              Icons.shopping_cart_outlined,
                              color: _textMuted,
                              size: 36),
                        ),
                        const SizedBox(height: 16),
                        const Text('Your cart is empty',
                            style: TextStyle(
                                color: _textSecondary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        const Text('Add services to get started',
                            style: TextStyle(
                                color: _textMuted, fontSize: 13)),
                      ],
                    ),
                  );
                }

                double totalCost = 0.0;
                for (final doc in cartDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  totalCost += _parseCost(data['cost']);
                }

                return Column(
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Row(
                        children: [
                          Text(
                            '${cartDocs.length} item${cartDocs.length > 1 ? 's' : ''}',
                            style: const TextStyle(
                                color: _textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            16, 8, 16, 16),
                        itemCount: cartDocs.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final doc  = cartDocs[index];
                          final data =
                              doc.data() as Map<String, dynamic>;
                          final String itemTitle =
                              data['title'] ?? 'Unknown Item';
                          final String displayCost =
                              _formatCost(data['cost']);
                          final String imageUrl =
                              (data['image'] as String?)?.trim() ?? '';

                          return Container(
                            decoration: BoxDecoration(
                              color: _bgCard,
                              borderRadius:
                                  BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white
                                      .withOpacity(0.06)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    child: imageUrl.isNotEmpty
                                        ? Image.network(
                                            imageUrl,
                                            width: 64, height: 64,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (_, __, ___) =>
                                                    _placeholder(),
                                          )
                                        : _placeholder(),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(itemTitle,
                                            style: const TextStyle(
                                              color: _textPrimary,
                                              fontWeight:
                                                  FontWeight.w600,
                                              fontSize: 14.5,
                                            )),
                                        const SizedBox(height: 5),
                                        Row(
                                          children: [
                                            _InfoChip(
                                                icon: Icons
                                                    .straighten_rounded,
                                                label:
                                                    '${data['area'] ?? '0'} sq ft'),
                                            const SizedBox(width: 8),
                                            _InfoChip(
                                                icon: Icons
                                                    .schedule_rounded,
                                                label: data['time'] ??
                                                    'N/A'),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(displayCost,
                                            style: const TextStyle(
                                              color: _accentA,
                                              fontWeight:
                                                  FontWeight.w700,
                                              fontSize: 15,
                                            )),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _removeFromCart(
                                        context,
                                        user.uid,
                                        doc.id,
                                        itemTitle),
                                    child: Container(
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(
                                        color: _errorColor
                                            .withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                          Icons
                                              .delete_outline_rounded,
                                          color: _errorColor,
                                          size: 18),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(
                            20, 16, 20, 16),
                        decoration: BoxDecoration(
                          color: _bgCard,
                          border: Border(
                              top: BorderSide(
                                  color: Colors.white
                                      .withOpacity(0.06))),
                        ),
                        child: Row(
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text('Total',
                                    style: TextStyle(
                                        color: _textMuted,
                                        fontSize: 12)),
                                const SizedBox(height: 2),
                                Text(
                                    '₹${totalCost.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        color: _accentA,
                                        fontSize: 22,
                                        fontWeight:
                                            FontWeight.w800)),
                              ],
                            ),
                            const Spacer(),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  colors: [_accentB, _accentA],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: _bgDeep,
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 28,
                                          vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(
                                              14)),
                                ),
                                onPressed: () => _initiateCheckout(
                                    totalCost, user.uid),
                                child: const Text('Checkout',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight:
                                            FontWeight.w800)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _placeholder() => Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: _bgSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.image_outlined,
            color: _textMuted, size: 28),
      );
}

// ─── Info chip ─────────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: _textMuted),
          const SizedBox(width: 4),
          Text(label,
              style:
                  const TextStyle(color: _textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}