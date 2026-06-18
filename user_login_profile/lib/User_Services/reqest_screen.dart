import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const Color _bgDeep    = Color(0xFF080C14);
const Color _bgCard    = Color(0xFF0F1624);
const Color _bgSurface = Color(0xFF141E2E);
const Color _accentA   = Color(0xFF00D4AA);
const Color _accentB   = Color(0xFF00A86B);
const Color _textPrimary   = Color(0xFFE8F0FE);
const Color _textSecondary = Color(0xFF8899B0);
const Color _textMuted     = Color(0xFF4A5A72);

class RequestsPage extends StatelessWidget {
  const RequestsPage({super.key});

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case "pending":
      case "accepted":
        return _accentB;
      case "completed":
        return Colors.blueAccent;
      case "cancelled":
        return Colors.redAccent;
      default:
        return Colors.orangeAccent; // "request" = waiting
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case "request":   return "Waiting for Washmitra";
      case "pending":   return "Washmitra Assigned";
      case "completed": return "Completed";
      default:          return status;
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return "Just now";
    if (value is Timestamp) {
      return DateFormat("dd MMM yyyy, hh:mm a")
          .format(value.toDate());
    }
    return "N/A";
  }

  Future<void> _deleteJob(
      BuildContext context, String id) async {
    try {
      // ✅ FIX: delete from "Jobs" not "requests"
      await FirebaseFirestore.instance
          .collection("Jobs")
          .doc(id)
          .delete();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Request deleted"),
          backgroundColor: _accentB,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _deleteDialog(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _bgCard,
        title: const Text("Delete Request?",
            style: TextStyle(color: _textPrimary)),
        content: const Text("Remove this order permanently?",
            style: TextStyle(color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteJob(context, id);
            },
            child: const Text("Delete",
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _bgDeep,
      appBar: AppBar(
        backgroundColor: _bgCard,
        title: const Text("My Order Requests",
            style: TextStyle(color: _textPrimary)),
      ),
      body: user == null
          ? const Center(
              child: Text("Please login",
                  style: TextStyle(color: _textSecondary)),
            )
          : StreamBuilder<QuerySnapshot>(
              // ✅ FIX: read from "Jobs" with correct field "userId"
              stream: FirebaseFirestore.instance
                  .collection("Jobs")
                  .where("userId", isEqualTo: user.uid)
                  .orderBy("createdAt", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        snapshot.error.toString(),
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: _accentA),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_outlined,
                            color: _textMuted, size: 56),
                        const SizedBox(height: 16),
                        const Text("No requests yet",
                            style: TextStyle(
                                color: _textSecondary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        const Text(
                            "Add services to cart and checkout",
                            style: TextStyle(
                                color: _textMuted,
                                fontSize: 13)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc  = docs[index];
                    final data =
                        doc.data() as Map<String, dynamic>;
                    final items =
                        List.from(data["items"] ?? []);
                    final status =
                        data["status"]?.toString() ?? "request";

                    return Card(
                      color: _bgCard,
                      margin: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14)),
                      child: ExpansionTile(
                        iconColor: _textSecondary,
                        collapsedIconColor: _textSecondary,
                        title: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "₹${data["totalAmount"] ?? 0}",
                              style: const TextStyle(
                                color: _textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _statusColor(status)
                                        .withOpacity(0.15),
                                    borderRadius:
                                        BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _statusLabel(status),
                                    style: TextStyle(
                                      color:
                                          _statusColor(status),
                                      fontSize: 11,
                                      fontWeight:
                                          FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _deleteDialog(
                                      context, doc.id),
                                  icon: const Icon(Icons.delete,
                                      color: Colors.redAccent),
                                ),
                              ],
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              data["serviceType"] ??
                                  "Multiple Services",
                              style: const TextStyle(
                                  color: _textSecondary),
                            ),
                            Text(
                              _formatDate(data["createdAt"]),
                              style: const TextStyle(
                                  color: _textMuted),
                            ),
                          ],
                        ),
                        children: [
                          Container(
                            color: _bgSurface,
                            child: Column(
                              children: items.map<Widget>((e) {
                                final item = Map<String,
                                    dynamic>.from(e);
                                return ListTile(
                                  leading: item["image"] != null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius
                                                  .circular(6),
                                          child: Image.network(
                                            item["image"],
                                            width: 45,
                                            height: 45,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (_, __, ___) =>
                                                    const Icon(
                                              Icons.shopping_bag,
                                              color:
                                                  _textSecondary,
                                            ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.shopping_bag,
                                          color: _textSecondary),
                                  title: Text(
                                      item["title"] ?? "Item",
                                      style: const TextStyle(
                                          color: _textPrimary)),
                                  subtitle: Text(
                                      "${item["area"] ?? ""} sq ft",
                                      style: const TextStyle(
                                          color: _textSecondary)),
                                  trailing: Text(
                                      item["cost"] ?? "₹0",
                                      style: const TextStyle(
                                          color: _accentA)),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}