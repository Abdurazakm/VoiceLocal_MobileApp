import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/issue_model.dart';
import '../../models/comment_model.dart';
import '../../services/issue_service.dart';
import 'profile/ProfileScreen.dart';

class IssueDetailScreen extends StatefulWidget {
  final Issue issue;
  const IssueDetailScreen({super.key, required this.issue});

  @override
  State<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final IssueService _issueService = IssueService();
  final Set<String> _visibleReplies = {};

  // Theme Colors
  final Color primaryColor = const Color(0xFF1A237E); // Deep Indigo
  final Color accentColor = const Color(0xFF3949AB);

  void _navigateToProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(targetUserId: userId),
      ),
    );
  }

  // --- SAFE DATA RETRIEVAL HELPER ---
  String? _getProfilePic(DocumentSnapshot snap) {
    if (!snap.exists) return null;
    final data = snap.data() as Map<String, dynamic>?;
    if (data != null && data.containsKey('profilePic')) {
      return data['profilePic'] as String?;
    }
    return null;
  }

  // --- ACTIONS & DIALOGS ---

  void _confirmDeleteIssue(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Report?"),
        content: const Text("This will permanently remove this issue report. This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await _issueService.deleteIssue(id);
              if (mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to previous screen
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteComment(String commentId, String issueId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Comment?"),
        content: const Text("Are you sure you want to remove this comment?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await _issueService.deleteComment(commentId, issueId);
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showStatusUpdateSheet(String issueId, String currentStatus) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Update Resolution Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 15),
            ...['Pending', 'In Progress', 'Resolved'].map((status) {
              bool isSelected = status == currentStatus;
              return ListTile(
                leading: Icon(
                  status == 'Resolved' ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                  color: isSelected ? primaryColor : Colors.grey,
                ),
                title: Text(status, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? primaryColor : Colors.black87)),
                trailing: isSelected ? Icon(Icons.check, color: primaryColor) : null,
                onTap: () async {
                  await FirebaseFirestore.instance.collection('Issues').doc(issueId).update({'status': status});
                  if (mounted) Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showEditIssueSheet(Issue currentIssue) {
    final tEdit = TextEditingController(text: currentIssue.title);
    final dEdit = TextEditingController(text: currentIssue.description);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Edit Issue Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 15),
            TextField(controller: tEdit, decoration: InputDecoration(labelText: "Title", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 12),
            TextField(controller: dEdit, maxLines: 4, decoration: InputDecoration(labelText: "Description", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                if (tEdit.text.isEmpty) return;
                await _issueService.updateIssue(currentIssue.id, tEdit.text, dEdit.text);
                if (mounted) Navigator.pop(context);
              },
              child: const Text("Save Changes"),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildStatusChip(String status) {
    Color color = status == 'Resolved' ? Colors.green : (status == 'In Progress' ? Colors.orange : Colors.blueGrey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  Widget _buildMedia(String? url) {
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    bool isVideo = url.contains(".mp4") || url.contains("video/upload");
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      width: double.infinity,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: isVideo
            ? Container(height: 220, color: Colors.black, child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 64))
            : Image.network(url, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(height: 150, color: Colors.grey[200], child: const Icon(Icons.broken_image))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('Issues').doc(widget.issue.id).snapshots(),
      builder: (context, snapshot) {
        Issue currentIssue = snapshot.hasData && snapshot.data!.exists ? Issue.fromFirestore(snapshot.data!) : widget.issue;

        return Scaffold(
          key: ValueKey(currentIssue.id),
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Text("Issue Details", style: TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              if (currentIssue.createdBy == uid) ...[
                IconButton(icon: const Icon(Icons.edit_note_rounded), onPressed: () => _showEditIssueSheet(currentIssue)),
                IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent), onPressed: () => _confirmDeleteIssue(currentIssue.id)),
              ],
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: primaryColor, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStatusChip(currentIssue.status),
                                Text(currentIssue.category.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(currentIssue.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 12),
                            Row(children: [
                              const Icon(Icons.location_on, color: Colors.white60, size: 16),
                              const SizedBox(width: 4),
                              Expanded(child: Text("${currentIssue.street}, ${currentIssue.region}", style: const TextStyle(color: Colors.white70, fontSize: 14))),
                            ]),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAuthorRow(currentIssue, uid),
                            const SizedBox(height: 20),
                            Text(currentIssue.description, style: const TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF263238))),
                            _buildMedia(currentIssue.attachmentUrl),
                            const Divider(height: 40),
                            _buildVoteSection(currentIssue, uid),
                            const SizedBox(height: 30),
                            const Text("Community Discussion", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                      _buildCommentsList(currentIssue, uid),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          floatingActionButton: _buildAddCommentButton(),
        );
      },
    );
  }

  Widget _buildAuthorRow(Issue currentIssue, String uid) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('Users').doc(currentIssue.createdBy).snapshots(),
      builder: (context, userSnap) {
        String name = "User";
        String? pic;
        if (userSnap.hasData && userSnap.data!.exists) {
          final userData = userSnap.data!.data() as Map<String, dynamic>?;
          name = userData?['name'] ?? "User";
          pic = _getProfilePic(userSnap.data!);
        }

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('Users').doc(uid).get(),
          builder: (context, roleSnap) {
            bool isAdmin = false;
            if (roleSnap.hasData && roleSnap.data!.exists) {
              final roleData = roleSnap.data!.data() as Map<String, dynamic>?;
              isAdmin = ['admin', 'super_admin', 'sector_admin'].contains(roleData?['role']);
            }
            return Row(
              children: [
                GestureDetector(
                  onTap: () => _navigateToProfile(currentIssue.createdBy),
                  child: CircleAvatar(radius: 20, backgroundImage: (pic != null && pic.isNotEmpty) ? NetworkImage(pic) : null, child: pic == null ? const Icon(Icons.person) : null),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const Text("Reporter", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ]),
                ),
                if (isAdmin)
                  TextButton.icon(
                    onPressed: () => _showStatusUpdateSheet(currentIssue.id, currentIssue.status),
                    icon: const Icon(Icons.settings_suggest_rounded, size: 20),
                    label: const Text("Manage"),
                    style: TextButton.styleFrom(foregroundColor: accentColor),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildVoteSection(Issue currentIssue, String uid) {
    bool hasVoted = currentIssue.votedUids.contains(uid);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _issueService.voteForIssue(currentIssue.id),
            icon: Icon(hasVoted ? Icons.thumb_up_rounded : Icons.thumb_up_outlined),
            style: IconButton.styleFrom(
              backgroundColor: hasVoted ? primaryColor : Colors.white,
              foregroundColor: hasVoted ? Colors.white : primaryColor,
              side: BorderSide(color: primaryColor.withOpacity(0.2)),
            ),
          ),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("${currentIssue.voteCount} Community Votes", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const Text("High votes increase fix priority", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        ],
      ),
    );
  }

  Widget _buildCommentsList(Issue currentIssue, String uid) {
    return StreamBuilder<List<Comment>>(
      stream: _issueService.getComments(currentIssue.id),
      builder: (context, snapshot) {
        final allComments = snapshot.data ?? [];
        final parents = allComments.where((c) => c.parentId == null).toList();
        if (parents.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Text("No comments yet.", style: TextStyle(color: Colors.grey))));

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: parents.length,
          itemBuilder: (context, index) {
            final parent = parents[index];
            final replies = allComments.where((c) => c.parentId == parent.id).toList();
            return _buildCommentThread(parent, replies, uid, currentIssue.id);
          },
        );
      },
    );
  }

  Widget _buildCommentThread(Comment parent, List<Comment> replies, String uid, String issueId) {
    return Column(
      children: [
        ListTile(
          leading: _buildCommentAvatar(parent.userId),
          title: Text(parent.userName, style: TextStyle(fontWeight: FontWeight.bold, color: accentColor, fontSize: 14)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(parent.text, style: const TextStyle(color: Colors.black87)),
            if (replies.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _visibleReplies.contains(parent.id) ? _visibleReplies.remove(parent.id) : _visibleReplies.add(parent.id)),
                child: Text(_visibleReplies.contains(parent.id) ? "Hide Replies" : "Show ${replies.length} Replies", style: const TextStyle(fontSize: 12)),
              ),
          ]),
          trailing: _buildCommentActions(parent, parent.userId == uid, issueId),
        ),
        if (_visibleReplies.contains(parent.id))
          Padding(
            padding: const EdgeInsets.only(left: 45),
            child: Column(
              children: replies.map((r) => ListTile(
                dense: true,
                leading: _buildCommentAvatar(r.userId, small: true),
                title: Text(r.userName, style: TextStyle(fontWeight: FontWeight.bold, color: accentColor, fontSize: 13)),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (r.replyToName != null) Text("@${r.replyToName}", style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 11)),
                  Text(r.text),
                ]),
                trailing: _buildCommentActions(r, r.userId == uid, issueId, rootId: parent.id),
              )).toList(),
            ),
          ),
        const Divider(indent: 70, height: 1),
      ],
    );
  }

  Widget _buildCommentAvatar(String userId, {bool small = false}) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('Users').doc(userId).snapshots(),
      builder: (context, snap) {
        String? pic = snap.hasData ? _getProfilePic(snap.data!) : null;
        return CircleAvatar(radius: small ? 12 : 16, backgroundImage: (pic != null && pic.isNotEmpty) ? NetworkImage(pic) : null, child: pic == null ? Icon(Icons.person, size: small ? 14 : 18) : null);
      },
    );
  }

  Widget _buildCommentActions(Comment c, bool isOwner, String issueId, {String? rootId}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(icon: const Icon(Icons.reply_rounded, size: 18), onPressed: () => _showReplySheet(pId: rootId ?? c.id, rName: c.userName)),
        if (isOwner)
          IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent), onPressed: () => _confirmDeleteComment(c.id, issueId)),
      ],
    );
  }

  Widget _buildAddCommentButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 5),
        onPressed: () => _showReplySheet(),
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text("Add a Comment", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showReplySheet({String? pId, String? rName}) {
    _commentController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(rName != null ? "Replying to @$rName" : "Write a comment", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(controller: _commentController, autofocus: true, decoration: const InputDecoration(hintText: "Type something helpful...")),
            const SizedBox(height: 15),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 45)),
              onPressed: () async {
                if (_commentController.text.isEmpty) return;
                await _issueService.postComment(widget.issue.id, _commentController.text, parentId: pId, replyToName: rName);
                if (mounted) Navigator.pop(context);
              },
              child: const Text("Post"),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
