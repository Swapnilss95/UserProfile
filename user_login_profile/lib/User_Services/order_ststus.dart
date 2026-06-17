import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:user_login_profile/userprofil.dart';

class PaymentScreen extends StatefulWidget {
  final bool? isSuccess; 
  final String transactionRef;
  final String amount;
  final String? errorMessage;

  const PaymentScreen({
    super.key,
    this.isSuccess,
    required this.transactionRef,
    required this.amount,
    this.errorMessage,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _ThemeColors {
  static const Color primaryPurple = Color(0xFF6366F1);
  static const Color successGreen = Color(0xFF10B981);
  static const Color alertRed = Color(0xFFEF4444);
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isLoading = true;
  late bool _finalSuccessState;
  late String _finalRequestId;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Dynamic User Booking Details from Firestore
  String _userName = "Loading...";
  String _userMobile = "Loading...";
  String _serviceAddress = "Loading...";
  String _scheduledDate = "Loading...";
  String _scheduledTime = "Loading...";

  // Dynamic Partner values from Firestore
  String _providerName = "Loading...";
  String _providerMobile = "Loading...";
  String _storeName = "Loading...";
  String _storeAddress = "Loading...";

  @override
  void initState() {
    super.initState();
    _simulateRequestCheck();
  }

  void _simulateRequestCheck() async {
    _finalRequestId = widget.transactionRef.isEmpty || widget.transactionRef == 'N/A'
        ? 'REQ-${Random().nextInt(8999) + 1000}'
        : widget.transactionRef;

    try {
      DocumentSnapshot requestDoc = await _firestore
          .collection('requests') 
          .doc(_finalRequestId)
          .get();

      if (requestDoc.exists && mounted) {
        _parseAndSetRequestData(requestDoc.data() as Map<String, dynamic>);
      } else {
        QuerySnapshot fallbackQuery = await _firestore
            .collection('requests')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

        if (fallbackQuery.docs.isNotEmpty && mounted) {
          var latestDoc = fallbackQuery.docs.first;
          _finalRequestId = latestDoc.id; 
          _parseAndSetRequestData(latestDoc.data() as Map<String, dynamic>);
        } else {
          setState(() {
            _finalSuccessState = widget.isSuccess ?? false;
            _userName = "Unknown User";
            _userMobile = "N/A";
            _serviceAddress = "No matching profile found in database";
            _scheduledDate = "N/A";
            _scheduledTime = "N/A";
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching parameters from Firestore: $e");
      setState(() {
        _finalSuccessState = widget.isSuccess ?? false;
        _userName = "Error Loading";
        _userMobile = "Error Loading";
        _serviceAddress = e.toString();
      });
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _parseAndSetRequestData(Map<String, dynamic> requestData) async {
    String currentStatus = requestData['status'] ?? '';
    bool isApproved = currentStatus.toLowerCase() == 'approved' || currentStatus.toLowerCase() == 'accepted';

    setState(() {
      _finalSuccessState = widget.isSuccess ?? isApproved;
      _userName = requestData['userName'] ?? 'Not Disclosed';
      _userMobile = requestData['userPhone'] ?? 'Not Disclosed';
      _serviceAddress = requestData['serviceAddress'] ?? 'Not Provided';
      _scheduledDate = requestData['scheduledDate'] ?? 'Not Scheduled';
      _scheduledTime = requestData['scheduledTime'] ?? 'Not Scheduled';
    });

    if (_finalSuccessState && requestData.containsKey('partnerId')) {
      String partnerId = requestData['partnerId'];

      DocumentSnapshot partnerDoc = await _firestore
          .collection('partners') 
          .doc(partnerId)
          .get();

      if (partnerDoc.exists && mounted) {
        final partnerData = partnerDoc.data() as Map<String, dynamic>;
        setState(() {
          _providerName = partnerData['name'] ?? 'Not Disclosed';
          _providerMobile = partnerData['mobile'] ?? partnerData['phone'] ?? 'Not Disclosed';
          _storeName = partnerData['storeName'] ?? 'Wahmitra Partner Hub';
          _storeAddress = partnerData['storeAddress'] ?? partnerData['address'] ?? 'Not Provided';
        });
      }
    }
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
              ? _buildLoadingState() 
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                  child: _buildStatusState(context),
                ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            height: 55,
            width: 55,
            child: CircularProgressIndicator(
              strokeWidth: 4.5,
              valueColor: AlwaysStoppedAnimation<Color>(_ThemeColors.primaryPurple),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            "Syncing Request Status...",
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            "Checking authorization pipelines on Wahmitra servers...",
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusState(BuildContext context) {
    final statusColor = _finalSuccessState ? _ThemeColors.successGreen : _ThemeColors.alertRed;

    return Column(
      children: [
        const SizedBox(height: 20),
        // Decorative Status Icon
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
          ),
          child: Icon(
            _finalSuccessState ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
            color: statusColor,
            size: 72,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _finalSuccessState ? "Request Approved!" : "Request Order Status",
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
        ),
        const SizedBox(height: 12),
        Text(
          _finalSuccessState 
              ? "Wahmitra has verified and successfully completed your service pipeline request setup."
              : (widget.errorMessage ?? "Your request layout parameters are actively logged in our registry database."),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7), height: 1.5),
        ),
        const SizedBox(height: 32),
        
        // Track ID Row Glass Card
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Track ID", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.5), fontSize: 14)),
              Text(
                _finalRequestId, 
                style: const TextStyle(fontFamily: 'monospace', fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // SECTION 1: Your Real-time Firestore Booking Details Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment_outlined, color: _ThemeColors.primaryPurple, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    "Your Booking Information",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.95)),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Divider(color: Colors.white.withOpacity(0.1), height: 1),
              ),
              _buildInfoRow(Icons.person_outline, "Name", _userName),
              const SizedBox(height: 14),
              _buildInfoRow(Icons.phone_android, "Mobile", _userMobile),
              const SizedBox(height: 14),
              _buildInfoRow(Icons.location_on_outlined, "Address", _serviceAddress),
              const SizedBox(height: 14),
              _buildInfoRow(Icons.calendar_today_outlined, "Date Scheduled", _scheduledDate),
              const SizedBox(height: 14),
              _buildInfoRow(Icons.access_time, "Time Window", _scheduledTime),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // SECTION 2: Partner Details Section (Shows only on Active Approvals)
        if (_finalSuccessState) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _ThemeColors.successGreen.withOpacity(0.25), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.storefront, color: _ThemeColors.successGreen, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      "Assigned Partner Details",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.95)),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Divider(color: Colors.white.withOpacity(0.1), height: 1),
                ),
                _buildInfoRow(Icons.person_outline, "Name", _providerName),
                const SizedBox(height: 14),
                _buildInfoRow(Icons.phone_android, "Mobile", _providerMobile),
                const SizedBox(height: 14),
                _buildInfoRow(Icons.business, "Store Name", _storeName),
                const SizedBox(height: 14),
                _buildInfoRow(Icons.location_on_outlined, "Address", _storeAddress),
              ],
            ),
          ),
          const SizedBox(height: 35),
        ] else ...[
          const SizedBox(height: 35),
        ],
        
        // Navigation Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _finalSuccessState ? _ThemeColors.primaryPurple : Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              side: _finalSuccessState ? BorderSide.none : BorderSide(color: Colors.white.withOpacity(0.3), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              if (_finalSuccessState) {
                UserProfileScreen.switchToServicesTab(context);
              } else {
                Navigator.pop(context);
              }
            },
            child: Text(
              _finalSuccessState ? "Return to Store" : "Modify Request",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.white.withOpacity(0.4)),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
          ),
        ),
      ],
    );
  }
}