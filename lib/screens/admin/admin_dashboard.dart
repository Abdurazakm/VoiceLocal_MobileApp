import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../screens/admin/user_management_screen.dart';
import '../user/home_screen.dart'; 
import '../../screens/admin/system_analytics_screen.dart';
import '../../models/user_model.dart';
import '../user/profile/ProfileScreen.dart'; 
import 'notifications_screen.dart'; // Ensure this file exists

class AdminDashboard extends StatelessWidget {
  final UserModel currentUser;

  const AdminDashboard({super.key, required this.currentUser});

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final String? sector = currentUser.assignedSector;
    final String? region = currentUser.region;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text(currentUser.role == 'super_admin' ? "Super Admin" : "${sector ?? 'Sector'} Admin"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          _buildNotificationBadge(context), // NOTIFICATION WITH COUNTER
          _buildProfileButton(context, currentUser.uid),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => Future.delayed(const Duration(seconds: 1)),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(sector, region),
              
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text("Regional Overview", 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blueGrey)),
              ),
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
              
              _buildMenuTile(
                context,
                title: "Sign Out",
                subtitle: "Safely exit your admin session",
                icon: Icons.logout_rounded,
                color: Colors.redAccent,
                onTap: () => FirebaseAuth.instance.signOut(),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- NOTIFICATION BADGE LOGIC ---
  Widget _buildNotificationBadge(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Notifications')
          .where('sector', isEqualTo: currentUser.assignedSector)
          .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = 0;
        if (snapshot.hasData) {
          // Count notifications where currentUser.uid is NOT in the readBy array
          unreadCount = snapshot.data!.docs.where((doc) {
            List readBy = doc['readBy'] ?? [];
            return !readBy.contains(currentUser.uid);
          }).length;
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, size: 28),
              onPressed: () => Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => AdminNotificationsScreen(
                  sector: currentUser.assignedSector,
                  region: currentUser.region,
                ))
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildProfileButton(BuildContext context, String uid) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('Users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        String? url = (snapshot.data?.data() as Map<String, dynamic>?)?['profilePic'];
        return InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: CircleAvatar(
              backgroundColor: Colors.white24,
              radius: 16,
              backgroundImage: (url != null && url.isNotEmpty) ? NetworkImage(url) : null,
              child: (url == null || url.isEmpty) ? const Icon(Icons.person, color: Colors.white, size: 18) : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(String? sector, String? region) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: Colors.indigo.withOpacity(0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Welcome, ${currentUser.name}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(currentUser.role == 'super_admin' ? "System Administrator" : "Assigned: $sector Sector | $region",
            style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStatGrid(String? sector, String? region) {
    Query query = FirebaseFirestore.instance.collection('Issues');
    if (currentUser.role == 'sector_admin') {
      query = query.where('category', isEqualTo: _toTitleCase(sector ?? '')).where('region', isEqualTo: _toTitleCase(region ?? ''));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
        final docs = snapshot.data!.docs;
        int total = docs.length;
        int resolved = docs.where((d) => (d.data() as Map)['status'] == 'Resolved').length;
        int pending = total - resolved;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
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

  Widget _statCard(String label, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)]),
      child: ListTile(
        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}