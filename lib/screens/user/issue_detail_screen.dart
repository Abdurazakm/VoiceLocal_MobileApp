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

  void _navigateToProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(targetUserId: userId),
      ),
    );
  }

  void _showStatusUpdateSheet(String issueId, String currentStatus) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: ['Pending', 'In Progress', 'Resolved'].map((status) {
          return ListTile(
            title: Text(status),
            leading: Icon(
              status == 'Resolved' ? Icons.check_circle : Icons.hourglass_empty,
              color: status == currentStatus ? Colors.blue : Colors.grey,
            ),
            onTap: () async {
              await FirebaseFirestore.instance
                  .collection('Issues')
                  .doc(issueId)
                  .update({'status': status});
              if (mounted) Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMedia(String? url) {
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    bool isVideo = url.contains(".mp4") || url.contains("video/upload");

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[200],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: isVideo
            ? Container(
                height: 200,
                color: Colors.black87,
                child: const Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 50,
                ),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  height: 100,
                  child: Icon(Icons.broken_image),
                ),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Edit Issue",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            TextField(
              controller: tEdit,
              decoration: const InputDecoration(labelText: "Title"),
            ),
            TextField(
              controller: dEdit,
              decoration: const InputDecoration(labelText: "Description"),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
              ),
              onPressed: () async {
                if (tEdit.text.isEmpty) return;
                await _issueService.updateIssue(
                  currentIssue.id,
                  tEdit.text,
                  dEdit.text,
                );
                if (mounted) Navigator.pop(context);
              },
              child: const Text("Update Issue"),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteIssue(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Report?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await _issueService.deleteIssue(id);
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
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

  void _handleEditComment(Comment comment) {
    _commentController.text = comment.text;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _commentController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: "Edit your comment...",
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                await _issueService.updateComment(
                  comment.id,
                  _commentController.text,
                );
                _commentController.clear();
                if (mounted) Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showReplySheet({String? pId, String? rName}) {
    _commentController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              rName != null ? "Replying to @$rName" : "New Comment",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _commentController,
              autofocus: true,
              decoration: const InputDecoration(hintText: "Type something..."),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
              ),
              onPressed: () async {
                if (_commentController.text.isEmpty) return;
                await _issueService.postComment(
                  widget.issue.id,
                  _commentController.text,
                  parentId: pId,
                  replyToName: rName,
                );
                _commentController.clear();
                if (mounted) Navigator.pop(context);
              },
              child: const Text("Post"),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Issues')
          .doc(widget.issue.id)
          .snapshots(),
      builder: (context, snapshot) {
        Issue currentIssue = snapshot.hasData && snapshot.data!.exists
            ? Issue.fromFirestore(snapshot.data!)
            : widget.issue;

        return Scaffold(
          appBar: AppBar(
            title: const Text("Issue Detail"),
            actions: [
              if (currentIssue.createdBy == uid) ...[
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.orange),
                  onPressed: () => _showEditIssueSheet(currentIssue),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDeleteIssue(currentIssue.id),
                ),
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
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Chip(
                                  label: Text(
                                    currentIssue.category,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  backgroundColor: Colors.blueAccent,
                                  visualDensity: VisualDensity.compact,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: currentIssue.status == 'Resolved'
                                        ? Colors.green[100]
                                        : Colors.orange[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    currentIssue.status,
                                    style: TextStyle(
                                      color: currentIssue.status == 'Resolved'
                                          ? Colors.green[800]
                                          : Colors.orange[800],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                _buildInfoBadge(Icons.location_on, currentIssue.region, Colors.redAccent),
                                _buildInfoBadge(Icons.add_road, currentIssue.street, Colors.blueGrey),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildAuthorAndAdminSection(currentIssue, uid),
                            const SizedBox(height: 12),
                            Text(
                              currentIssue.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currentIssue.description,
                              style: const TextStyle(fontSize: 16),
                            ),
                            _buildMedia(currentIssue.attachmentUrl),
                            const SizedBox(height: 16),
                            _buildVoteSection(currentIssue, uid),
                          ],
                        ),
                      ),
                      const Divider(),
                      _buildCommentsList(currentIssue, uid),
                    ],
                  ),
                ),
              ),
              _buildAddCommentButton(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoBadge(IconData icon, String label, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildAuthorAndAdminSection(Issue currentIssue, String uid) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('Users').doc(currentIssue.createdBy).snapshots(),
      builder: (context, userSnap) {
        String authorName = "Loading...";
        String? authorPic;
        if (userSnap.hasData && userSnap.data!.exists) {
          final data = userSnap.data!.data() as Map<String, dynamic>;
          authorName = data['name'] ?? "User";
          authorPic = data['profilePic'];
        }

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('Users').doc(uid).get(),
          builder: (context, currentRoleSnap) {
            bool isCurrentUserAdmin = false;
            if (currentRoleSnap.hasData && currentRoleSnap.data!.exists) {
              isCurrentUserAdmin = (currentRoleSnap.data!.data() as Map<String, dynamic>)['role'] == 'admin';
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => _navigateToProfile(currentIssue.createdBy),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundImage: (authorPic != null && authorPic.isNotEmpty) ? NetworkImage(authorPic) : null,
                        child: (authorPic == null || authorPic.isEmpty) ? const Icon(Icons.person, size: 20) : null,
                      ),
                      const SizedBox(width: 10),
                      Text(authorName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                ),
                if (isCurrentUserAdmin)
                  TextButton.icon(
                    onPressed: () => _showStatusUpdateSheet(currentIssue.id, currentIssue.status),
                    icon: const Icon(Icons.settings, size: 16),
                    label: const Text("Manage Status", style: TextStyle(fontSize: 12)),
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
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: () => _issueService.voteForIssue(currentIssue.id),
          icon: Icon(hasVoted ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined, size: 18),
          label: Text(hasVoted ? "Voted" : "Vote"),
          style: ElevatedButton.styleFrom(
            backgroundColor: hasVoted ? Colors.blue : Colors.blue.shade50,
            foregroundColor: hasVoted ? Colors.white : Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            "${currentIssue.voteCount} community members voted",
            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentsList(Issue currentIssue, String uid) {
    return StreamBuilder<List<Comment>>(
      stream: _issueService.getComments(currentIssue.id),
      builder: (context, commentSnapshot) {
        final allComments = commentSnapshot.data ?? [];
        final parentComments = allComments.where((c) => c.parentId == null).toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: parentComments.length,
          itemBuilder: (context, index) {
            final parent = parentComments[index];
            final replies = allComments.where((c) => c.parentId == parent.id).toList();
            bool isOwner = parent.userId == uid;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: _buildCommentAvatar(parent.userId),
                  title: GestureDetector(
                    onTap: () => _navigateToProfile(parent.userId),
                    child: Text(parent.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                  ),
                  subtitle: _buildCommentBody(parent, allComments),
                  trailing: _buildCommentActions(parent, isOwner, currentIssue.id),
                ),
                if (_visibleReplies.contains(parent.id) && replies.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 32.0),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: Colors.grey.shade300, width: 2)),
                      ),
                      child: Column(
                        children: replies.map((reply) {
                          bool isReplyOwner = reply.userId == uid;
                          return ListTile(
                            dense: true,
                            leading: _buildCommentAvatar(reply.userId),
                            title: Text(reply.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (reply.replyToName != null)
                                  Text("@${reply.replyToName}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11)),
                                Text(reply.text),
                              ],
                            ),
                            // FIX: Passing the parent.id as rootId so replies to replies stay in this thread
                            trailing: _buildCommentActions(reply, isReplyOwner, currentIssue.id, rootId: parent.id),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                const Divider(indent: 16, endIndent: 16, height: 1),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCommentAvatar(String userId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('Users').doc(userId).snapshots(),
      builder: (context, snap) {
        String? pic;
        if (snap.hasData && snap.data!.exists) {
          pic = (snap.data!.data() as Map<String, dynamic>)['profilePic'];
        }
        return GestureDetector(
          onTap: () => _navigateToProfile(userId),
          child: CircleAvatar(
            radius: 16,
            backgroundImage: (pic != null && pic.isNotEmpty) ? NetworkImage(pic) : null,
            child: (pic == null || pic.isEmpty) ? const Icon(Icons.person, size: 16) : null,
          ),
        );
      },
    );
  }

  Widget _buildCommentBody(Comment c, List<Comment> allComments) {
    bool hasReplies = allComments.any((reply) => reply.parentId == c.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (c.replyToName != null && c.parentId == null) // In case of single level
          Text("@${c.replyToName}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
        Text(c.text),
        if (c.parentId == null && hasReplies)
          TextButton(
            onPressed: () {
              setState(() {
                _visibleReplies.contains(c.id) ? _visibleReplies.remove(c.id) : _visibleReplies.add(c.id);
              });
            },
            child: Text(_visibleReplies.contains(c.id) ? "Hide Replies" : "Show Replies", style: const TextStyle(fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildCommentActions(Comment c, bool isOwner, String issueId, {String? rootId}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.reply, size: 18),
          // Uses rootId if provided, otherwise the comment's own id
          onPressed: () => _showReplySheet(pId: rootId ?? c.id, rName: c.userName),
        ),
        if (isOwner) ...[
          IconButton(icon: const Icon(Icons.edit, size: 18, color: Colors.orange), onPressed: () => _handleEditComment(c)),
          IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _confirmDeleteComment(c.id, issueId)),
        ],
      ],
    );
  }

  Widget _buildAddCommentButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => _showReplySheet(),
        child: const Text("Add Comment"),
      ),
    );
  }
}
