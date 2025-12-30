import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/issue_service.dart';
import '../../models/issue_model.dart';
import 'add_issue_screen.dart';
import 'issue_detail_screen.dart';
import 'profile/ProfileScreen.dart';

class UserHome extends StatefulWidget {
  const UserHome({super.key});

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  final IssueService _issueService = IssueService();
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final primaryColor = const Color(0xFF1E88E5); // Modern Blue

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
        title: Text(
          "VoiceLocal",
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.account_circle_outlined, color: Colors.grey[700], size: 28),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
          ),
          IconButton(
            icon: Icon(Icons.logout_rounded, color: Colors.grey[700]),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- STYLISH SEARCH BAR ---
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: "Search community issues...",
                prefixIcon: Icon(Icons.search, color: primaryColor),
                suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = "");
                      }) 
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          Expanded(
            child: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('Users').doc(currentUid).get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                final String userReg = (userData?['region'] ?? '').toString().toLowerCase();
                final String userStr = (userData?['street'] ?? '').toString().toLowerCase();

                return StreamBuilder<List<Issue>>(
                  stream: _issueService.getIssues(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return _buildEmptyState();
                    }

                    List<Issue> filteredIssues = snapshot.data!.where((issue) {
                      final titleMatch = issue.title.toLowerCase().contains(_searchQuery);
                      final catMatch = issue.category.toLowerCase().contains(_searchQuery);
                      return titleMatch || catMatch;
                    }).toList();

                    filteredIssues.sort((a, b) {
                      int getPriority(Issue issue) {
                        String iReg = issue.region.toLowerCase();
                        String iStr = issue.street.toLowerCase();
                        if (iReg == userReg && iStr == userStr) return 0;
                        if (iReg == userReg) return 1;
                        return 2;
                      }
                      int pA = getPriority(a);
                      int pB = getPriority(b);
                      if (pA != pB) return pA.compareTo(pB);
                      return (b.createdAt).compareTo(a.createdAt);
                    });

                    return ListView.builder(
                      padding: const EdgeInsets.only(top: 10, bottom: 80),
                      itemCount: filteredIssues.length,
                      itemBuilder: (context, index) {
                        final issue = filteredIssues[index];
                        bool isExact = issue.region.toLowerCase() == userReg && issue.street.toLowerCase() == userStr;
                        bool isReg = issue.region.toLowerCase() == userReg;

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => IssueDetailScreen(issue: issue))),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLeadingMedia(issue),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            if (isExact) _badge("MY STREET", Colors.blue)
                                            else if (isReg) _badge("MY REGION", Colors.orange)
                                            else _badge(issue.category.toUpperCase(), Colors.grey),
                                            
                                            _statusDot(issue.status),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          issue.title,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF263238)),
                                          maxLines: 1, overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                "${issue.region}, ${issue.street}",
                                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            // VOTE COUNT
                                            const Icon(Icons.thumb_up_off_alt, size: 16, color: Colors.blue),
                                            const SizedBox(width: 4),
                                            Text("${issue.voteCount}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                            
                                            const SizedBox(width: 16),
                                            
                                            // COMMENT COUNT
                                            const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.blue),
                                            const SizedBox(width: 4),
                                            Text("${issue.commentCount}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                            
                                            const Spacer(),
                                            
                                            Text(
                                              issue.status,
                                              style: TextStyle(
                                                color: issue.status == 'Resolved' ? Colors.green : Colors.orange[800],
                                                fontWeight: FontWeight.bold, fontSize: 12
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddIssueScreen())),
        label: const Text("Report Issue", style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_photo_alternate_outlined),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  Widget _statusDot(String status) {
    return Container(
      width: 8, height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: status == 'Resolved' ? Colors.green : Colors.orange,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text("No issues found", style: TextStyle(color: Colors.grey[600], fontSize: 18, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildLeadingMedia(Issue issue) {
    bool hasMedia = issue.attachmentUrl != null && issue.attachmentUrl!.isNotEmpty;
    bool isVid = hasMedia && (issue.attachmentUrl!.contains(".mp4") || issue.attachmentUrl!.contains("video/upload"));

    return Container(
      width: 70, height: 70,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: hasMedia 
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isVid 
                ? const Center(child: Icon(Icons.play_circle_fill, color: Colors.blue, size: 30)) 
                : Image.network(issue.attachmentUrl!, fit: BoxFit.cover),
            )
          : Icon(Icons.image_outlined, color: Colors.grey[400], size: 30),
    );
  }
}