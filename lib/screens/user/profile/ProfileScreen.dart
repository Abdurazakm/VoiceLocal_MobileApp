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
  // NEW: Location Controllers
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile picture updated!")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- RESTORED: Original Bio Update ---
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

  // --- RESTORED: Original Name Update ---
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

  // --- NEW: Location Update ---
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

  @override
  Widget build(BuildContext context) {
    final String effectiveUid = widget.targetUserId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(isMe ? "My Profile" : "User Profile"), centerTitle: true),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('Users').doc(effectiveUid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: CircularProgressIndicator());
          final user = UserModel.fromMap(snapshot.data!.data() as Map<String, dynamic>, effectiveUid);

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildHeader(user),
                const Divider(height: 40),
                _buildSectionHeader("About Me", isMe ? () => _showEditBioSheet(effectiveUid, user.bio) : null),
                _buildBioBox(user.bio),
                const Divider(height: 40),
                _buildSectionHeader("Contributions", null),
                _buildContributions(effectiveUid),
                const Divider(height: 40),
                _buildSectionHeader(isMe ? "My Reports" : "${user.name}'s Reports", null),
                _buildUserIssues(effectiveUid),
                if (isMe) ...[const SizedBox(height: 30), _buildLogoutButton()],
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(UserModel user) {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 55,
              backgroundImage: user.profilePic.isNotEmpty ? NetworkImage(user.profilePic) : null,
              child: user.profilePic.isEmpty && !_isUploading ? const Icon(Icons.person, size: 55) : (_isUploading ? const CircularProgressIndicator() : null),
            ),
            if (isMe)
              Positioned(bottom: 0, right: 0, child: GestureDetector(
                onTap: () => _updateProfilePicture(user.uid),
                child: const CircleAvatar(radius: 18, backgroundColor: Colors.blue, child: Icon(Icons.camera_alt, color: Colors.white, size: 18)),
              )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if (isMe) IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: () => _showEditNameSheet(user.uid, user.name)),
          ],
        ),
        Text(user.email, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 8),
        // Location Badge
        GestureDetector(
          onTap: isMe ? () => _showEditLocationSheet(user.uid, user.region, user.street) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.blue),
                const SizedBox(width: 4),
                Text("${user.region}, ${user.street}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500)),
                if (isMe) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.edit, size: 12, color: Colors.blue)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Rest of your helper methods (_buildSectionHeader, _buildBioBox, _buildContributions, etc.) stay exactly the same...
  Widget _buildSectionHeader(String title, VoidCallback? onEdit) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (onEdit != null) IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: onEdit),
        ],
      ),
    );
  }

  Widget _buildBioBox(String bio) {
    return Container(
      width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 20), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
      child: Text(bio.isEmpty ? (isMe ? "Add a bio to introduce yourself!" : "No bio available.") : bio),
    );
  }

  Widget _buildContributions(String uid) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
      child: FutureBuilder<Map<String, int>>(
        future: _getContributionsData(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data ?? {'votes': 0, 'comments': 0};
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildContributionItem("Votes Received", data['votes']!, Icons.thumb_up),
              _buildContributionItem("Comments", data['comments']!, Icons.comment),
            ],
          );
        },
      ),
    );
  }

  Future<Map<String, int>> _getContributionsData(String uid) async {
    final votes = await _issueService.getTotalVotesReceived(uid);
    final comments = await _issueService.getTotalCommentsMade(uid);
    return {'votes': votes, 'comments': comments};
  }

  Widget _buildContributionItem(String label, int count, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Colors.blue),
        const SizedBox(height: 8),
        Text(count.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildUserIssues(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('Issues').where('createdBy', isEqualTo: uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Text("No issues reported yet."));
        return ListView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: docs.length,
          itemBuilder: (context, i) {
            final issue = Issue.fromFirestore(docs[i]);
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              child: ListTile(
                leading: const Icon(Icons.description_outlined), title: Text(issue.title),
                subtitle: Text("${issue.status} • ${issue.voteCount} Votes"),
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
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50), side: const BorderSide(color: Colors.red), foregroundColor: Colors.red),
        onPressed: () => _auth.logout(), icon: const Icon(Icons.logout), label: const Text("Sign Out"),
      ),
    );
  }
}
