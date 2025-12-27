import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/issue_service.dart';
import '../../models/issue_model.dart';
import 'add_issue_screen.dart';
import 'issue_detail_screen.dart';

class UserHome extends StatelessWidget {
  const UserHome({super.key});

  @override
  Widget build(BuildContext context) {
    final IssueService issueService = IssueService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("VoiceLocal Issues"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<List<Issue>>(
        stream: issueService.getIssues(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No issues reported yet."));
          }

          final issues = snapshot.data!;

          return ListView.builder(
            itemCount: issues.length,
            itemBuilder: (context, index) {
              final issue = issues[index];
              
              // Logic to check if media exists
              bool hasMedia = issue.attachmentUrl != null && issue.attachmentUrl!.isNotEmpty;
              bool isVideo = hasMedia && (issue.attachmentUrl!.contains(".mp4") || issue.attachmentUrl!.contains("video/upload"));

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  // ADDED: Media Thumbnail for Image/Video
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: hasMedia
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: isVideo
                                ? const Icon(Icons.videocam, color: Colors.blue)
                                : Image.network(
                                    issue.attachmentUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                                  ),
                          )
                        : const Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
                  title: Text(
                    issue.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("${issue.status} • ${issue.voteCount} Votes"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => IssueDetailScreen(issue: issue),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddIssueScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}