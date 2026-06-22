/*// reqest_screen.dart
// Save at: lib/User_Services/reqest_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const Color _bgDeep        = Color(0xFF080C14);
const Color _bgCard        = Color(0xFF0F1624);
const Color _accentA       = Color(0xFF00D4AA);
const Color _textPrimary   = Color(0xFFE8F0FE);
const Color _textSecondary = Color(0xFF8899B0);
const Color _textMuted     = Color(0xFF4A5A72);

class RequestServiceScreen extends StatelessWidget {
  final String? jobDocId;
  const RequestServiceScreen({super.key, this.jobDocId});

  Future<void> _deleteJob(BuildContext context, String docId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _bgCard,
        title: const Text('Cancel Request', style: TextStyle(color: _textPrimary)),
        content: const Text(
          'Are you sure you want to cancel and delete this service request?',
          style: TextStyle(color: _textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('No', style: TextStyle(color: _textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Yes, Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('Jobs').doc(docId).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request cancelled successfully.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to delete: $e'),
                backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: _bgDeep,
        body: Center(
          child: Text('Please log in to view your requests.',
              style: TextStyle(color: _textSecondary)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bgDeep,
      appBar: AppBar(
        backgroundColor: _bgCard,
        foregroundColor: _textPrimary,
        title: const Text('My Service Requests',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Jobs')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(_accentA)),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined,
                      size: 48, color: _textMuted.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  const Text('No service requests yet.',
                      style: TextStyle(color: _textSecondary, fontSize: 15)),
                  const SizedBox(height: 6),
                  const Text('Add services to cart and checkout.',
                      style: TextStyle(color: _textMuted, fontSize: 13)),
                ],
              ),
            );
          }

          final sortedDocs = [...docs]..sort((a, b) {
              final aTs =
                  (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              final bTs =
                  (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              if (aTs == null || bTs == null) return 0;
              return bTs.compareTo(aTs);
            });

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sortedDocs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc  = sortedDocs[index];
              final data = doc.data() as Map<String, dynamic>;

              final String  status      = data['status']      ?? 'request';
              final String  address     = data['address']      ?? 'No address provided';
              final String  totalAmount = data['totalAmount']  ?? '0';
              final String  serviceType = data['serviceType']  ?? 'Service';
              final String? washmitraId = data['washmitraId']  as String?;
              final List    items       = (data['items'] as List?) ?? [];

              final String scheduledTime = items.isNotEmpty
                  ? (items[0] as Map<String, dynamic>)['time'] ?? ''
                  : '';

              final bool isNewJob   = doc.id == jobDocId;
              final bool isAccepted = status == 'accepted';
              final bool isCompleted = status == 'completed';
              final bool isPending  = status == 'request';

              return Container(
                decoration: BoxDecoration(
                  color: _bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isNewJob
                        ? _accentA.withOpacity(0.5)
                        : Colors.white.withOpacity(0.06),
                    width: isNewJob ? 1.5 : 1.0,
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header row ──────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            serviceType,
                            style: const TextStyle(
                                color: _textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _statusLabel(status),
                                style: TextStyle(
                                    color: _statusColor(status),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (isPending) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent, size: 20),
                                onPressed: () => _deleteJob(context, doc.id),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // ── Address ─────────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: _textMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(address,
                              style: const TextStyle(
                                  color: _textSecondary, fontSize: 13)),
                        ),
                      ],
                    ),

                    // ── Schedule ────────────────────────────────────────
                    if (scheduledTime.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.schedule_outlined,
                              size: 14, color: _textMuted),
                          const SizedBox(width: 4),
                          Text(scheduledTime,
                              style: const TextStyle(
                                  color: _textMuted, fontSize: 12)),
                        ],
                      ),
                    ],

                    // ── Items list ──────────────────────────────────────
                    if (items.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ...items.map((item) {
                        final m = item as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.circle,
                                  size: 6, color: _textMuted),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(m['title'] ?? 'Service',
                                    style: const TextStyle(
                                        color: _textSecondary, fontSize: 12)),
                              ),
                              Text(
                                m['cost']?.toString() ?? '',
                                style: const TextStyle(
                                    color: _accentA,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],

                    // ── Total ───────────────────────────────────────────
                    const Divider(color: Colors.white10, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Amount',
                            style:
                                TextStyle(color: _textSecondary, fontSize: 13)),
                        Text(
                          totalAmount.startsWith('₹')
                              ? totalAmount
                              : '₹$totalAmount',
                          style: const TextStyle(
                              color: _accentA,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),

                    // ── STATUS TIMELINE ─────────────────────────────────
                    const SizedBox(height: 16),
                    _StatusTimeline(status: status),

                    // ── Washmitra details (accepted or completed) ───────
                    if ((isAccepted || isCompleted) &&
                        washmitraId != null &&
                        washmitraId.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _WashmitraInfoCard(
                        washmitraId: washmitraId,
                        isCompleted: isCompleted,
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return _accentA;
      case 'completed':
        return Colors.greenAccent;
      case 'request':
      default:
        return Colors.orangeAccent;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'Accepted';
      case 'completed':
        return 'Completed';
      case 'request':
      default:
        return 'Pending';
    }
  }
}

// ─── Status Timeline Widget ───────────────────────────────────────────────────

class _StatusTimeline extends StatelessWidget {
  final String status;
  const _StatusTimeline({required this.status});

  @override
  Widget build(BuildContext context) {
    // Steps: 0=Pending, 1=Accepted, 2=Completed
    final int currentStep = status == 'completed'
        ? 2
        : status == 'accepted'
            ? 1
            : 0;

    final steps = [
      _TimelineStep(
        icon: Icons.hourglass_empty_rounded,
        label: 'Order Placed',
        sublabel: 'Waiting for washmitra',
        activeColor: Colors.orangeAccent,
      ),
      _TimelineStep(
        icon: Icons.handshake_outlined,
        label: 'Accepted',
        sublabel: 'Washmitra on the way',
        activeColor: _accentA,
      ),
      _TimelineStep(
        icon: Icons.check_circle_rounded,
        label: 'Completed',
        sublabel: 'Service done!',
        activeColor: Colors.greenAccent,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Status',
            style: TextStyle(
                color: _textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(steps.length * 2 - 1, (i) {
              // Connector lines
              if (i.isOdd) {
                final stepIndex = (i - 1) ~/ 2;
                final isActive = currentStep > stepIndex;
                return Expanded(
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: isActive
                          ? LinearGradient(colors: [
                              steps[stepIndex].activeColor,
                              steps[stepIndex + 1].activeColor,
                            ])
                          : null,
                      color: isActive ? null : Colors.white12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }

              // Step circles
              final stepIndex = i ~/ 2;
              final isActive = currentStep >= stepIndex;
              final isCurrent = currentStep == stepIndex;
              final step = steps[stepIndex];

              return Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: isCurrent ? 38 : 32,
                    height: isCurrent ? 38 : 32,
                    decoration: BoxDecoration(
                      color: isActive
                          ? step.activeColor.withOpacity(0.15)
                          : Colors.white.withOpacity(0.04),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive
                            ? step.activeColor
                            : Colors.white12,
                        width: isCurrent ? 2 : 1,
                      ),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: step.activeColor.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : [],
                    ),
                    child: Icon(
                      step.icon,
                      size: isCurrent ? 18 : 15,
                      color: isActive ? step.activeColor : Colors.white24,
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 10),
          // Labels row
          Row(
            children: List.generate(steps.length * 2 - 1, (i) {
              if (i.isOdd) return const Expanded(child: SizedBox());
              final stepIndex = i ~/ 2;
              final isActive = currentStep >= stepIndex;
              final isCurrent = currentStep == stepIndex;
              final step = steps[stepIndex];
              return SizedBox(
                width: 70,
                child: Column(
                  children: [
                    Text(
                      step.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isActive ? step.activeColor : _textMuted,
                        fontSize: isCurrent ? 11 : 10,
                        fontWeight: isCurrent
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(height: 2),
                      Text(
                        step.sublabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: step.activeColor.withOpacity(0.7),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ),

          // ── Completion message ────────────────────────────────────
          if (status == 'completed') ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: Colors.greenAccent.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_rounded,
                      color: Colors.greenAccent, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '✅ Your job has been completed successfully!',
                      style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Accepted message ──────────────────────────────────────
          if (status == 'accepted') ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _accentA.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _accentA.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.directions_run_rounded,
                      color: _accentA, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🎉 Washmitra accepted your request and is on the way!',
                      style: TextStyle(
                          color: _accentA,
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineStep {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color activeColor;
  const _TimelineStep({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.activeColor,
  });
}

// ─── Washmitra Info Card ───────────────────────────────────────────────────────

class _WashmitraInfoCard extends StatelessWidget {
  final String washmitraId;
  final bool isCompleted;
  const _WashmitraInfoCard({
    required this.washmitraId,
    this.isCompleted = false,
  });

  /// Check all 3 possible collections where washmitra data could be stored
  Future<Map<String, dynamic>> _fetchWashmitraData() async {
    final db = FirebaseFirestore.instance;

    // 1. Try 'washmitra_profiles' first (seen in your Firestore screenshot)
    try {
      final snap =
          await db.collection('washmitra_profiles').doc(washmitraId).get();
      if (snap.exists && snap.data() != null && snap.data()!.isNotEmpty) {
        return snap.data()!;
      }
    } catch (_) {}

    // 2. Try 'users' collection
    try {
      final snap = await db.collection('users').doc(washmitraId).get();
      if (snap.exists && snap.data() != null && snap.data()!.isNotEmpty) {
        return snap.data()!;
      }
    } catch (_) {}

    // 3. Try querying washmitra_profiles by uid field
    try {
      final query = await db
          .collection('washmitra_profiles')
          .where('uid', isEqualTo: washmitraId)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return query.docs.first.data();
      }
    } catch (_) {}

    return {};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchWashmitraData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _accentA.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _accentA.withOpacity(0.2)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _accentA),
                ),
                SizedBox(width: 10),
                Text('Loading washmitra details...',
                    style: TextStyle(color: _textMuted, fontSize: 12)),
              ],
            ),
          );
        }

        final data = snapshot.data ?? {};

        // Try every possible field name variation
        final name = (data['name'] ??
                data['fullName'] ??
                data['full_name'] ??
                data['displayName'])
            ?.toString() ??
            'Washmitra Partner';

        final shopName = (data['shopName'] ??
                data['shop_name'] ??
                data['businessName'] ??
                data['business_name'])
            ?.toString();

        final address = (data['address'] ??
                data['shopAddress'] ??
                data['shop_address'] ??
                data['location'])
            ?.toString();

        final mobile = (data['mobile'] ??
                data['phone'] ??
                data['phoneNumber'] ??
                data['phone_number'] ??
                data['mobileNumber'] ??
                data['contact'])
            ?.toString();

        final bool noData = data.isEmpty;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isCompleted
                ? Colors.greenAccent.withOpacity(0.05)
                : _accentA.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCompleted
                  ? Colors.greenAccent.withOpacity(0.3)
                  : _accentA.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ───────────────────────────────────────────────
              Row(
                children: [
                  Icon(
                    isCompleted
                        ? Icons.verified_rounded
                        : Icons.person_pin_circle_outlined,
                    color:
                        isCompleted ? Colors.greenAccent : _accentA,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isCompleted
                        ? 'Completed by Washmitra'
                        : 'Your Washmitra',
                    style: TextStyle(
                        color: isCompleted
                            ? Colors.greenAccent
                            : _accentA,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (noData) ...[
                // ── Fallback if no data found ─────────────────────────
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: _accentA.withOpacity(0.15),
                      child: const Icon(Icons.person,
                          color: _accentA, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Washmitra Partner',
                              style: TextStyle(
                                  color: _textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          SizedBox(height: 4),
                          Text('Details not available',
                              style: TextStyle(
                                  color: _textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // ── Avatar + Name ─────────────────────────────────────
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: isCompleted
                          ? Colors.greenAccent.withOpacity(0.15)
                          : _accentA.withOpacity(0.15),
                      child: Icon(
                        Icons.storefront_rounded,
                        color: isCompleted
                            ? Colors.greenAccent
                            : _accentA,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                                color: _textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700),
                          ),
                          if (shopName != null) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.storefront_outlined,
                                    size: 12, color: _textMuted),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    shopName,
                                    style: const TextStyle(
                                        color: _textSecondary,
                                        fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Divider(
                    color: Colors.white.withOpacity(0.07), height: 1),
                const SizedBox(height: 12),

                // ── Mobile ────────────────────────────────────────────
                if (mobile != null)
                  _infoRow(
                    icon: Icons.phone_rounded,
                    label: 'Mobile',
                    value: mobile,
                    valueColor: _accentA,
                  )
                else
                  _infoRow(
                    icon: Icons.phone_rounded,
                    label: 'Mobile',
                    value: 'Not available',
                    valueColor: _textMuted,
                  ),

                // ── Address ───────────────────────────────────────────
                if (address != null)
                  _infoRow(
                    icon: Icons.location_on_rounded,
                    label: 'Address',
                    value: address,
                  ),
              ],

              // ── Washmitra UID (always show for debug) ─────────────
              const SizedBox(height: 4),
              _infoRow(
                icon: Icons.badge_outlined,
                label: 'Partner ID',
                value: washmitraId.length > 16
                    ? '${washmitraId.substring(0, 16)}...'
                    : washmitraId,
                valueColor: _textMuted,
                valueFontSize: 10,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    Color valueColor = _textSecondary,
    double valueFontSize = 12,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: _textMuted),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
                color: _textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  color: valueColor,
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
} */