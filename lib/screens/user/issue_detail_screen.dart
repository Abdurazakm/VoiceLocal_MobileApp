import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
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

  // Redirect Logic: Finds the parent comment and scrolls to it
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

  void _showReplySheet({String? pId, String? rName}) {
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
            Text(rName != null ? "Replying to @$rName" : "Write a comment"),
            TextField(
              controller: _commentController, 
              autofocus: true, 
              decoration: const InputDecoration(hintText: "Type here...")
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                if (_commentController.text.isEmpty) return;
                await _issueService.postComment(
                  widget.issue.id,
                  _commentController.text,
                  parentId: pId,
                  replyToName: rName,
                );
                _commentController.clear();
                Navigator.pop(context);
              },
              child: const Text("Post"),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.issue.title)),
      body: Column(
        children: [
          // Issue Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.issue.description, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 10),
                Text("Status: ${widget.issue.status}", style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const Divider(),
          
          // Comments Section
          Expanded(
            child: StreamBuilder<List<Comment>>(
              stream: _issueService.getComments(widget.issue.id),
              builder: (context, snapshot) {
                // 1. Handle Errors (Crucial for detecting missing Firestore Indexes)
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text("Error: ${snapshot.error}", textAlign: TextAlign.center),
                    ),
                  );
                }

                // 2. Loading State
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final comments = snapshot.data ?? [];

                // 3. Empty State
                if (comments.isEmpty) {
                  return const Center(child: Text("No comments yet. Start the conversation!"));
                }

                // 4. Data List
                return ScrollablePositionedList.builder(
                  itemScrollController: _itemScrollController,
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    bool isReply = comment.parentId != null;

                    return Container(
                      margin: EdgeInsets.only(left: isReply ? 40 : 0),
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: isReply ? Colors.grey.shade300 : Colors.transparent, width: 2))
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: isReply ? 15 : 20,
                          child: Text(comment.userName[0].toUpperCase()),
                        ),
                        title: Text(comment.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (comment.replyToName != null)
                              GestureDetector(
                                onTap: () => _jumpToParent(comment.parentId!, comments),
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: Text(
                                    "@${comment.replyToName}",
                                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ),
                            Text(comment.text, style: const TextStyle(fontSize: 15)),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.reply, size: 18, color: Colors.grey),
                          onPressed: () => _showReplySheet(pId: comment.id, rName: comment.userName),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // Bottom Bar for New Comments
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))]
            ),
            child: SafeArea(
              child: InkWell(
                onTap: () => _showReplySheet(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.comment_outlined, size: 20, color: Colors.grey),
                      SizedBox(width: 12),
                      Text("Write a comment...", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}