import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Ensure these paths match your folder structure
import '../../models/issue_model.dart'; 
import '../user/issue_detail_screen.dart'; 

class AdminNotificationsScreen extends StatelessWidget {
  final String? sector;
  final String? region;

  const AdminNotificationsScreen({super.key, this.sector, this.region});

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Query filters notifications by the admin's assigned sector
    Query query = FirebaseFirestore.instance.collection('Notifications')
        .where('sector', isEqualTo: sector);

    if (region != null) {
      query = query.where('region', isEqualTo: region);
    }

    query = query.orderBy('timestamp', descending: true);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => _markAllAsRead(currentUserId),
            child: const Text("Mark all read", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              List readBy = data['readBy'] ?? [];
              bool isRead = readBy.contains(currentUserId);

              return _buildNotificationItem(
                context: context,
                docId: doc.id,
                data: data,
                isRead: isRead,
                userId: currentUserId,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem({
    required BuildContext context,
    required String docId,
    required Map<String, dynamic> data,
    required bool isRead,
    required String userId,
  }) {
    DateTime? time = (data['timestamp'] as Timestamp?)?.toDate();
    String formattedTime = time != null ? DateFormat('MMM d, h:mm a').format(time) : '';

    return Container(
      color: isRead ? Colors.transparent : Colors.indigo.withOpacity(0.04),
      child: ListTile(
        onTap: () => _handleNotificationTap(context, docId, userId, data['issueId']),
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: _getIconColor(data['type']).withOpacity(0.1),
              child: Icon(_getIcon(data['type']), color: _getIconColor(data['type'])),
            ),
            if (!isRead)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          data['title'] ?? 'New Update',
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            fontSize: 15,
            color: isRead ? Colors.black87 : Colors.black,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['body'] ?? '', style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 4),
            Text(formattedTime, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
      ),
    );
  }

  Future<void> _handleNotificationTap(
      BuildContext context, String docId, String userId, String? issueId) async {
    
    // 1. Mark as read in Firestore
    await FirebaseFirestore.instance.collection('Notifications').doc(docId).update({
      'readBy': FieldValue.arrayUnion([userId])
    });

    if (issueId == null || issueId.isEmpty) return;

    // 2. Fetch the Issue details to pass to detail screen
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      DocumentSnapshot issueDoc = await FirebaseFirestore.instance
          .collection('Issues')
          .doc(issueId)
          .get();

      if (context.mounted) Navigator.pop(context); // Close loading dialog

      if (issueDoc.exists && context.mounted) {
        final issue = Issue.fromFirestore(issueDoc);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => IssueDetailScreen(issue: issue),
          ),
        );
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Issue details are no longer available.")),
          );
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      debugPrint("Error fetching issue: $e");
    }
  }

  Future<void> _markAllAsRead(String userId) async {
    Query query = FirebaseFirestore.instance
        .collection('Notifications')
        .where('sector', isEqualTo: sector);

    if (region != null) {
      query = query.where('region', isEqualTo: region);
    }

    var snapshots = await query.get();

    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshots.docs) {
      batch.update(doc.reference, {
        'readBy': FieldValue.arrayUnion([userId])
      });
    }
    await batch.commit();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 70, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("No recent alerts found", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  IconData _getIcon(String? type) {
    if (type == 'new_issue') return Icons.report_gmailerrorred_rounded;
    if (type == 'resolved') return Icons.check_circle_rounded;
    return Icons.notifications_active_rounded;
  }

  Color _getIconColor(String? type) {
    if (type == 'new_issue') return Colors.orange;
    if (type == 'resolved') return Colors.green;
    return Colors.indigo;
  }
}