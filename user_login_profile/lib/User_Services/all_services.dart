import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
const Color _bgDeep      = Color(0xFF080C14);
const Color _bgCard      = Color(0xFF0F1624);
const Color _bgSurface   = Color(0xFF141E2E);
const Color _accentA     = Color(0xFF00D4AA);
const Color _accentB     = Color(0xFF00A86B);
const Color _textPrimary   = Color(0xFFE8F0FE);
const Color _textSecondary = Color(0xFF8899B0);
const Color _textMuted     = Color(0xFF4A5A72);
const Color _errorColor    = Color(0xFFFF5C6E);

// ─── Category metadata ────────────────────────────────────────────────────────
const _kCategories = [
  _Cat('All',      'All',          Icons.grid_view_rounded),
  _Cat('Laundry',  'Laundry',      Icons.local_laundry_service_rounded),
  _Cat('Home',     'Home Clean',   Icons.home_rounded),
  _Cat('Vehicle',  'Vehicle',      Icons.directions_car_rounded),
  _Cat('Outdoor',  'Outdoor',      Icons.park_rounded),
  _Cat('Specialty','Specialty',    Icons.auto_fix_high_rounded),
];

class _Cat {
  final String id;
  final String label;
  final IconData icon;
  const _Cat(this.id, this.label, this.icon);
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _addingIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Firestore query ──────────────────────────────────────────────────────────
  Query<Map<String, dynamic>> get _query {
    final base = FirebaseFirestore.instance
        .collection('services')
        .where('isActive', isEqualTo: true);
    if (_selectedCategory == 'All') return base;
    return base.where('category', isEqualTo: _selectedCategory);
  }

  // ── Add to cart ──────────────────────────────────────────────────────────────
  Future<void> _addToCart(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack(context, 'Please log in to add items.', isError: true);
      return;
    }

    setState(() => _addingIds.add(docId));

    try {
      final cartRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart');

      final existing = await cartRef
          .where('serviceId', isEqualTo: docId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        if (!context.mounted) return;
        _snack(context, '${data['title']} is already in your cart.');
        return;
      }

      await cartRef.add({
        'serviceId': docId,
        'title':    data['title']    ?? 'Unknown',
        'cost':     data['cost']     ?? '₹0',
        'area':     data['area']     ?? '0',
        'time':     data['time']     ?? 'N/A',
        'image':    data['image']    ?? '',
        'category': data['category'] ?? '',
        'addedAt':  FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;
      _snack(context, '${data['title']} added to cart ✓');
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, 'Failed to add: $e', isError: true);
    } finally {
      if (mounted) setState(() => _addingIds.remove(docId));
    }
  }

  void _snack(BuildContext ctx, String msg, {bool isError = false}) {
    ScaffoldMessenger.of(ctx).clearSnackBars();
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(color: _textPrimary, fontSize: 13)),
        backgroundColor:
            isError ? _errorColor.withOpacity(0.9) : const Color(0xFF1C2A3A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDeep,
      appBar: AppBar(
        backgroundColor: _bgCard,
        foregroundColor: _textPrimary,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: const Text('Services',
            style: TextStyle(
                color: _textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child:
              Container(height: 1, color: Colors.white.withOpacity(0.06)),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search bar ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: _bgCard,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(color: _textPrimary, fontSize: 14),
                cursorColor: _accentA,
                decoration: InputDecoration(
                  hintText: 'Search services...',
                  hintStyle:
                      const TextStyle(color: _textMuted, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: _textMuted, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: const Icon(Icons.close_rounded,
                              color: _textMuted, size: 18),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),

          // ── Category chips ───────────────────────────────────────────────
          SizedBox(
            height: 54,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              itemCount: _kCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = _kCategories[i];
                final sel = cat.id == _selectedCategory;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedCategory = cat.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel
                          ? _accentA.withOpacity(0.15)
                          : _bgCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel
                            ? _accentA.withOpacity(0.6)
                            : Colors.white.withOpacity(0.07),
                        width: sel ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cat.icon,
                            size: 13,
                            color: sel ? _accentA : _textMuted),
                        const SizedBox(width: 5),
                        Text(cat.label,
                            style: TextStyle(
                              color: sel ? _accentA : _textSecondary,
                              fontSize: 12.5,
                              fontWeight: sel
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            )),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Services grid ────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}',
                        style:
                            const TextStyle(color: _errorColor)),
                  );
                }
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(_accentA)),
                  );
                }

                // Apply client-side search filter
                final allDocs = snapshot.data?.docs ?? [];
                final docs = _searchQuery.isEmpty
                    ? allDocs
                    : allDocs.where((d) {
                        final title = (d.data()['title'] ?? '')
                            .toString()
                            .toLowerCase();
                        return title
                            .contains(_searchQuery.toLowerCase());
                      }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _accentA.withOpacity(0.08),
                          ),
                          child: const Icon(
                              Icons.search_off_rounded,
                              color: _textMuted,
                              size: 32),
                        ),
                        const SizedBox(height: 14),
                        const Text('No services found',
                            style: TextStyle(
                                color: _textSecondary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        const Text('Try a different category',
                            style: TextStyle(
                                color: _textMuted, fontSize: 12)),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding:
                      const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    return _ServiceCard(
                      docId: doc.id,
                      data: data,
                      isAdding: _addingIds.contains(doc.id),
                      onAddToCart: () =>
                          _addToCart(context, doc.id, data),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Service Card ─────────────────────────────────────────────────────────────
class _ServiceCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool isAdding;
  final VoidCallback onAddToCart;

  const _ServiceCard({
    required this.docId,
    required this.data,
    required this.isAdding,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final String title    = data['title']    ?? 'Unknown';
    final String cost     = data['cost']     ?? '₹0';
    final String area     = data['area']     ?? '0';
    final String time     = data['time']     ?? 'N/A';
    final String imageUrl = data['image']    ?? '';
    final String tag      = data['tag']      ?? '';
    final String category = data['category'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Stack(
            children: [
              SizedBox(
                height: 120,
                width: double.infinity,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, prog) {
                          if (prog == null) return child;
                          return Container(
                            color: _bgSurface,
                            child: Center(
                              child: SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(
                                          _accentA.withOpacity(0.5)),
                                ),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) =>
                            _Placeholder(category: category),
                      )
                    : _Placeholder(category: category),
              ),
              // Gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        _bgCard.withOpacity(0.8),
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),
              // Tag badge
              if (tag.isNotEmpty)
                Positioned(
                  top: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: tag == 'New'
                          ? const Color(0xFF7C3AED).withOpacity(0.9)
                          : _accentB.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(tag,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              // Time chip
              Positioned(
                bottom: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 10, color: _textSecondary),
                      const SizedBox(width: 3),
                      Text(time,
                          style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  if (area != '0')
                    Text('$area sq ft',
                        style: const TextStyle(
                            color: _textMuted, fontSize: 11)),
                  const Spacer(),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(cost,
                          style: const TextStyle(
                              color: _accentA,
                              fontSize: 15,
                              fontWeight: FontWeight.w800)),
                      GestureDetector(
                        onTap: isAdding ? null : onAddToCart,
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isAdding
                                ? null
                                : const LinearGradient(
                                    colors: [_accentB, _accentA],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            color: isAdding
                                ? _accentA.withOpacity(0.15)
                                : null,
                            boxShadow: isAdding
                                ? null
                                : [
                                    BoxShadow(
                                      color:
                                          _accentA.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                          ),
                          child: isAdding
                              ? const Center(
                                  child: SizedBox(
                                    width: 14, height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.8,
                                      valueColor:
                                          AlwaysStoppedAnimation<
                                              Color>(_accentA),
                                    ),
                                  ),
                                )
                              : const Icon(Icons.add_rounded,
                                  color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Placeholder image ────────────────────────────────────────────────────────
class _Placeholder extends StatelessWidget {
  final String category;
  const _Placeholder({required this.category});

  IconData get _icon {
    switch (category) {
      case 'Vehicle':   return Icons.directions_car_rounded;
      case 'Home':      return Icons.home_rounded;
      case 'Laundry':   return Icons.local_laundry_service_rounded;
      case 'Outdoor':   return Icons.park_rounded;
      case 'Specialty': return Icons.auto_fix_high_rounded;
      default:          return Icons.miscellaneous_services_rounded;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        height: 120, width: double.infinity,
        color: _bgSurface,
        child: Icon(_icon, color: _textMuted, size: 40),
      );
}
