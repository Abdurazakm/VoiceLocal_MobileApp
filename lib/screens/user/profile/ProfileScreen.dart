import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import '../../../../models/user_model.dart';
import '../../../../models/issue_model.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/issue_service.dart';
import '../issue_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? targetUserId;
  const ProfileScreen({super.key, this.targetUserId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();

  final AuthService _auth = AuthService();
  final IssueService _issueService = IssueService();
  bool _isUploading = false;

  final cloudinary = CloudinaryPublic(
    'dqokyquo6',
    'voicelocal_preset',
    cache: false,
  );

  bool get isMe =>
      widget.targetUserId == null ||
      widget.targetUserId == FirebaseAuth.instance.currentUser?.uid;

  // --- LOGOUT LOGIC ---
  Future<void> _handleLogout() async {
  final bool? confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Text("Sign Out"),
      content: const Text("Are you sure you want to log out?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text("SIGN OUT", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );

  if (confirm == true) {
    // 1. Close the dialog
    // No need to do anything else. When the line below finishes, 
    // the StreamBuilder in AuthGate (main.dart) will automatically 
    // kick the user back to the LoginScreen.
    await _auth.logout(); 
  }
}
  // --- UPDATE METHODS ---
  Future<void> _updateProfilePicture(String uid) async {
    if (!isMe) return;
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile == null) return;

    setState(() => _isUploading = true);
    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(pickedFile.path, resourceType: CloudinaryResourceType.Image, folder: 'voicelocal_profiles'),
      );
      await FirebaseFirestore.instance.collection('Users').doc(uid).update({'profilePic': response.secureUrl});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _updateBio(String uid, String newBio) async {
    try {
      await _auth.updateUserProfile(uid, bio: newBio);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bio updated!")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _updateName(String uid, String newName) async {
    try {
      await _auth.updateUserProfile(uid, name: newName);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Name updated!")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _updateLocation(String uid, String region, String street) async {
    try {
      await _auth.updateUserProfile(uid, region: region, street: street);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location updated!")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // --- UI MODALS ---
  void _showEditLocationSheet(String uid, String currentRegion, String currentStreet) {
    _regionController.text = currentRegion;
    _streetController.text = currentStreet;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Edit Location", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(controller: _regionController, decoration: const InputDecoration(labelText: "Region", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _streetController, decoration: const InputDecoration(labelText: "Street", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () => _updateLocation(uid, _regionController.text.trim(), _streetController.text.trim()),
              child: const Text("Save"),
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showEditBioSheet(String uid, String currentBio) {
    _bioController.text = currentBio;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Edit Bio", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(controller: _bioController, maxLines: 3, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "About you...")),
            const SizedBox(height: 15),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => _updateBio(uid, _bioController.text.trim()), child: const Text("Save"))),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showEditNameSheet(String uid, String currentName) {
    _nameController.text = currentName;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Edit Name", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(controller: _nameController, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Your name...")),
            const SizedBox(height: 15),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => _updateName(uid, _nameController.text.trim()), child: const Text("Save"))),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- BUILDER ---
  @override
  Widget build(BuildContext context) {
    final String effectiveUid = widget.targetUserId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text(isMe ? "My Account" : "Profile", style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('Users').doc(effectiveUid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: CircularProgressIndicator());
          final user = UserModel.fromMap(snapshot.data!.data() as Map<String, dynamic>, effectiveUid);

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildHeaderCard(user),
                _buildSectionLabel("PERSONAL INFO"),
                _buildInfoCard(user),
                _buildSectionLabel("STATS"),
                _buildContributions(effectiveUid),
                _buildSectionLabel(isMe ? "MY ACTIVITY" : "RECENT REPORTS"),
                _buildUserIssues(effectiveUid),
                if (isMe) ...[
                  const SizedBox(height: 30),
                  _buildLogoutButton(),
                ],
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(UserModel user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 25),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.blue.shade100, width: 3)),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: user.profilePic.isNotEmpty ? NetworkImage(user.profilePic) : null,
                  child: user.profilePic.isEmpty && !_isUploading ? const Icon(Icons.person, size: 50, color: Colors.grey) : (_isUploading ? const CircularProgressIndicator() : null),
                ),
              ),
              if (isMe)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => _updateProfilePicture(user.uid),
                    child: const CircleAvatar(radius: 16, backgroundColor: Colors.blue, child: Icon(Icons.camera_alt, color: Colors.white, size: 16)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              if (isMe) IconButton(icon: const Icon(Icons.edit, size: 16, color: Colors.blue), onPressed: () => _showEditNameSheet(user.uid, user.name)),
            ],
          ),
          Text(user.email, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildInfoCard(UserModel user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          _buildListTile(
            icon: Icons.notes_rounded,
            title: "About",
            subtitle: user.bio.isEmpty ? "No bio added yet" : user.bio,
            onTap: isMe ? () => _showEditBioSheet(user.uid, user.bio) : null,
          ),
          const Divider(height: 1, indent: 55),
          _buildListTile(
            icon: Icons.location_on_rounded,
            title: "Location",
            subtitle: "${user.region}, ${user.street}",
            onTap: isMe ? () => _showEditLocationSheet(user.uid, user.region, user.street) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildListTile({required IconData icon, required String title, required String subtitle, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue[700]),
      title: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 15, color: Colors.black87)),
      trailing: onTap != null ? const Icon(Icons.chevron_right, size: 18) : null,
      onTap: onTap,
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.1)),
      ),
    );
  }

  Widget _buildContributions(String uid) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.shade900, Colors.blue.shade600]),
        borderRadius: BorderRadius.circular(15),
      ),
      child: FutureBuilder<Map<String, int>>(
        future: _getContributionsData(uid),
        builder: (context, snapshot) {
          final data = snapshot.data ?? {'votes': 0, 'comments': 0};
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatBox("Votes Received", data['votes']!.toString()),
              Container(width: 1, height: 30, color: Colors.white24),
              _buildStatBox("Comments", data['comments']!.toString()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatBox(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Future<Map<String, int>> _getContributionsData(String uid) async {
    final votes = await _issueService.getTotalVotesReceived(uid);
    final comments = await _issueService.getTotalCommentsMade(uid);
    return {'votes': votes, 'comments': comments};
  }

  Widget _buildUserIssues(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('Issues').where('createdBy', isEqualTo: uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Text("No issues found."));

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final issue = Issue.fromFirestore(docs[i]);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: Colors.blue.withOpacity(0.1), child: const Icon(Icons.description, color: Colors.blue, size: 20)),
                title: Text(issue.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(issue.status, style: TextStyle(color: issue.status == 'Resolved' ? Colors.green : Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => IssueDetailScreen(issue: issue))),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextButton.icon(
        style: TextButton.styleFrom(
          minimumSize: const Size(double.infinity, 55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.red)),
          foregroundColor: Colors.red,
        ),
        onPressed: _handleLogout,
        icon: const Icon(Icons.logout_rounded),
        label: const Text("Sign Out", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
