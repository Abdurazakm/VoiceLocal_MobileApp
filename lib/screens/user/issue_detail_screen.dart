import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  
  void _showEditIssueSheet() {
    final tEdit = TextEditingController(text: widget.issue.title);
    final dEdit = TextEditingController(text: widget.issue.description);

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
                await _issueService.updateIssue(widget.issue.id, tEdit.text, dEdit.text);
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

  void _confirmDeleteIssue() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Report?"),
        content: const Text("This will permanently remove this issue and all its data."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await _issueService.deleteIssue(widget.issue.id);
              if (mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Exit detail screen
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- COMMENT EDIT/DELETE LOGIC ---

  void _confirmDeleteComment(String commentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Comment?"),
        content: const Text("Are you sure you want to remove this comment?"),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("Issue Detail"),
        actions: [
          if (widget.issue.createdBy == uid) ...[
            IconButton(icon: const Icon(Icons.edit, color: Colors.orange), onPressed: _showEditIssueSheet),
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _confirmDeleteIssue),
          ]
        ],
      ),
      body: Column(
        children: [
          ListTile(
            title: Text(widget.issue.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            subtitle: Text(widget.issue.description),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<List<Comment>>(
              stream: _issueService.getComments(widget.issue.id),
              builder: (context, snapshot) {
                final comments = snapshot.data ?? [];
                return ScrollablePositionedList.builder(
                  itemScrollController: _itemScrollController,
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
                              GestureDetector(
                                onTap: () => _jumpToParent(c.parentId!, comments),
                                child: Text("@${c.replyToName}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                              ),
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
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () => _showReplySheet(), 
              child: const Text("Add Comment")
            ),
          )
        ],
      ),
    );
  }
}