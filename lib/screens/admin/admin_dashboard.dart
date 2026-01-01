import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../screens/admin/user_management_screen.dart';
import '../user/home_screen.dart'; 
import '../../screens/admin/system_analytics_screen.dart';
import '../../models/user_model.dart';

class AdminDashboard extends StatelessWidget {
  final UserModel currentUser;

  const AdminDashboard({super.key, required this.currentUser});

  // EXACT same helper as your UserHome to ensure query match
  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    // Determine the sector and region based on how your UserHome does it
    // Based on your UserHome code, sector is 'assignedSector' and region is 'region'
    final String? sector = currentUser.assignedSector;
    final String? region = currentUser.region; 

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text(currentUser.role == 'super_admin' 
            ? "Super Admin Panel" 
            : "${sector ?? 'Sector'} Admin"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(sector, region),
            _buildStatGrid(sector, region), 
            
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text("Management Tools", 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            
            _buildMenuTile(
              context,
              title: "View Assigned Issues",
              subtitle: currentUser.role == 'super_admin' 
                  ? "Manage all system-wide reports" 
                  : "Manage reports in ${region ?? 'your region'}",
              icon: Icons.assignment_outlined,
              color: Colors.orange,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UserHome())),
            ),

            if (currentUser.role == 'super_admin') ...[
              _buildMenuTile(
                context,
                title: "User Management",
                subtitle: "Promote users and manage roles",
                icon: Icons.group_add_outlined,
                color: Colors.purple,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UserManagementScreen())),
              ),
              _buildMenuTile(
                context,
                title: "System Analytics",
                subtitle: "View reporting trends",
                icon: Icons.analytics_outlined,
                color: Colors.blue,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SystemAnalyticsScreen())),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String? sector, String? region) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: Colors.indigo.withOpacity(0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Welcome back, ${currentUser.name}", 
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.verified_user, size: 16, color: Colors.indigo),
              const SizedBox(width: 4),
              Text(currentUser.role.replaceAll('_', ' ').toUpperCase(), 
                style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
          if (currentUser.role == 'sector_admin') ...[
            const SizedBox(height: 8),
            Text("Jurisdiction: $sector | $region", 
              style: const TextStyle(fontSize: 14, color: Colors.blueGrey)),
          ],
        ],
      ),
    );
  }

  Widget _buildStatGrid(String? sector, String? region) {
    Query query = FirebaseFirestore.instance.collection('Issues');

    if (currentUser.role == 'sector_admin' && sector != null) {
      // Use the exact same TitleCase and Field logic as UserHome
      query = query
          .where('category', isEqualTo: _toTitleCase(sector))
          .where('region', isEqualTo: _toTitleCase(region ?? ''));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: LinearProgressIndicator());
        
        final docs = snapshot.data!.docs;
        int total = docs.length;
        int resolved = docs.where((d) => (d.data() as Map)['status'] == 'Resolved').length;
        int pending = total - resolved;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              _statCard("Total", total.toString(), Colors.blue),
              const SizedBox(width: 12),
              _statCard("Pending", pending.toString(), Colors.orange),
              const SizedBox(width: 12),
              _statCard("Resolved", resolved.toString(), Colors.green),
            ],
          ),
        );
      },
    );
  }

  // ... (Keep your _statCard and _buildMenuTile widgets the same as before)
  Widget _statCard(String label, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Text(count, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade100)),
      child: ListTile(
        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: onTap,
      ),
    );
  }
}