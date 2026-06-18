import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:user_login_profile/userprofil.dart';

// ─── Theme ────────────────────────────────────────────────────────────────────
class _C {
  static const purple = Color(0xFF6366F1);
  static const green  = Color(0xFF10B981);
  static const red    = Color(0xFFEF4444);
}

class PaymentScreen extends StatefulWidget {
  // ✅ Clean constructor — only jobDocId needed
  final String jobDocId;
  const PaymentScreen({super.key, this.jobDocId = ''});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isLoading = true;

  String _clientName   = 'Loading...';
  String _clientMobile = 'Loading...';
  String _address      = 'Loading...';
  String _serviceType  = 'Loading...';
  String _status       = 'request';
  String _totalAmount  = 'Loading...';
  String _txnRef       = 'Loading...';
  List   _items        = [];

  String _washmitraName   = '';
  String _washmitramobile = '';
  bool   _isAssigned      = false;

  StreamSubscription<DocumentSnapshot>? _jobSub;

  @override
  void initState() {
    super.initState();
    _listenToJob();
  }

  void _listenToJob() {
    if (widget.jobDocId.isEmpty) {
      _loadLatestJob();
      return;
    }
    _jobSub = FirebaseFirestore.instance
        .collection('Jobs')
        .doc(widget.jobDocId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || !mounted) return;
      _parseJobData(doc.data() as Map<String, dynamic>);
    });
  }

  Future<void> _loadLatestJob() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Jobs')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty && mounted) {
        _jobSub = FirebaseFirestore.instance
            .collection('Jobs')
            .doc(snap.docs.first.id)
            .snapshots()
            .listen((doc) {
          if (!doc.exists || !mounted) return;
          _parseJobData(doc.data() as Map<String, dynamic>);
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _status = 'Error: $e'; });
    }
  }

  Future<void> _parseJobData(Map<String, dynamic> data) async {
    final wId = data['washmitraId'];
    final bool assigned =
        wId != null && wId.toString().trim().isNotEmpty;

    if (!mounted) return;
    setState(() {
      _clientName   = data['clientName']     ?? 'N/A';
      _clientMobile = data['mobile']         ?? 'N/A';
      _address      = data['address']        ?? 'N/A';
      _serviceType  = data['serviceType']    ?? 'N/A';
      _status       = data['status']         ?? 'request';
      _totalAmount  = data['totalAmount']?.toString() ?? 'N/A';
      _txnRef       = data['transactionRef'] ?? 'N/A';
      _items        = List.from(data['items'] ?? []);
      _isAssigned   = assigned;
      _isLoading    = false;
    });

    if (assigned) {
      try {
        final wDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(wId.toString())
            .get();
        if (wDoc.exists && mounted) {
          final wd = wDoc.data() as Map<String, dynamic>;
          setState(() {
            _washmitraName   = wd['name']   ?? 'N/A';
            _washmitramobile = wd['mobile'] ?? 'N/A';
          });
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _jobSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? _buildLoading()
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 20),
                  child: _buildContent(context),
                ),
        ),
      ),
    );
  }

  Widget _buildLoading() => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 55, height: 55,
              child: CircularProgressIndicator(
                  strokeWidth: 4.5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(_C.purple)),
            ),
            SizedBox(height: 24),
            Text('Loading order status...',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ],
        ),
      );

  Widget _buildContent(BuildContext context) {
    final bool accepted =
        _status == 'pending' || _status == 'completed';
    final Color sc = accepted ? _C.green : _C.red;

    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: sc.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: sc.withOpacity(0.3), width: 2),
          ),
          child: Icon(
            accepted
                ? Icons.check_circle_outline_rounded
                : Icons.hourglass_empty_rounded,
            color: sc, size: 72,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          accepted ? 'Request Accepted!' : 'Request Submitted',
          style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          accepted
              ? 'A washmitra has accepted your request.'
              : 'Waiting for a washmitra to accept your request.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
              height: 1.5),
        ),
        const SizedBox(height: 24),

        _glassCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Track ID',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 13)),
              Flexible(
                child: Text(_txnRef,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _section(
          icon: Icons.assignment_outlined,
          title: 'Your Order',
          color: _C.purple,
          rows: [
            _row(Icons.person_outline, 'Name', _clientName),
            _row(Icons.phone_android, 'Mobile', _clientMobile),
            _row(Icons.location_on_outlined, 'Address', _address),
            _row(Icons.local_laundry_service_outlined,
                'Service', _serviceType),
            _row(Icons.currency_rupee, 'Total', '₹$_totalAmount'),
            _row(Icons.info_outline, 'Status',
                _status.toUpperCase()),
          ],
        ),
        const SizedBox(height: 16),

        if (_items.isNotEmpty)
          _section(
            icon: Icons.list_alt_outlined,
            title: 'Items Ordered',
            color: _C.purple,
            rows: _items.map<Widget>((item) {
              return _row(
                Icons.check_circle_outline,
                item['title']?.toString() ?? 'Item',
                item['cost']?.toString() ?? '',
              );
            }).toList(),
          ),

        if (_isAssigned) ...[
          const SizedBox(height: 16),
          _section(
            icon: Icons.storefront,
            title: 'Your Washmitra',
            color: _C.green,
            rows: [
              _row(Icons.person_outline, 'Name', _washmitraName),
              _row(Icons.phone_android, 'Mobile',
                  _washmitramobile),
            ],
          ),
        ],

        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.purple,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () =>
                UserProfileScreen.switchToServicesTab(context),
            child: const Text('Back to Services',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _glassCard({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: child,
      );

  Widget _section({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> rows,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: color.withOpacity(0.2), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.95))),
            ]),
            Divider(height: 24, color: Colors.white.withOpacity(0.08)),
            ...rows,
          ],
        ),
      );

  Widget _row(IconData icon, String label, String value) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                size: 16, color: Colors.white.withOpacity(0.4)),
            const SizedBox(width: 10),
            SizedBox(
              width: 90,
              child: Text(label,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 13)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.3)),
            ),
          ],
        ),
      );
}
