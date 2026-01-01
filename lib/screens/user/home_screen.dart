import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/issue_model.dart';
import 'add_issue_screen.dart';
import 'issue_detail_screen.dart';
import 'profile/ProfileScreen.dart';
import '../admin/status_update_dialog.dart';

class UserHome extends StatefulWidget {
  const UserHome({super.key});

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Color primaryColor = const Color(0xFF3F51B5);

  final List<Issue> _issues = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMore = true;
  String _searchQuery = "";
  
  String userReg = "";
  String userStr = "";
  String userRole = "user"; 
  String? adminSector;

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
      try {
        final userDoc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          setState(() {
            userReg = (data?['region'] ?? '').toString().trim();
            userStr = (data?['street'] ?? '').toString().trim();
            userRole = data?['role'] ?? 'user';
            adminSector = data?['assignedSector'];
          });
        }
      } catch (e) {
        debugPrint("Error fetching user data: $e");
      }
    }
    _fetchIssues(isRefresh: true);
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  Future<void> _fetchIssues({bool isRefresh = false}) async {
    if (_isLoading || (!isRefresh && !_hasMore)) return;

    setState(() => _isLoading = true);

    if (isRefresh) {
      _lastDocument = null;
      _issues.clear();
      _hasMore = true;
    }

    try {
      Query query = FirebaseFirestore.instance.collection('Issues');

      if (userRole == 'sector_admin' && adminSector != null) {
        String formattedRegion = _toTitleCase(userReg);
        String formattedCategory = _toTitleCase(adminSector!);
        
        query = query
            .where('category', isEqualTo: formattedCategory)
            .where('region', isEqualTo: formattedRegion);
      }

      query = query.orderBy('createdAt', descending: true).limit(10);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.length < 10) _hasMore = false;

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        
        final List<Issue> newIssues = snapshot.docs.map<Issue>((doc) {
          return Issue.fromFirestore(doc);
        }).toList();

        setState(() {
          _issues.addAll(newIssues);
          if (userRole == 'user') {
            _applySorting();
          }
        });
      }
    } catch (e) {
      debugPrint("!!! FIRESTORE QUERY ERROR: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applySorting() {
    _issues.sort((a, b) {
      int getP(Issue i) {
        String r = i.region.toLowerCase().trim();
        String s = i.street.toLowerCase().trim();
        String uR = userReg.toLowerCase().trim();
        String uS = userStr.toLowerCase().trim();
        if (r == uR && s == uS) return 0;
        if (r == uR) return 1;
        return 2;
      }
      int res = getP(a).compareTo(getP(b));
      return res != 0 ? res : b.createdAt.compareTo(a.createdAt);
    });
  }

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final bool isAdmin = userRole == 'sector_admin' || userRole == 'super_admin';
    
    final filteredDisplayList = _issues.where((issue) {
      final query = _searchQuery.toLowerCase();
      return issue.title.toLowerCase().contains(query) || 
             issue.category.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE), 
      body: RefreshIndicator(
        onRefresh: () => _fetchIssues(isRefresh: true),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              expandedHeight: 140.0, // Increased height for larger logo
              floating: true,
              pinned: true,
              elevation: 0,
              backgroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Increased Logo Size
                    Image.asset(
                      'assets/logo.png', 
                      height: 40, // Increased height
                      width: 40,  // Added width for visibility
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        isAdmin ? Icons.admin_panel_settings : Icons.campaign, 
                        color: primaryColor, 
                        size: 32 // Increased fallback size
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isAdmin ? "Admin Console" : "VoiceLocal",
                      style: TextStyle(
                        color: primaryColor, 
                        fontWeight: FontWeight.bold, 
                        fontSize: 22 // Increased title font size
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                _buildProfileButton(currentUid),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.grey, size: 28),
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
                    Text(isAdmin 
                      ? (userRole == 'super_admin' ? "All Active Reports" : "Jurisdiction: $adminSector") 
                      : "Hello community!", 
                      style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    Text(isAdmin ? "Management Hub" : "Local Issues", 
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    
                    if (isAdmin) _buildAdminStats(),

                    const SizedBox(height: 15),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _searchQuery = value),
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

            filteredDisplayList.isEmpty && !_isLoading 
            ? SliverFillRemaining(child: _buildEmptyState())
            : SliverPadding(
                padding: const EdgeInsets.only(bottom: 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == filteredDisplayList.length) {
                        return _hasMore ? _buildIssueShimmer() : _buildEndOfList();
                      }
                      return _buildIssueCard(filteredDisplayList[index], userReg, userStr, isAdmin);
                    },
                    childCount: filteredDisplayList.length + 1,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: isAdmin ? null : FloatingActionButton.extended(
        backgroundColor: primaryColor,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddIssueScreen())),
        icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
        label: const Text("Report Issue", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildProfileButton(String uid) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('Users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        String? url = (snapshot.data?.data() as Map<String, dynamic>?)?['profilePic'];
        return IconButton(
          icon: CircleAvatar(
            backgroundColor: primaryColor.withOpacity(0.1),
            radius: 20,
            backgroundImage: (url != null && url.isNotEmpty) ? NetworkImage(url) : null,
            child: (url == null || url.isEmpty) ? Icon(Icons.person, color: primaryColor, size: 24) : null,
          ),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
        );
      },
    );
  }

  Widget _buildAdminStats() {
    Query query = FirebaseFirestore.instance.collection('Issues');
    if (userRole == 'sector_admin' && adminSector != null) {
      query = query
        .where('category', isEqualTo: _toTitleCase(adminSector!))
        .where('region', isEqualTo: _toTitleCase(userReg));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 10);
        int total = snapshot.data!.docs.length;
        int resolved = snapshot.data!.docs.where((doc) => doc['status'] == 'Resolved').length;
        int pending = total - resolved;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 15),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: primaryColor.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem("Total", total.toString()),
              _statItem("Pending", pending.toString()),
              _statItem("Resolved", resolved.toString()),
            ],
          ),
        );
      },
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildIssueCard(Issue issue, String uReg, String uStr, bool isAdmin) {
    bool isMyStreet = issue.region.toLowerCase().trim() == uReg.toLowerCase().trim() && 
                      issue.street.toLowerCase().trim() == uStr.toLowerCase().trim();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        onTap: () {
          if (isAdmin) {
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (context) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                    ListTile(
                      leading: const Icon(Icons.visibility_outlined, color: Colors.blue),
                      title: const Text("View Report Details"),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => IssueDetailScreen(issue: issue)));
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.edit_road_outlined, color: Colors.orange),
                      title: const Text("Update Resolution Status"),
                      onTap: () {
                        Navigator.pop(context);
                        showDialog(
                          context: context, 
                          builder: (context) => StatusUpdateDialog(issueId: issue.id, currentStatus: issue.status)
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (context) => IssueDetailScreen(issue: issue)));
          }
        },
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
                    // StreamBuilder for real-time vote/comment counts
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('Issues').doc(issue.id).snapshots(),
                      builder: (context, snapshot) {
                        int votes = issue.voteCount;
                        int comments = issue.commentCount;

                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data = snapshot.data!.data() as Map<String, dynamic>;
                          votes = data['voteCount'] ?? 0;
                          comments = data['commentCount'] ?? 0;
                        }

                        return Row(
                          children: [
                            _miniStat(Icons.thumb_up_alt_rounded, "$votes"),
                            const SizedBox(width: 12),
                            _miniStat(Icons.comment_rounded, "$comments"),
                            const Spacer(),
                            Text(
                              issue.status, 
                              style: TextStyle(
                                fontSize: 11, 
                                fontWeight: FontWeight.bold, 
                                color: issue.status == 'Resolved' ? Colors.green : Colors.orange
                              )
                            ),
                          ],
                        );
                      }
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

  Widget _buildLeadingMedia(Issue issue) {
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(color: const Color(0xFFF1F4FF), borderRadius: BorderRadius.circular(12)),
      child: issue.attachmentUrl != null && issue.attachmentUrl!.isNotEmpty
          ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(issue.attachmentUrl!, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image)))
          : Icon(Icons.image_not_supported, color: primaryColor.withOpacity(0.2)),
    );
  }

  Widget _miniStat(IconData icon, String count) => Row(children: [Icon(icon, size: 16, color: Colors.grey[600]), const SizedBox(width: 4), Text(count, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))]);
  
  Widget _badge(String label, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)));

  Widget _statusDot(String status) => Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: status == 'Resolved' ? Colors.green : Colors.orange));

  Widget _buildEmptyState() => const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.map_outlined, size: 80, color: Colors.grey), Text("No issues found", style: TextStyle(fontWeight: FontWeight.bold))]));

  Widget _buildEndOfList() => const Padding(padding: EdgeInsets.all(30), child: Center(child: Text("You've reached the end", style: TextStyle(color: Colors.grey, fontSize: 12))));

  Widget _buildIssueShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(margin: const EdgeInsets.all(16), height: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}