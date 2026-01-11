import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  final List<String> _sectors = ["Water", "Electric", "Roads", "Sanitation"];
  final List<String> _regions = ["Addis Ababa", "Oromia", "Amhara", "Sidama"];

  final Color primaryColor = const Color(0xFF1A237E); // Deep Indigo
  final Color backgroundColor = const Color(0xFFF8F9FE);

  // Logic for Revoking Admin Privileges
  void _confirmRevoke(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Confirm Demotion", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("Revoke administrative privileges from ${user.name}? They will lose access to the management suite."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700, 
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () async {
              await _authService.promoteUserToAdmin(
                targetUid: user.uid,
                role: 'user',
                sector: null,
                region: null,
              );
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("${user.name} access revoked."), behavior: SnackBarBehavior.floating),
                );
              }
            },
            child: const Text("Revoke Access"),
          ),
        ],
      ),
    );
  }

  // Dialog for Reassigning or Promoting Users
  void _showPromotionDialog(UserModel user) {
    String selectedRole = (user.role == 'super_admin' || user.role == 'sector_admin') ? user.role : 'sector_admin';
    String selectedSector = _sectors.contains(user.assignedSector) ? user.assignedSector! : _sectors[0];
    String selectedRegion = _regions.contains(user.assignedRegion) ? user.assignedRegion! : _regions[0];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          title: Row(
            children: [
              Icon(Icons.admin_panel_settings, color: primaryColor),
              const SizedBox(width: 12),
              const Text("Manage Permissions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFieldLabel("System Role"),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: _inputDecoration(),
                  items: ['user', 'sector_admin', 'super_admin'].map((role) {
                    return DropdownMenuItem(
                      value: role, 
                      child: Text(role.replaceAll('_', ' ').toUpperCase(), 
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedRole = val!),
                ),
                if (selectedRole == 'sector_admin') ...[
                  const SizedBox(height: 16),
                  _buildFieldLabel("Department / Sector"),
                  DropdownButtonFormField<String>(
                    initialValue: selectedSector,
                    decoration: _inputDecoration(),
                    items: _sectors.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) => setDialogState(() => selectedSector = val!),
                  ),
                  const SizedBox(height: 16),
                  _buildFieldLabel("Regional Jurisdiction"),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRegion,
                    decoration: _inputDecoration(),
                    items: _regions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (val) => setDialogState(() => selectedRegion = val!),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Discard")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
              onPressed: () async {
                await _authService.promoteUserToAdmin(
                  targetUid: user.uid,
                  role: selectedRole,
                  sector: selectedRole == 'sector_admin' ? selectedSector : null,
                  region: selectedRole == 'sector_admin' ? selectedRegion : null,
                );
                if (mounted) Navigator.pop(context);
              },
              child: const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration() => InputDecoration(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    filled: true,
    fillColor: Colors.grey.shade100,
  );

  Widget _buildFieldLabel(String label) => Container(
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.only(bottom: 6, left: 4),
    child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.blueGrey)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: const Text("User Management", style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Elegant Header with Search Bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search name or email address...",
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('Users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final allUsers = snapshot.data!.docs.map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
                final filteredUsers = allUsers.where((u) => u.name.toLowerCase().contains(_searchQuery) || u.email.toLowerCase().contains(_searchQuery)).toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    final bool isStaff = user.role != 'user';

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: ExpansionTile(
                          shape: const RoundedRectangleBorder(side: BorderSide.none),
                          collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                          backgroundColor: Colors.white,
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: isStaff ? primaryColor.withValues(alpha: 0.1) : Colors.grey.shade100,
                            child: Text(user.name[0].toUpperCase(), style: TextStyle(color: isStaff ? primaryColor : Colors.blueGrey, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          subtitle: Row(
                            children: [
                              _roleBadge(user.role),
                              if (user.assignedSector != null) ...[
                                const SizedBox(width: 6),
                                _sectorBadge(user.assignedSector!),
                              ]
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              child: Column(
                                children: [
                                  const Divider(height: 30),
                                  _infoTile(Icons.alternate_email_rounded, user.email),
                                  _infoTile(Icons.location_on_outlined, "${user.street}, ${user.region}"),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _actionBtn(
                                          "Edit Access", Icons.security_rounded, primaryColor, 
                                          () => _showPromotionDialog(user)
                                        ),
                                      ),
                                      if (isStaff) ...[
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _actionBtn(
                                            "Revoke", Icons.person_remove_rounded, Colors.redAccent, 
                                            () => _confirmRevoke(user)
                                          ),
                                        ),
                                      ],
                                    ],
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleBadge(String role) {
    Color color = role == 'super_admin' ? Colors.deepPurple : (role == 'sector_admin' ? primaryColor : Colors.blueGrey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(role.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  Widget _sectorBadge(String sector) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(sector.toUpperCase(), style: const TextStyle(color: Colors.orange, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  Widget _infoTile(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey.shade300),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}