import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart'; // Ensure you added shimmer to pubspec.yaml
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
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Color primaryColor = const Color(0xFF3F51B5);

  List<Issue> _issues = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMore = true;
  String _searchQuery = "";
  
  String userReg = "";
  String userStr = "";

  @override
  void initState() {
    super.initState();
    _initializeUserAndData();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9) {
      if (!_isLoading && _hasMore) {
        _fetchIssues();
      }
    }
  }

  Future<void> _initializeUserAndData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final userDoc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        setState(() {
          userReg = (data?['region'] ?? '').toString().toLowerCase();
          userStr = (data?['street'] ?? '').toString().toLowerCase();
        });
      }
    }
    _fetchIssues(isRefresh: true);
  }

  Future<void> _fetchIssues({bool isRefresh = false}) async {
    if (_isLoading || (!isRefresh && !_hasMore)) return;

    setState(() => _isLoading = true);

    if (isRefresh) {
      _lastDocument = null;
      _issues.clear();
      _hasMore = true;
    }

    Query query = FirebaseFirestore.instance.collection('Issues')
        .orderBy('createdAt', descending: true)
        .limit(10);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    try {
      final snapshot = await query.get();

      if (snapshot.docs.length < 10) _hasMore = false;

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        
        final List<Issue> newIssues = snapshot.docs.map<Issue>((doc) {
          return Issue.fromFirestore(doc);
        }).toList();

        setState(() {
          _issues.addAll(newIssues);
          _applySorting();
        });
      }
    } catch (e) {
      debugPrint("Error fetching issues: $e");
    }

    setState(() => _isLoading = false);
  }

  void _applySorting() {
    _issues.sort((a, b) {
      int getP(Issue i) {
        if (i.region.toLowerCase() == userReg && i.street.toLowerCase() == userStr) return 0;
        if (i.region.toLowerCase() == userReg) return 1;
        return 2;
      }
      int res = getP(a).compareTo(getP(b));
      return res != 0 ? res : b.createdAt.compareTo(a.createdAt);
    });
  }

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    
    final filteredDisplayList = _issues.where((issue) {
      return issue.title.toLowerCase().contains(_searchQuery) || 
             issue.category.toLowerCase().contains(_searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE), 
      body: RefreshIndicator(
        onRefresh: () => _fetchIssues(isRefresh: true),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              expandedHeight: 120.0,
              floating: true,
              pinned: true,
              elevation: 0,
              backgroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                title: Row(
                  children: [
                    Image.asset(
                      'assets/logo.png', 
                      height: 24, 
                      errorBuilder: (c, e, s) => Icon(Icons.campaign, color: primaryColor),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "VoiceLocal",
                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ],
                ),
              ),
              actions: [
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('Users').doc(currentUid).snapshots(),
                  builder: (context, userSnapshot) {
                    String? profileUrl;
                    if (userSnapshot.hasData && userSnapshot.data!.exists) {
                      final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                      profileUrl = userData?['profilePic'];
                    }

                    return IconButton(
                      icon: CircleAvatar(
                        backgroundColor: primaryColor.withOpacity(0.1),
                        radius: 18,
                        backgroundImage: (profileUrl != null && profileUrl.isNotEmpty)
                            ? NetworkImage(profileUrl) : null,
                        child: (profileUrl == null || profileUrl.isEmpty)
                            ? Icon(Icons.person_outline, color: primaryColor, size: 20) : null,
                      ),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.grey),
                  onPressed: () => FirebaseAuth.instance.signOut(),
                ),
                const SizedBox(width: 8),
              ],
            ),

            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Hello community!", style: TextStyle(color: Colors.grey, fontSize: 16)),
                    const Text("Local Issues", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                      decoration: InputDecoration(
                        hintText: "Search issues or categories...",
                        prefixIcon: Icon(Icons.search_rounded, color: primaryColor),
                        filled: true,
                        fillColor: const Color(0xFFF1F4FF),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _issues.isEmpty && !_isLoading 
            ? SliverFillRemaining(child: _buildEmptyState())
            : SliverPadding(
                padding: const EdgeInsets.only(bottom: 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      // Initial Loading State
                      if (_issues.isEmpty && _isLoading) {
                        return _buildIssueShimmer();
                      }

                      // Paginated Loading State
                      if (index == filteredDisplayList.length) {
                        return _hasMore 
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: _buildIssueShimmer(),
                            )
                          : const Padding(
                              padding: EdgeInsets.all(20), 
                              child: Center(child: Text("No more issues found", style: TextStyle(color: Colors.grey)))
                            );
                      }
                      return _buildIssueCard(filteredDisplayList[index], userReg, userStr);
                    },
                    childCount: (_issues.isEmpty && _isLoading) ? 6 : filteredDisplayList.length + 1,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddIssueScreen())),
        icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
        label: const Text("Report Issue", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildIssueShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Container(width: 85, height: 85, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15))),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 60, height: 12, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(width: double.infinity, height: 16, color: Colors.white),
                  const SizedBox(height: 4),
                  Container(width: 100, height: 12, color: Colors.white),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(width: 30, height: 12, color: Colors.white),
                      const SizedBox(width: 12),
                      Container(width: 30, height: 12, color: Colors.white),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueCard(Issue issue, String uReg, String uStr) {
    bool isMyStreet = issue.region.toLowerCase() == uReg && issue.street.toLowerCase() == uStr;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => IssueDetailScreen(issue: issue))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildLeadingMedia(issue),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _badge(isMyStreet ? "MY STREET" : issue.category.toUpperCase(), isMyStreet ? primaryColor : Colors.blueGrey),
                        _statusDot(issue.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(issue.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text("${issue.region}, ${issue.street}", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _miniStat(Icons.thumb_up_alt_rounded, "${issue.voteCount}"),
                        const SizedBox(width: 12),
                        _miniStat(Icons.mode_comment_rounded, "${issue.commentCount}"),
                        const Spacer(),
                        Text(issue.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: issue.status == 'Resolved' ? Colors.green : Colors.orange)),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String count) {
    return Row(children: [
      Icon(icon, size: 14, color: primaryColor.withOpacity(0.5)),
      const SizedBox(width: 4),
      Text(count, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _statusDot(String status) {
    return Container(
      width: 8, height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: status == 'Resolved' ? Colors.green : Colors.orange,
        boxShadow: [BoxShadow(color: (status == 'Resolved' ? Colors.green : Colors.orange).withOpacity(0.4), blurRadius: 4)],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 100, color: primaryColor.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text("Everything looks clear!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text("No issues reported here yet.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildLeadingMedia(Issue issue) {
    return Container(
      width: 85, height: 85,
      decoration: BoxDecoration(color: const Color(0xFFF1F4FF), borderRadius: BorderRadius.circular(15)),
      child: issue.attachmentUrl != null && issue.attachmentUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.network(issue.attachmentUrl!, fit: BoxFit.cover, errorBuilder: (c, e, s) => Icon(Icons.broken_image, color: primaryColor.withOpacity(0.2))),
            )
          : Icon(Icons.image_not_supported_outlined, color: primaryColor.withOpacity(0.2)),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}