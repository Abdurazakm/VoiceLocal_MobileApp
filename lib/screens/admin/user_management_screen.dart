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

  // SRS Constants for Sectors and Regions
  final List<String> _sectors = ["Water", "Electric", "Roads", "Sanitation"];
  final List<String> _regions = ["Addis Ababa", "Oromia", "Amhara", "Sidama"];

  void _showPromotionDialog(UserModel user) {
    String selectedRole = 'sector_admin';
    String selectedSector = _sectors[0];
    String selectedRegion = _regions[0];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Promote ${user.name}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Assign administrative privileges and jurisdiction."),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: "Role"),
                items: ['sector_admin', 'super_admin'].map((role) {
                  return DropdownMenuItem(value: role, child: Text(role));
                }).toList(),
                onChanged: (val) => setDialogState(() => selectedRole = val!),
              ),
              if (selectedRole == 'sector_admin') ...[
                DropdownButtonFormField<String>(
                  value: selectedSector,
                  decoration: const InputDecoration(labelText: "Sector"),
                  items: _sectors.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) => setDialogState(() => selectedSector = val!),
                ),
                DropdownButtonFormField<String>(
                  value: selectedRegion,
                  decoration: const InputDecoration(labelText: "Region"),
                  items: _regions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (val) => setDialogState(() => selectedRegion = val!),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                await _authService.promoteUserToAdmin(
                  targetUid: user.uid,
                  role: selectedRole,
                  sector: selectedRole == 'sector_admin' ? selectedSector : null,
                  region: selectedRole == 'sector_admin' ? selectedRegion : null,
                );
                if (mounted) Navigator.pop(context);
              },
              child: const Text("Promote"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("User Management")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final users = snapshot.data!.docs.map((doc) => 
            UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(child: Text(user.name[0])),
                  title: Text(user.name),
                  subtitle: Text("Role: ${user.role} | ${user.region}"),
                  trailing: user.role == 'user' 
                    ? IconButton(
                        icon: const Icon(Icons.person_add, color: Colors.indigo),
                        onPressed: () => _showPromotionDialog(user),
                      )
                    : const Icon(Icons.verified, color: Colors.green),
                ),
              );
            },
          );
        },
      ),
    );
  }
}