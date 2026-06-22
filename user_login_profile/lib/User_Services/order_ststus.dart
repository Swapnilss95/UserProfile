// order_status_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ─── Theme Constants ──────────────────────────────────────────────────────────
const _kPrimaryDark   = Color(0xff0a1628);
const _kPrimaryMid    = Color(0xff1a3a7e);
const _kAccent        = Color(0xff1a5fc8);
const _kBgPage        = Color(0xfff0f4ff);
const _kBgCard        = Color(0xffffffff);
const _kBorderCard    = Color(0xffdde5f7);
const _kTextPrimary   = Color(0xff1a2a4e);
const _kTextMuted     = Color(0xff7a8db5);
const _kGradient      = LinearGradient(
  colors: [_kPrimaryDark, _kPrimaryMid],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const _kStatusCompleted  = Color(0xff1db954);
const _kStatusPending    = Color(0xfff59e0b);
const _kStatusInProgress = Color(0xff3b82f6);
const _kStatusCancelled  = Color(0xffe05252);

// ─── OrderStatusScreen ────────────────────────────────────────────────────────
class OrderStatusScreen extends StatelessWidget {
  const OrderStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: _kBgPage,
        body: Center(
          child: Text('Please log in to view orders.',
              style: TextStyle(color: _kTextMuted, fontSize: 14)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _kBgPage,
      appBar: AppBar(
        backgroundColor: _kPrimaryDark,
        foregroundColor: Colors.white,
        title: const Text('My Orders',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // FIX: Query 'Jobs' collection by userId — matches your Firestore structure
        stream: FirebaseFirestore.instance
            .collection('Jobs')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: _kStatusCancelled),
                  const SizedBox(height: 12),
                  Text('Error: ${snapshot.error}',
                      style:
                          const TextStyle(color: _kTextMuted, fontSize: 13)),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _kAccent));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 64, color: _kTextMuted.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  const Text('No orders yet',
                      style: TextStyle(
                          color: _kTextPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text('Your order history will appear here.',
                      style: TextStyle(color: _kTextMuted, fontSize: 13)),
                ],
              ),
            );
          }

          // Sort newest first locally
          final sortedDocs = [...docs]..sort((a, b) {
              final aTs = (a.data() as Map<String, dynamic>)['createdAt']
                  as Timestamp?;
              final bTs = (b.data() as Map<String, dynamic>)['createdAt']
                  as Timestamp?;
              if (aTs == null || bTs == null) return 0;
              return bTs.compareTo(aTs);
            });

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: sortedDocs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final doc  = sortedDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              // Normalize data from Jobs collection format
              final normalized = _normalizeJobData(data);
              return _OrderCard(
                orderId: doc.id,
                data: normalized,
                rawData: data,
                onTap: () => _showOrderDetails(context, doc.id, normalized, data),
              );
            },
          );
        },
      ),
    );
  }

  /// Converts Jobs collection fields → OrderCard field names
  Map<String, dynamic> _normalizeJobData(Map<String, dynamic> raw) {
    // Pull service title from serviceType or items[0].title
    String serviceTitle = raw['serviceType']?.toString() ?? '';
    String serviceImage = '';
    String cost         = raw['totalAmount']?.toString() ?? '0';
    String area         = '0';

    final items = (raw['items'] as List?) ?? [];
    if (items.isNotEmpty) {
      final first = items[0] as Map<String, dynamic>;
      if (serviceTitle.isEmpty) {
        serviceTitle = first['title']?.toString() ?? 'Service';
      }
      serviceImage = first['image']?.toString() ?? '';
      area         = first['area']?.toString()  ?? '0';
      // If cost not at top level, use item cost
      if (cost == '0') cost = first['cost']?.toString() ?? '0';
    }

    // Map Jobs status → display status
    // Jobs: "request" | "accepted" | "completed"
    final rawStatus = raw['status']?.toString() ?? 'request';
    final String displayStatus;
    switch (rawStatus) {
      case 'accepted':
        displayStatus = 'in_progress';
        break;
      case 'completed':
        displayStatus = 'completed';
        break;
      default:
        displayStatus = 'pending';
    }

    return {
      'status':        displayStatus,
      'rawStatus':     rawStatus,
      'serviceTitle':  serviceTitle,
      'serviceImage':  serviceImage,
      'cost':          cost,
      'area':          area,
      'address':       raw['address']?.toString()      ?? 'N/A',
      'mobile':        raw['mobile']?.toString()        ?? 'N/A',
      'clientName':    raw['clientName']?.toString()    ?? 'N/A',
      'washmitraId':   raw['washmitraId']?.toString()   ?? '',
      'transactionRef':raw['transactionRef']?.toString() ?? 'N/A',
      'createdAt':     raw['createdAt'],
      'completedAt':   raw['completedAt'],
      'acceptedAt':    raw['acceptedAt'],
      'items':         items,
    };
  }

  void _showOrderDetails(BuildContext context, String orderId,
      Map<String, dynamic> data, Map<String, dynamic> rawData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailSheet(
          orderId: orderId, data: data, rawData: rawData),
    );
  }
}

// ─── Order Card ───────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final Map<String, dynamic> rawData;
  final VoidCallback onTap;

  const _OrderCard({
    required this.orderId,
    required this.data,
    required this.rawData,
    required this.onTap,
  });

  Color _statusColor(String s) {
    switch (s) {
      case 'completed':  return _kStatusCompleted;
      case 'in_progress':return _kStatusInProgress;
      case 'cancelled':  return _kStatusCancelled;
      default:           return _kStatusPending;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'completed':  return Icons.check_circle_rounded;
      case 'in_progress':return Icons.autorenew_rounded;
      case 'cancelled':  return Icons.cancel_rounded;
      default:           return Icons.schedule_rounded;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'completed':  return 'Completed';
      case 'in_progress':return 'In Progress';
      case 'cancelled':  return 'Cancelled';
      default:           return 'Pending';
    }
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return 'N/A';
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return '${dt.day}/${dt.month}/${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    }
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    final status       = data['status'] as String;
    final serviceTitle = data['serviceTitle'] as String;
    final cost         = data['cost'];
    final imageUrl     = data['serviceImage'] as String;
    final isCompleted  = status == 'completed';
    final isAccepted   = status == 'in_progress';
    final washmitraId  = data['washmitraId'] as String;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _kBgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isCompleted
                ? _kStatusCompleted.withOpacity(0.4)
                : isAccepted
                    ? _kStatusInProgress.withOpacity(0.3)
                    : _kBorderCard,
            width: (isCompleted || isAccepted) ? 1.5 : 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Status Banner ─────────────────────────────────────────────
            if (isCompleted)
              _statusBanner(
                color: _kStatusCompleted,
                icon: Icons.celebration_rounded,
                text: '🎉  Your job has been completed!',
              )
            else if (isAccepted && washmitraId.isNotEmpty)
              _statusBanner(
                color: _kStatusInProgress,
                icon: Icons.directions_run_rounded,
                text: '🚀  Washmitra accepted & is on the way!',
              ),

            // ── Main Content ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: imageUrl.isNotEmpty
                        ? Image.network(imageUrl,
                            width: 68, height: 68, fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => _placeholder())
                        : _placeholder(),
                  ),
                  const SizedBox(width: 14),

                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(serviceTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _kTextPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.location_on_outlined,
                              size: 12, color: _kTextMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(data['address'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: _kTextMuted, fontSize: 11)),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 11, color: _kTextMuted),
                          const SizedBox(width: 4),
                          Text(_formatDate(data['createdAt']),
                              style: const TextStyle(
                                  color: _kTextMuted, fontSize: 11)),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Cost + Status badge
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        cost.toString().startsWith('₹')
                            ? cost.toString()
                            : '₹$cost',
                        style: const TextStyle(
                            color: _kAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_statusIcon(status),
                                size: 11, color: _statusColor(status)),
                            const SizedBox(width: 4),
                            Text(_statusLabel(status),
                                style: TextStyle(
                                    color: _statusColor(status),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Tap hint ──────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: _kBgPage,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              child: const Center(
                child: Text('Tap to view full details',
                    style: TextStyle(
                        color: _kAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBanner(
      {required Color color,
      required IconData icon,
      required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: _kBgPage,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.local_laundry_service_outlined,
            color: _kTextMuted, size: 28),
      );
}

// ─── Order Detail Sheet ───────────────────────────────────────────────────────
class _OrderDetailSheet extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final Map<String, dynamic> rawData;

  const _OrderDetailSheet({
    required this.orderId,
    required this.data,
    required this.rawData,
  });

  String _formatDate(dynamic ts) {
    if (ts == null) return 'N/A';
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return '${dt.day}/${dt.month}/${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    }
    return 'N/A';
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'completed':  return _kStatusCompleted;
      case 'in_progress':return _kStatusInProgress;
      case 'cancelled':  return _kStatusCancelled;
      default:           return _kStatusPending;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'completed':  return 'Completed';
      case 'in_progress':return 'In Progress';
      case 'cancelled':  return 'Cancelled';
      default:           return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status       = data['status'] as String;
    final isCompleted  = status == 'completed';
    final isAccepted   = status == 'in_progress';
    final serviceTitle = data['serviceTitle'] as String;
    final serviceImage = data['serviceImage'] as String;
    final cost         = data['cost'];
    final area         = data['area'] as String;
    final address      = data['address'] as String;
    final washmitraId  = data['washmitraId'] as String;
    final items        = (data['items'] as List?) ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: _kBgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: _kBorderCard,
                  borderRadius: BorderRadius.circular(10)),
            ),

            // Header
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(gradient: _kGradient),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.receipt_long_rounded,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Order: ${orderId.length > 14 ? '${orderId.substring(0, 14)}...' : orderId}',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(serviceTitle,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _statusColor(status).withOpacity(0.5)),
                      ),
                      child: Text(_statusLabel(status),
                          style: TextStyle(
                              color: _statusColor(status),
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                    const Spacer(),
                    Text(
                      cost.toString().startsWith('₹')
                          ? cost.toString()
                          : '₹$cost',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                  ]),
                ],
              ),
            ),

            // Scrollable body
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [

                  // ── COMPLETION BANNER ───────────────────────────────────
                  if (isCompleted) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _kStatusCompleted.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _kStatusCompleted.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: _kStatusCompleted, size: 44),
                          const SizedBox(height: 8),
                          const Text('✅  Job Completed Successfully!',
                              style: TextStyle(
                                  color: _kStatusCompleted,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            'Completed on: ${_formatDate(data['completedAt'])}',
                            style: const TextStyle(
                                color: _kTextMuted, fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Total Paid: ${cost.toString().startsWith('₹') ? cost : '₹$cost'}',
                            style: const TextStyle(
                                color: _kStatusCompleted,
                                fontSize: 14,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── ACCEPTED BANNER ─────────────────────────────────────
                  if (isAccepted && washmitraId.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _kStatusInProgress.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _kStatusInProgress.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.directions_run_rounded,
                            color: _kStatusInProgress, size: 20),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            '🚀 Washmitra accepted your request and is on the way!',
                            style: TextStyle(
                                color: _kStatusInProgress,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── ORDER DETAILS ───────────────────────────────────────
                  _sectionHeader('Order Details', Icons.shopping_bag_outlined),
                  const SizedBox(height: 10),
                  _detailCard([
                    if (serviceImage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(serviceImage,
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(
                                height: 80, color: _kBgPage,
                                child: const Center(
                                  child: Icon(
                                      Icons.local_laundry_service_outlined,
                                      color: _kTextMuted, size: 32),
                                ),
                              )),
                        ),
                      ),
                    _detailRow(Icons.design_services_outlined,
                        'Service', serviceTitle),
                    _divider(),
                    _detailRow(Icons.currency_rupee_rounded, 'Total Cost',
                        cost.toString().startsWith('₹')
                            ? cost.toString()
                            : '₹$cost'),
                    _divider(),
                    _detailRow(
                        Icons.location_on_outlined, 'Address', address),
                    _divider(),
                    _detailRow(Icons.square_foot_outlined, 'Area',
                        area.isNotEmpty ? '${area} sq ft' : 'N/A'),
                    _divider(),
                    _detailRow(Icons.calendar_today_outlined, 'Order Placed',
                        _formatDate(data['createdAt'])),
                    if (data['acceptedAt'] != null) ...[
                      _divider(),
                      _detailRow(Icons.handshake_outlined, 'Accepted At',
                          _formatDate(data['acceptedAt'])),
                    ],
                    if (isCompleted && data['completedAt'] != null) ...[
                      _divider(),
                      _detailRow(Icons.done_all_rounded, 'Completed At',
                          _formatDate(data['completedAt'])),
                    ],
                  ]),

                  // ── ITEMS BREAKDOWN ─────────────────────────────────────
                  if (items.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionHeader(
                        'Services Booked', Icons.list_alt_rounded),
                    const SizedBox(height: 10),
                    _detailCard(
                      List.generate(items.length, (i) {
                        final item = items[i] as Map<String, dynamic>;
                        final isLast = i == items.length - 1;
                        return Column(
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: item['image'] != null &&
                                            item['image']
                                                .toString()
                                                .isNotEmpty
                                        ? Image.network(
                                            item['image'].toString(),
                                            width: 44,
                                            height: 44,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) =>
                                                _itemPlaceholder())
                                        : _itemPlaceholder(),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['title']?.toString() ??
                                              'Service',
                                          style: const TextStyle(
                                              color: _kTextPrimary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600),
                                        ),
                                        if (item['time'] != null)
                                          Text(
                                            item['time'].toString(),
                                            style: const TextStyle(
                                                color: _kTextMuted,
                                                fontSize: 11),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    item['cost']?.toString() ?? '',
                                    style: const TextStyle(
                                        color: _kAccent,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            if (!isLast) _divider(),
                          ],
                        );
                      }),
                    ),
                  ],

                  // ── WASHMITRA DETAILS ───────────────────────────────────
                  if (washmitraId.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionHeader('Washmitra Details',
                        Icons.person_pin_circle_outlined),
                    const SizedBox(height: 10),
                    _WashmitraDetailCard(
                      washmitraId: washmitraId,
                      isCompleted: isCompleted,
                      cost: cost.toString(),
                    ),
                  ],

                  // ── ORDER TIMELINE ──────────────────────────────────────
                  const SizedBox(height: 20),
                  _sectionHeader('Order Timeline', Icons.timeline_rounded),
                  const SizedBox(height: 10),
                  _OrderTimeline(status: status),

                  const SizedBox(height: 20),
                  // Transaction ref
                  if (data['transactionRef'] != null)
                    Center(
                      child: Text(
                        'Txn Ref: ${data['transactionRef']}',
                        style: const TextStyle(
                            color: _kTextMuted, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) => Row(
        children: [
          Icon(icon, size: 18, color: _kAccent),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  color: _kTextPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3)),
        ],
      );

  Widget _detailCard(List<Widget> children) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _kBgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorderCard, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children),
      );

  Widget _detailRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: _kAccent),
            const SizedBox(width: 10),
            SizedBox(
              width: 110,
              child: Text(label,
                  style: const TextStyle(
                      color: _kTextMuted, fontSize: 13)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      color: _kTextPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.right),
            ),
          ],
        ),
      );

  Widget _divider() => const Divider(color: _kBorderCard, height: 1);

  Widget _itemPlaceholder() => Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: _kBgPage,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.local_laundry_service_outlined,
            color: _kTextMuted, size: 20),
      );
}

// ─── Washmitra Detail Card (fetches from Firestore) ───────────────────────────
class _WashmitraDetailCard extends StatelessWidget {
  final String washmitraId;
  final bool isCompleted;
  final String cost;

  const _WashmitraDetailCard({
    required this.washmitraId,
    required this.isCompleted,
    required this.cost,
  });

  Future<Map<String, dynamic>> _fetchWashmitra() async {
    final db = FirebaseFirestore.instance;

    // 1. Try washmitra_profiles by doc ID
    try {
      final s = await db.collection('washmitra_profiles').doc(washmitraId).get();
      if (s.exists && s.data() != null && s.data()!.isNotEmpty) return s.data()!;
    } catch (_) {}

    // 2. Try users collection by doc ID
    try {
      final s = await db.collection('users').doc(washmitraId).get();
      if (s.exists && s.data() != null && s.data()!.isNotEmpty) return s.data()!;
    } catch (_) {}

    // 3. Try washmitra_profiles where uid field == washmitraId
    try {
      final q = await db
          .collection('washmitra_profiles')
          .where('uid', isEqualTo: washmitraId)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) return q.docs.first.data();
    } catch (_) {}

    return {};
  }

  @override
  Widget build(BuildContext context) {
    final headerColor = isCompleted ? _kStatusCompleted : _kAccent;

    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchWashmitra(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kBgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorderCard),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _kAccent),
                ),
                SizedBox(width: 10),
                Text('Loading washmitra details...',
                    style:
                        TextStyle(color: _kTextMuted, fontSize: 12)),
              ],
            ),
          );
        }

        final d = snapshot.data ?? {};

        final name = (d['name'] ?? d['fullName'] ?? d['full_name'] ??
                d['displayName'])?.toString() ?? 'Washmitra Partner';
        final shopName = (d['shopName'] ?? d['shop_name'] ??
                d['businessName'])?.toString();
        final address = (d['address'] ?? d['shopAddress'] ??
                d['location'])?.toString();
        final mobile = (d['mobile'] ?? d['phone'] ??
                d['phoneNumber'] ?? d['phone_number'] ??
                d['mobileNumber'])?.toString();

        return Container(
          decoration: BoxDecoration(
            color: _kBgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: headerColor.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Card Header ────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: headerColor.withOpacity(0.08),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(children: [
                  Icon(
                    isCompleted
                        ? Icons.verified_rounded
                        : Icons.person_pin_circle_outlined,
                    color: headerColor, size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isCompleted
                        ? '✅  Job Completed by Washmitra'
                        : '🚀  Your Assigned Washmitra',
                    style: TextStyle(
                        color: headerColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ]),
              ),

              // ── Avatar + Name + Shop ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: headerColor.withOpacity(0.12),
                        child: Icon(Icons.storefront_rounded,
                            color: headerColor, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    color: _kTextPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            if (shopName != null) ...[
                              const SizedBox(height: 3),
                              Row(children: [
                                const Icon(Icons.storefront_outlined,
                                    size: 12, color: _kTextMuted),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(shopName,
                                      style: const TextStyle(
                                          color: _kTextMuted,
                                          fontSize: 12),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ]),
                            ],
                          ],
                        ),
                      ),
                    ]),

                    const SizedBox(height: 14),
                    const Divider(color: _kBorderCard, height: 1),
                    const SizedBox(height: 12),

                    // ── Info rows ──────────────────────────────────────
                    if (mobile != null)
                      _wRow(Icons.phone_rounded, 'Mobile', mobile,
                          valueColor: _kAccent)
                    else
                      _wRow(Icons.phone_rounded, 'Mobile',
                          'Not available',
                          valueColor: _kTextMuted),

                    if (address != null)
                      _wRow(Icons.location_on_rounded, 'Address', address),

                    // ── Cost (highlighted on completed) ────────────────
                    _wRow(
                      Icons.currency_rupee_rounded,
                      'Service Cost',
                      cost.startsWith('₹') ? cost : '₹$cost',
                      valueColor: isCompleted
                          ? _kStatusCompleted
                          : _kAccent,
                      bold: true,
                    ),

                    _wRow(
                      Icons.badge_outlined,
                      'Partner ID',
                      washmitraId.length > 16
                          ? '${washmitraId.substring(0, 16)}...'
                          : washmitraId,
                      valueColor: _kTextMuted,
                      fontSize: 11,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _wRow(IconData icon, String label, String value,
      {Color valueColor = _kTextPrimary,
      double fontSize = 12,
      bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: _kTextMuted),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text('$label:',
                style: const TextStyle(
                    color: _kTextMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: valueColor,
                    fontSize: fontSize,
                    fontWeight:
                        bold ? FontWeight.bold : FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─── Order Timeline ───────────────────────────────────────────────────────────
class _OrderTimeline extends StatelessWidget {
  final String status;
  const _OrderTimeline({required this.status});

  @override
  Widget build(BuildContext context) {
    final steps = [
      _TimelineStep(
        label: 'Order Placed',
        sublabel: 'Request submitted',
        icon: Icons.shopping_cart_checkout_rounded,
        isActive: true,
        color: _kStatusPending,
      ),
      _TimelineStep(
        label: 'Washmitra Assigned',
        sublabel: 'Partner accepted',
        icon: Icons.handshake_rounded,
        isActive: status == 'in_progress' || status == 'completed',
        color: _kStatusInProgress,
      ),
      _TimelineStep(
        label: 'In Progress',
        sublabel: 'Service underway',
        icon: Icons.autorenew_rounded,
        isActive: status == 'in_progress' || status == 'completed',
        color: _kStatusInProgress,
      ),
      _TimelineStep(
        label: 'Completed',
        sublabel: 'Job done!',
        icon: Icons.check_circle_rounded,
        isActive: status == 'completed',
        color: _kStatusCompleted,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kBgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorderCard, width: 0.8),
      ),
      child: Column(
        children: List.generate(steps.length, (i) {
          final step   = steps[i];
          final isLast = i == steps.length - 1;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon + connector
              Column(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: step.isActive
                        ? step.color.withOpacity(0.12)
                        : _kBgPage,
                    border: Border.all(
                      color: step.isActive ? step.color : _kBorderCard,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(step.icon,
                      size: 17,
                      color: step.isActive ? step.color : _kTextMuted),
                ),
                if (!isLast)
                  Container(
                    width: 2, height: 30,
                    color: step.isActive
                        ? step.color.withOpacity(0.3)
                        : _kBorderCard,
                  ),
              ]),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(step.label,
                        style: TextStyle(
                            color: step.isActive
                                ? _kTextPrimary
                                : _kTextMuted,
                            fontSize: 13,
                            fontWeight: step.isActive
                                ? FontWeight.w700
                                : FontWeight.normal)),
                    Text(step.sublabel,
                        style: TextStyle(
                            color: step.isActive
                                ? step.color
                                : _kTextMuted,
                            fontSize: 11)),
                    SizedBox(height: isLast ? 0 : 10),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _TimelineStep {
  final String label;
  final String sublabel;
  final IconData icon;
  final bool isActive;
  final Color color;

  const _TimelineStep({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.isActive,
    required this.color,
  });
}