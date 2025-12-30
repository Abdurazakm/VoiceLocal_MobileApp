import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../screens/admin/user_management_screen.dart';
import '../../screens/admin/assigned_issues_screen.dart';
import '../../screens/admin/system_analytics_screen.dart';
import '../../models/user_model.dart';

class AdminDashboard extends StatelessWidget {
  final UserModel currentUser;

  const AdminDashboard({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(currentUser.role == 'super_admin' 
            ? "Super Admin Panel" 
            : "Sector Admin: ${currentUser.assignedSector}"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildStatGrid(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Management Tools", 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            
            // SECTION 1: SECTOR ADMIN TOOLS (FR-9, FR-13)
            if (currentUser.role == 'sector_admin' || currentUser.role == 'super_admin')
              _buildMenuTile(
                context,
                title: "Assigned Issues",
                subtitle: "Manage ${currentUser.assignedSector ?? 'All'} issues in ${currentUser.assignedRegion ?? 'All Regions'}",
                icon: Icons.assignment_outlined,
                color: Colors.orange,
onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => AssignedIssuesScreen(currentUser: currentUser),
    ),
  );
},
              ),

            // SECTION 2: SUPER ADMIN TOOLS (FR-11, FR-12)
            if (currentUser.role == 'super_admin') ...[
              _buildMenuTile(
                context,
                title: "User Management",
                subtitle: "Promote users to Sector Admins",
                icon: Icons.group_add_outlined,
                color: Colors.purple,
onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const UserManagementScreen()),
  );
},
              ),
 _buildMenuTile(
  context,
  title: "System Analytics",
  subtitle: "View reporting trends and heatmaps",
  icon: Icons.analytics_outlined,
  color: Colors.blue,
  onTap: () {
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => const SystemAnalyticsScreen())
    );
  },
),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: Colors.indigo.withOpacity(0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Welcome back, ${currentUser.name}", 
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text("Role: ${currentUser.role.toUpperCase()}", 
            style: TextStyle(color: Colors.indigo.shade700, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildStatGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('Issues').snapshots(),
      builder: (context, snapshot) {
        int total = snapshot.data?.docs.length ?? 0;
        int open = snapshot.data?.docs.where((d) => d['status'] == 'Open').length ?? 0;
        int resolved = snapshot.data?.docs.where((d) => d['status'] == 'Resolved').length ?? 0;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              _statCard("Total", total.toString(), Colors.blue),
              const SizedBox(width: 10),
              _statCard("Pending", open.toString(), Colors.orange),
              const SizedBox(width: 10),
              _statCard("Resolved", resolved.toString(), Colors.green),
            ],
          ),
        );
      },
    );
  }

  Widget _statCard(String label, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(count, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile(BuildContext context, {
    required String title, 
    required String subtitle, 
    required IconData icon, 
    required Color color,
    required VoidCallback onTap}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}