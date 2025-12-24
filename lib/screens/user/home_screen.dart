import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/issue_service.dart';
import '../../models/issue_model.dart';
import 'add_issue_screen.dart';
import 'issue_detail_screen.dart'; // Import for FR-7 implementation

class UserHome extends StatelessWidget {
  const UserHome({super.key});

  @override
  Widget build(BuildContext context) {
    // Accessing the Service Layer as defined in System Architecture [cite: 134]
    final IssueService issueService = IssueService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("VoiceLocal Issues"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            // Implements FR-3: User logout [cite: 70]
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      // Implements NFR-4: Real-time updates [cite: 106]
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

          // FR-6: Display reported issues in a list [cite: 77, 110]
          return ListView.builder(
            itemCount: issues.length,
            itemBuilder: (context, index) {
              final issue = issues[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  // Displaying core Issue attributes [cite: 206, 208]
                  title: Text(issue.title),
                  // Displaying status and vote count [cite: 210, 211]
                  subtitle: Text("${issue.status} • ${issue.voteCount} Votes"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Navigate to Issue Detail Screen for FR-7 and FR-8 [cite: 117, 119]
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
      // FR-4: Trigger for adding a new issue [cite: 75, 116]
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