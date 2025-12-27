import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Required for live stream
import '../../models/issue_model.dart';
import '../../models/comment_model.dart';
import '../../services/issue_service.dart';

class IssueDetailScreen extends StatefulWidget {
  final Issue issue;
  const IssueDetailScreen({super.key, required this.issue});

  @override
  State<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final TextEditingController _commentController = TextEditingController();
  final IssueService _issueService = IssueService();

  // Helper to build the image display
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
                child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 50)
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => 
                  const SizedBox(height: 100, child: Icon(Icons.broken_image)),
              ),
      ),
    );
  }

  void _jumpToParent(String parentId, List<Comment> allComments) {
    int index = allComments.indexWhere((c) => c.id == parentId);
    if (index != -1) {
      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  // --- ISSUE EDIT/DELETE LOGIC ---
  
  void _showEditIssueSheet(Issue currentIssue) {
    final tEdit = TextEditingController(text: currentIssue.title);
    final dEdit = TextEditingController(text: currentIssue.description);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16, right: 16, top: 16
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Edit Issue", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            TextField(controller: tEdit, decoration: const InputDecoration(labelText: "Title")),
            TextField(controller: dEdit, decoration: const InputDecoration(labelText: "Description"), maxLines: 3),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                if (tEdit.text.isEmpty) return;
                await _issueService.updateIssue(currentIssue.id, tEdit.text, dEdit.text);
                if (mounted) Navigator.pop(context);
              }, 
              child: const Text("Update Issue")
            ),
            const SizedBox(height: 10),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
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

  // --- COMMENT LOGIC ---

  void _confirmDeleteComment(String commentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Comment?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await _issueService.deleteComment(commentId);
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
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _commentController, autofocus: true),
            ElevatedButton(
              onPressed: () async {
                await _issueService.updateComment(comment.id, _commentController.text);
                _commentController.clear();
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
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
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(rName != null ? "Replying to @$rName" : "New Comment"),
            TextField(controller: _commentController, autofocus: true),
            ElevatedButton(
              onPressed: () async {
                if (_commentController.text.isEmpty) return;
                await _issueService.postComment(widget.issue.id, _commentController.text, parentId: pId, replyToName: rName);
                _commentController.clear();
                Navigator.pop(context);
              },
              child: const Text("Post"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    // FIX: Wrapping everything in a StreamBuilder for live data
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('Issues').doc(widget.issue.id).snapshots(),
      builder: (context, snapshot) {
        // Fallback to widget.issue if stream is loading or empty
        Issue currentIssue = snapshot.hasData && snapshot.data!.exists 
            ? Issue.fromFirestore(snapshot.data!) 
            : widget.issue;

        return Scaffold(
          appBar: AppBar(
            title: const Text("Issue Detail"),
            actions: [
              if (currentIssue.createdBy == uid) ...[
                IconButton(icon: const Icon(Icons.edit, color: Colors.orange), onPressed: () => _showEditIssueSheet(currentIssue)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDeleteIssue(currentIssue.id)),
              ]
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView( // Allow scrolling when image is large
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(currentIssue.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                            const SizedBox(height: 8),
                            Text(currentIssue.description, style: const TextStyle(fontSize: 16)),
                            
                            // FIX: Added Media Section
                            _buildMedia(currentIssue.attachmentUrl),

                            const SizedBox(height: 16),
                            
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _issueService.voteForIssue(currentIssue.id),
                                  icon: Icon(
                                    currentIssue.votedUids.contains(uid) 
                                        ? Icons.thumb_up_alt 
                                        : Icons.thumb_up_alt_outlined, 
                                    size: 18
                                  ),
                                  label: Text(currentIssue.votedUids.contains(uid) ? "Voted" : "Vote"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: currentIssue.votedUids.contains(uid) 
                                        ? Colors.blue 
                                        : Colors.blue.shade50, 
                                    foregroundColor: currentIssue.votedUids.contains(uid) 
                                        ? Colors.white 
                                        : Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "${currentIssue.voteCount} community members voted", 
                                  style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      
                      // COMMENTS LIST (Already handles its own stream)
                      StreamBuilder<List<Comment>>(
                        stream: _issueService.getComments(currentIssue.id),
                        builder: (context, commentSnapshot) {
                          final comments = commentSnapshot.data ?? [];
                          return ListView.builder( // Switched to ListView inside ScrollView for better layout
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: comments.length,
                            itemBuilder: (context, index) {
                              final c = comments[index];
                              bool isReply = c.parentId != null;
                              bool isOwner = c.userId == uid;

                              return Padding(
                                padding: EdgeInsets.only(left: isReply ? 32 : 0),
                                child: ListTile(
                                  title: Text(c.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (c.replyToName != null)
                                        Text("@${c.replyToName}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                                      Text(c.text),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(icon: const Icon(Icons.reply, size: 18), onPressed: () => _showReplySheet(pId: c.id, rName: c.userName)),
                                      if (isOwner) ...[
                                        IconButton(icon: const Icon(Icons.edit, size: 18, color: Colors.orange), onPressed: () => _handleEditComment(c)),
                                        IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _confirmDeleteComment(c.id)),
                                      ]
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
                  onPressed: () => _showReplySheet(), 
                  child: const Text("Add Comment")
                ),
              )
            ],
          ),
        );
      },
    );
  }
}