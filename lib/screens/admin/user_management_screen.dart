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

  // SRS Constants for Sectors and Regions
  final List<String> _sectors = ["Water", "Electric", "Roads", "Sanitation"];
  final List<String> _regions = ["Addis Ababa", "Oromia", "Amhara", "Sidama"];

  // 1. Confirmation Dialog for Revoking Admin Privileges
  void _confirmRevoke(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Revoke Admin?"),
        content: Text("Are you sure you want to return ${user.name} to a standard user role?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
                  SnackBar(content: Text("Privileges revoked for ${user.name}")),
                );
              }
            },
            child: const Text("Revoke", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 2. Dialog for Promoting or Reassigning Admins
  void _showPromotionDialog(UserModel user) {
    // FIXED: Using assignedSector and assignedRegion from your UserModel
    String selectedRole = (user.role == 'super_admin' || user.role == 'sector_admin') ? user.role : 'sector_admin';
    String selectedSector = _sectors.contains(user.assignedSector) ? user.assignedSector! : _sectors[0];
    String selectedRegion = _regions.contains(user.assignedRegion) ? user.assignedRegion! : _regions[0];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(user.role == 'user' ? "Promote ${user.name}" : "Reassign ${user.name}"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Current Role: ${user.role}"),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: "Target Role", border: OutlineInputBorder()),
                  items: ['user', 'sector_admin', 'super_admin'].map((role) {
                    return DropdownMenuItem(value: role, child: Text(role));
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedRole = val!),
                ),
                if (selectedRole == 'sector_admin') ...[
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: selectedSector,
                    decoration: const InputDecoration(labelText: "Sector", border: OutlineInputBorder()),
                    items: _sectors.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) => setDialogState(() => selectedSector = val!),
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: selectedRegion,
                    decoration: const InputDecoration(labelText: "Region", border: OutlineInputBorder()),
                    items: _regions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (val) => setDialogState(() => selectedRegion = val!),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              onPressed: () async {
                await _authService.promoteUserToAdmin(
                  targetUid: user.uid,
                  role: selectedRole,
                  sector: selectedRole == 'sector_admin' ? selectedSector : null,
                  region: selectedRole == 'sector_admin' ? selectedRegion : null,
                );
                if (mounted) Navigator.pop(context);
              },
              child: Text(user.role == 'user' ? "Promote" : "Update Assignment"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("User Management"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search users by name...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = "");
                      },
                    )
                  : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('Users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final users = snapshot.data!.docs
                    .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                    .where((user) => user.name.toLowerCase().contains(_searchQuery))
                    .toList();

                if (users.isEmpty) {
                  return const Center(child: Text("No users found."));
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final bool isStaff = user.role == 'sector_admin' || user.role == 'super_admin';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isStaff ? Colors.indigo : Colors.grey[400],
                          child: Text(user.name[0], style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        // FIXED: Using user.assignedSector for subtitle
                        subtitle: Text("Role: ${user.role}${user.assignedSector != null ? ' | ${user.assignedSector}' : ''}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(isStaff ? Icons.edit_note : Icons.person_add, color: Colors.indigo),
                              onPressed: () => _showPromotionDialog(user),
                            ),
                            if (isStaff)
                              IconButton(
                                icon: const Icon(Icons.person_remove_outlined, color: Colors.redAccent),
                                onPressed: () => _confirmRevoke(user),
                              ),
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
}