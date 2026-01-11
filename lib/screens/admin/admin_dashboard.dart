import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../screens/admin/user_management_screen.dart';
import '../user/home_screen.dart'; 
import '../../screens/admin/system_analytics_screen.dart';
import '../../models/user_model.dart';
import '../user/profile/ProfileScreen.dart'; 
import 'notifications_screen.dart';
// Added Seed Service Import
import '../seed_service.dart';

class AdminDashboard extends StatelessWidget {
  final UserModel currentUser;

  const AdminDashboard({super.key, required this.currentUser});

  // Professional Color Palette (Matching UserManagementScreen)
  final Color primaryColor = const Color(0xFF1A237E); 
  final Color backgroundColor = const Color(0xFFF8F9FE);

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final String? sector = currentUser.assignedSector;
    final String? region = currentUser.assignedRegion; // Changed to match common field name

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          currentUser.role == 'super_admin' ? "Super Admin Panel" : "${sector ?? 'Sector'} Management",
          style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // Added Seed & Clear Functionality for Super Admin
          if (currentUser.role == 'super_admin') ...[
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
              tooltip: "Clear Database",
              onPressed: () => _showClearConfirmation(context),
            ),
            IconButton(
              icon: const Icon(Icons.storage_rounded, color: Colors.orangeAccent),
              tooltip: "Seed Demo Data",
              onPressed: () => _showSeedConfirmation(context),
            ),
          ],
          _buildNotificationBadge(context),
          _buildProfileButton(context, currentUser.uid),
          const SizedBox(width: 12),
        ],
      ),
      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: () async => Future.delayed(const Duration(seconds: 1)),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(sector, region),
              
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 25, 20, 12),
                child: Text(
                  "REGIONAL OVERVIEW", 
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 1.2),
                ),
              ),
              _buildStatGrid(sector, region), 

              const Padding(
                padding: EdgeInsets.fromLTRB(20, 30, 20, 12),
                child: Text(
                  "MANAGEMENT TOOLS", 
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 1.2),
                ),
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
                  subtitle: "View reporting trends and data",
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

  // Confirmation Dialog for Clearing Data
  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear All Issues?"),
        content: const Text("This will permanently delete all reported issues and their comments. This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final instance = FirebaseFirestore.instance;
              final batch = instance.batch();
              var snapshots = await instance.collection('Issues').get();
              for (var doc in snapshots.docs) {
                batch.delete(doc.reference);
              }
              await batch.commit();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Database cleared successfully!")),
                );
              }
            },
            child: const Text("Clear All", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Confirmation Dialog for Seeding
  // Inside your AdminDashboard class...

void _showSeedConfirmation(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false, // Prevent closing during process
    builder: (context) => AlertDialog(
      title: const Text("Seed Database"),
      content: const Text("Inyecting 15 Ethiopian demo issues and comments. This takes a few seconds."),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () async {
            // Close the confirmation dialog
            Navigator.pop(context);

            // Show a progress indicator
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const Center(child: CircularProgressIndicator()),
            );

            try {
              await SeedService().seedIssuesWithComments();
              
              if (context.mounted) {
                Navigator.pop(context); // Close the progress indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Success: All 15 issues seeded!")),
                );
              }
            } catch (e) {
              if (context.mounted) {
                Navigator.pop(context); // Close the progress indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error seeding data: $e")),
                );
              }
            }
          },
          child: const Text("Start Seeding"),
        ),
      ],
    ),
  );
}

  Widget _buildNotificationBadge(BuildContext context) {
    Query notificationQuery = FirebaseFirestore.instance.collection('Notifications')
        .where('sector', isEqualTo: currentUser.assignedSector);
    
    if (currentUser.assignedRegion != null) {
      notificationQuery = notificationQuery.where('region', isEqualTo: currentUser.assignedRegion);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: notificationQuery.snapshots(),
      builder: (context, snapshot) {
        int unreadCount = 0;
        if (snapshot.hasData) {
          unreadCount = snapshot.data!.docs.where((doc) {
            List readBy = doc['readBy'] ?? [];
            return !readBy.contains(currentUser.uid);
          }).length;
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, size: 26),
              onPressed: () => Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => AdminNotificationsScreen(
                  sector: currentUser.assignedSector,
                  region: currentUser.assignedRegion,
                ))
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent, 
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryColor, width: 1.5),
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
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
          child: Container(
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
            ),
            child: CircleAvatar(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
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
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Welcome back,",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            currentUser.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user, color: Colors.white70, size: 14),
                const SizedBox(width: 8),
                Text(
                  currentUser.role == 'super_admin' ? "System Administrator" : "$sector Sector • $region",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ],
            ),
          ),
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
              _statCard("Total", total.toString(), Colors.indigo),
              const SizedBox(width: 10),
              _statCard("Pending", pending.toString(), Colors.orange.shade700),
              const SizedBox(width: 10),
              _statCard("Resolved", resolved.toString(), Colors.green.shade700),
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
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), 
              blurRadius: 10, 
              offset: const Offset(0, 4)
            )
          ],
        ),
        child: Column(
          children: [
            Text(count, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(15), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03), 
            blurRadius: 8, 
            offset: const Offset(0, 2)
          )
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10), 
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1), 
            borderRadius: BorderRadius.circular(12)
          ), 
          child: Icon(icon, color: color, size: 24)
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF263238))),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400),
        onTap: onTap,
      ),
    );
  }
}