import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/issue_service.dart';
import '../../models/issue_model.dart';
import 'add_issue_screen.dart';
import 'issue_detail_screen.dart';
import 'profile/ProfileScreen.dart';

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
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
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

              bool hasMedia = issue.attachmentUrl != null && issue.attachmentUrl!.isNotEmpty;
              bool isVideo = hasMedia && (issue.attachmentUrl!.contains(".mp4") || issue.attachmentUrl!.contains("video/upload"));

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListTile(
                    leading: Container(
                      width: 55,
                      height: 55,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
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
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          issue.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        // UPDATED: Added Region and Street info in the list view
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 12, color: Colors.redAccent),
                            const SizedBox(width: 2),
                            Text(
                              "${issue.region}, ${issue.street}",
                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                    subtitle: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: issue.status == 'Resolved' ? Colors.green[50] : Colors.orange[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            issue.status,
                            style: TextStyle(
                              color: issue.status == 'Resolved' ? Colors.green[700] : Colors.orange[700],
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text("• ${issue.voteCount} Votes", style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => IssueDetailScreen(issue: issue),
                        ),
                      );
                    },
                  ),
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
