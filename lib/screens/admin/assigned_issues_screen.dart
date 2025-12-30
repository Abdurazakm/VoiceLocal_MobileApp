import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import 'status_update_dialog.dart'; // We created this earlier

class AssignedIssuesScreen extends StatelessWidget {
  final UserModel currentUser;

  const AssignedIssuesScreen({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    // Build the query based on Admin Jurisdiction
    Query issueQuery = FirebaseFirestore.instance.collection('Issues');

    // If it's a Sector Admin, apply strict filters (FR-13)
    if (currentUser.role == 'sector_admin') {
      issueQuery = issueQuery
          .where('category', isEqualTo: currentUser.assignedSector)
          .where('region', isEqualTo: currentUser.assignedRegion);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(currentUser.role == 'super_admin' 
            ? "All System Issues" 
            : "${currentUser.assignedSector} Issues"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: issueQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text("No issues found in your jurisdiction.", 
                    style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String status = data['status'] ?? 'Open';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: _getStatusIcon(status),
                  title: Text(data['title'] ?? 'Untitled'),
                  subtitle: Text("Location: ${data['street']}, ${data['region']}"),
                  trailing: const Icon(Icons.edit_note),
                  onTap: () {
                    // Open the Status Update Dialog (FR-9)
                    showDialog(
                      context: context,
                      builder: (context) => StatusUpdateDialog(
                        issueId: docs[index].id,
                        currentStatus: status,
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _getStatusIcon(String status) {
    switch (status) {
      case 'Resolved':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'In Review':
        return const Icon(Icons.pending, color: Colors.orange);
      default:
        return const Icon(Icons.error_outline, color: Colors.red);
    }
  }
}