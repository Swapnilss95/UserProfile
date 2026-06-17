import 'package:flutter/material.dart';

// ─── Design Tokens (matches Services, Cart & SignUp theme) ───────────────────
const Color _bgDeep = Color(0xFF080C14);
const Color _bgCard = Color(0xFF0F1624);
const Color _bgSurface = Color(0xFF141E2E);
const Color _accentA = Color(0xFF00D4AA); // bright teal
const Color _accentB = Color(0xFF00A86B); // emerald
const Color _textPrimary = Color(0xFFE8F0FE);
const Color _textSecondary = Color(0xFF8899B0);
const Color _textMuted = Color(0xFF4A5A72);
// ─────────────────────────────────────────────────────────────────────────────

class BoxDetailScreen extends StatefulWidget {
  final String title;
  final String imageUrl;
  final String time;
  final int baseCost;
  final int ratePerSqMeter;
  final int visitingCharge;
  final int defaultAreaSqM;

  const BoxDetailScreen({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.time,
    required this.baseCost,
    required this.ratePerSqMeter,
    required this.visitingCharge,
    required this.defaultAreaSqM,
  });

  @override
  State<BoxDetailScreen> createState() => _BoxDetailScreenState();
}

class _BoxDetailScreenState extends State<BoxDetailScreen> {
  late double _currentArea;

  @override
  void initState() {
    super.initState();
    _currentArea = widget.defaultAreaSqM.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic formula breakdown: Base Cost + (Selected Area * Rate Per Sq Meter) + Visiting Charge
    double calculatedServiceCost = _currentArea * widget.ratePerSqMeter;
    double totalEstimatedPrice =
        widget.baseCost + calculatedServiceCost + widget.visitingCharge;

    return Scaffold(
      backgroundColor: _bgDeep,
      // ── AppBar ──────────────────────────────────────────────────────────────
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: _bgCard,
        foregroundColor: _textPrimary,
        elevation: 0,
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.white.withOpacity(0.06),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image Header with Gradient Overlay
            Stack(
              children: [
                Image.network(
                  widget.imageUrl,
                  width: double.infinity,
                  height: 240,
                  fit: BoxFit.cover,
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          _bgDeep.withOpacity(0.9),
                        ],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 14, color: _textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'Estimated Duration: ${widget.time}',
                        style: const TextStyle(color: _textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                  
                  Divider(height: 36, color: Colors.white.withOpacity(0.06)),

                  // Interactive Area Customizer Section
                  const Text(
                    'Adjust Job Area Size',
                    style: TextStyle(
                      fontSize: 15, 
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4,
                              thumbColor: _accentA,
                              activeTrackColor: _accentA,
                              inactiveTrackColor: _bgSurface,
                              overlayColor: _accentA.withOpacity(0.15),
                              valueIndicatorColor: _bgSurface,
                              valueIndicatorTextStyle: const TextStyle(color: _accentA),
                            ),
                            child: Slider(
                              value: _currentArea,
                              min: 1,
                              max: (widget.defaultAreaSqM * 2).toDouble() < 1 
                                  ? 100 
                                  : (widget.defaultAreaSqM * 2).toDouble(),
                              divisions: 100,
                              label: '${_currentArea.round()} sq m',
                              onChanged: (newValue) {
                                setState(() {
                                  _currentArea = newValue;
                                });
                              },
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _bgSurface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_currentArea.round()} sq m',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _accentA,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Divider(height: 40, color: Colors.white.withOpacity(0.06)),

                  // Pricing Invoice Summary Card
                  Container(
                    decoration: BoxDecoration(
                      color: _bgCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.06),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Price Breakdown',
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildPriceRow(
                            'Base Package Fixed Minimum',
                            '₹${widget.baseCost}',
                          ),
                          _buildPriceRow(
                            'Area Service Charge (${_currentArea.round()} sq m × ₹${widget.ratePerSqMeter})',
                            '₹${calculatedServiceCost.round()}',
                          ),
                          _buildPriceRow(
                            'Outstation Visiting Fee',
                            '₹${widget.visitingCharge}',
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Divider(color: Colors.white.withOpacity(0.08), thickness: 1),
                          ),
                          _buildPriceRow(
                            'Total Estimated Amount',
                            '₹${totalEstimatedPrice.round()}',
                            isTotal: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.w700 : FontWeight.w400,
                fontSize: isTotal ? 15 : 13.5,
                color: isTotal ? _textPrimary : _textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
              fontSize: isTotal ? 17 : 14,
              color: isTotal ? _accentA : _textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}