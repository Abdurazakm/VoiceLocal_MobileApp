import 'package:flutter/material.dart';
import '../../models/issue_model.dart';
import '../../services/issue_service.dart';

class IssueDetailScreen extends StatelessWidget {
  final Issue issue;
  const IssueDetailScreen({super.key, required this.issue});

  @override
  Widget build(BuildContext context) {
    final IssueService issueService = IssueService();

    return Scaffold(
      appBar: AppBar(title: Text(issue.title)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display Image/Video from Cloudinary
            if (issue.attachmentUrl != null)
              Container(
                width: double.infinity,
                height: 250,
                color: Colors.grey[200],
                child: Image.network(
                  issue.attachmentUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Center(child: Icon(Icons.broken_image, size: 50)),
                ),
              ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Chip(
                        label: Text(issue.status),
                        backgroundColor: issue.status == 'Open' ? Colors.orange[100] : Colors.green[100],
                      ),
                      Text(
                        "${issue.voteCount} Votes",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text("Description", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  Text(issue.description),
                  const SizedBox(height: 40),
                  
                  // FR-8: Voting Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await issueService.voteForIssue(issue.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Vote counted!")),
                          );
                        }
                      },
                      icon: const Icon(Icons.thumb_up),
                      label: const Text("Vote for this Issue"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}