import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:user_login_profile/User_Services/box_details.dart';

// ─── Design Tokens (matches Cart & SignUp theme) ──────────────────────────────
const _bgDeep    = Color(0xFF080C14);
const _bgCard    = Color(0xFF0F1624);
const _bgSurface = Color(0xFF141E2E);
const _accentA   = Color(0xFF00D4AA); // bright teal
const _accentB   = Color(0xFF00A86B); // emerald
const _textPrimary   = Color(0xFFE8F0FE);
const _textSecondary = Color(0xFF8899B0);
const _textMuted     = Color(0xFF4A5A72);
const _errorColor    = Color(0xFFFF5C6E);
// ─────────────────────────────────────────────────────────────────────────────

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  // All washing-related service categories
  final List<String> _categories = [
    'All',
    'Laundry',
    'Home',
    'Vehicle',
    'Outdoor',
    'Specialty',
  ];

  // 10 washing services with Unsplash images
  final List<Map<String, String>> _allServices = [
    {
      'title': 'Premium Laundry',
      'image': 'https://images.unsplash.com/photo-1517677208171-0bc6725a3e60?q=80&w=600&auto=format&fit=crop',
      'cost': '₹350',
      'time': '1 Day',
      'area': '50',
      'category': 'Laundry',
      'tag': 'Popular',
    },
    {
      'title': 'Dry Cleaning',
      'image': 'https://images.unsplash.com/photo-1545173168-9f1947e80154?q=80&w=600&auto=format&fit=crop',
      'cost': '₹650',
      'time': '2 Days',
      'area': '30',
      'category': 'Laundry',
      'tag': '',
    },
    {
      'title': 'Full House Wash',
      'image': 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?q=80&w=600&auto=format&fit=crop',
      'cost': '₹4,500',
      'time': '1 Day',
      'area': '2200',
      'category': 'Home',
      'tag': 'Best Value',
    },
    {
      'title': 'Carpet Deep Wash',
      'image': 'https://images.unsplash.com/photo-1558317374-067fb5f30001?q=80&w=600&auto=format&fit=crop',
      'cost': '₹950',
      'time': '1 Day',
      'area': '250',
      'category': 'Home',
      'tag': '',
    },
    {
      'title': 'Sofa & Upholstery',
      'image': 'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?q=80&w=600&auto=format&fit=crop',
      'cost': '₹800',
      'time': '3 Hours',
      'area': '100',
      'category': 'Home',
      'tag': '',
    },
    {
      'title': 'Window & Glass',
      'image': 'https://images.unsplash.com/photo-1627905646269-7f03bd04b36a?q=80&w=600&auto=format&fit=crop',
      'cost': '₹1,200',
      'time': '5 Hours',
      'area': '450',
      'category': 'Home',
      'tag': '',
    },
    {
      'title': 'Car Wash & Polish',
      'image': 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?q=80&w=600&auto=format&fit=crop',
      'cost': '₹599',
      'time': '2 Hours',
      'area': '20',
      'category': 'Vehicle',
      'tag': 'New',
    },
    {
      'title': 'Bike Detailing',
      'image': 'https://images.unsplash.com/photo-1558981806-ec527fa84c39?q=80&w=600&auto=format&fit=crop',
      'cost': '₹299',
      'time': '1 Hour',
      'area': '10',
      'category': 'Vehicle',
      'tag': '',
    },
    {
      'title': 'Garden Jet Wash',
      'image': 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?q=80&w=600&auto=format&fit=crop',
      'cost': '₹1,800',
      'time': '4 Hours',
      'area': '800',
      'category': 'Outdoor',
      'tag': '',
    },
    {
      'title': 'Mattress Sanitise',
      'image': 'https://images.unsplash.com/photo-1631049307264-da0ec9d70304?q=80&w=600&auto=format&fit=crop',
      'cost': '₹499',
      'time': '2 Hours',
      'area': '40',
      'category': 'Specialty',
      'tag': 'New',
    },
  ];

  List<Map<String, String>> get _filteredServices {
    return _allServices.where((item) {
      final matchesSearch = item['title']!
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' ||
          item['category'] == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  Future<void> _addToCart(
    BuildContext context,
    Map<String, String> item,
    String userId,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cart')
          .add({
        'title': item['title'],
        'image': item['image'],
        'cost': item['cost'],
        'time': item['time'],
        'area': item['area'],
        'addedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item['title']} added to cart!'),
          backgroundColor: const Color(0xFF0F1624),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add: $e'),
          backgroundColor: _errorColor.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _openDetail(BuildContext context, Map<String, String> item) {
    final cleanCost =
        item['cost']!.replaceAll(RegExp(r'[^\d]'), '');
    final int parsedCost = int.tryParse(cleanCost) ?? 0;
    final double parsedAreaSqFt =
        double.tryParse(item['area']!) ?? 0.0;
    final int parsedAreaSqM = (parsedAreaSqFt * 0.092903).round();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BoxDetailScreen(
          title: item['title']!,
          imageUrl: item['image']!,
          time: item['time']!,
          baseCost: parsedCost,
          ratePerSqMeter: 15,
          visitingCharge: 50,
          defaultAreaSqM: parsedAreaSqM > 0 ? parsedAreaSqM : 20,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final filtered = _filteredServices;

    return Scaffold(
      backgroundColor: _bgDeep,
      // ── AppBar ──────────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: _bgCard,
        foregroundColor: _textPrimary,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Services',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          // Cart icon badge placeholder
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.shopping_cart_outlined,
                    color: _textSecondary, size: 24),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
              height: 1, color: Colors.white.withOpacity(0.06)),
        ),
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search bar ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: _bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.white.withOpacity(0.07), width: 1),
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
                      const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          // ── Category chips ───────────────────────────────────────────────────
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final isSelected = cat == _selectedCategory;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedCategory = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _accentA.withOpacity(0.15)
                          : _bgCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? _accentA.withOpacity(0.6)
                            : Colors.white.withOpacity(0.07),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: isSelected ? _accentA : _textSecondary,
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Result count ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              '${filtered.length} service${filtered.length != 1 ? 's' : ''}',
              style:
                  const TextStyle(color: _textMuted, fontSize: 12),
            ),
          ),

          // ── Grid ─────────────────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded,
                            color: _textMuted, size: 48),
                        const SizedBox(height: 12),
                        const Text('No services found',
                            style: TextStyle(
                                color: _textSecondary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        const Text('Try a different search or category',
                            style: TextStyle(
                                color: _textMuted, fontSize: 13)),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _ServiceCard(
                        item: item,
                        user: user,
                        onTap: () => _openDetail(context, item),
                        onAddToCart: () => user == null
                            ? ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                      'Log in to add items to cart.'),
                                  backgroundColor: _bgCard,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  margin: const EdgeInsets.all(16),
                                ),
                              )
                            : _addToCart(context, item, user.uid),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Service Card Widget ──────────────────────────────────────────────────────
class _ServiceCard extends StatelessWidget {
  final Map<String, String> item;
  final User? user;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const _ServiceCard({
    required this.item,
    required this.user,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final String tag = item['tag'] ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: Colors.white.withOpacity(0.06), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image area ──────────────────────────────────────────────
            Stack(
              children: [
                // Photo
                SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: Image.network(
                    item['image']!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: _bgSurface,
                      child: const Center(
                        child: Icon(Icons.water_drop_outlined,
                            color: _textMuted, size: 32),
                      ),
                    ),
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: _bgSurface,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
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
                  ),
                ),

                // Gradient overlay on image
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          _bgCard.withOpacity(0.85),
                        ],
                        stops: const [0.45, 1.0],
                      ),
                    ),
                  ),
                ),

                // Tag badge (Popular / New / Best Value)
                if (tag.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: tag == 'New'
                            ? const Color(0xFF7C3AED).withOpacity(0.9)
                            : _accentB.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                // Time chip on image
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
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
                        Text(
                          item['time']!,
                          style: const TextStyle(
                              color: _textSecondary, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── Details ─────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title']!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item['area']} sq ft',
                      style: const TextStyle(
                          color: _textMuted, fontSize: 11),
                    ),
                    const Spacer(),

                    // Price + Add to Cart row
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item['cost']!,
                          style: const TextStyle(
                            color: _accentA,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        GestureDetector(
                          onTap: onAddToCart,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [_accentB, _accentA],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _accentA.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
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
      ),
    );
  }
}