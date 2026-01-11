import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart'; 
import 'dart:async'; 
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
  StreamSubscription? _realtimeSubscription; 
  
  final Color primaryColor = const Color(0xFF3F51B5);
  final Color surfaceColor = Colors.white;
  final Color backgroundColor = const Color(0xFFF8F9FE);
  final Color textDark = const Color(0xFF1A1C1E);
  final Color textLight = const Color(0xFF6C757D);

  final List<Issue> _issues = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMore = true;
  String _searchQuery = "";
  
  String userReg = "";
  String userStr = "";
  String userRole = "user"; 
  String? adminSector;
  String? adminRegion; // Added adminRegion

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
            // Ensure this field matches your Firestore "Users" collection field name
            adminSector = data?['assignedSector'] ?? data?['sector']; 
            adminRegion = data?['assignedRegion']; // Capture assignedRegion
          });
        }
      } catch (e) {
        debugPrint("Error fetching user data: $e");
      }
    }
    // Initial fetch
    await _fetchIssues(isRefresh: true);
    _setupRealTimeListener();
  }

  void _setupRealTimeListener() {
    _realtimeSubscription?.cancel();
    
    Query query = FirebaseFirestore.instance.collection('Issues');

    // SECTOR ADMIN FILTERING LOGIC
    if (userRole == 'sector_admin' && adminSector != null) {
      query = query
          .where('category', isEqualTo: _toTitleCase(adminSector!))
          .where('region', isEqualTo: _toTitleCase(adminRegion ?? userReg)); // Use adminRegion
    }

    _realtimeSubscription = query
        .orderBy('createdAt', descending: true)
        .limit(20) 
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final newIssue = Issue.fromFirestore(change.doc);
          bool exists = _issues.any((issue) => issue.id == newIssue.id);
          if (!exists) {
            setState(() {
              _issues.insert(0, newIssue); 
              if (userRole == 'user') _applySorting();
            });
          }
        } 
        else if (change.type == DocumentChangeType.removed) {
          setState(() {
            _issues.removeWhere((issue) => issue.id == change.doc.id);
          });
        }
        else if (change.type == DocumentChangeType.modified) {
          final modIssue = Issue.fromFirestore(change.doc);
          int idx = _issues.indexWhere((i) => i.id == modIssue.id);
          if (idx != -1) {
            setState(() {
              _issues[idx] = modIssue;
              if (userRole == 'user') _applySorting();
            });
          }
        }
      }
    });
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

      // SECTOR ADMIN FILTERING LOGIC
      if (userRole == 'sector_admin' && adminSector != null) {
        query = query
            .where('category', isEqualTo: _toTitleCase(adminSector!))
            .where('region', isEqualTo: _toTitleCase(adminRegion ?? userReg)); // Use adminRegion
      }
      
      query = query.orderBy('createdAt', descending: true).limit(10);
      
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();
      
      if (snapshot.docs.length < 10) {
        _hasMore = false;
      }

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        final List<Issue> newIssues = snapshot.docs.map<Issue>((doc) => Issue.fromFirestore(doc)).toList();
        
        setState(() {
          for (var newItem in newIssues) {
            if (!_issues.any((existing) => existing.id == newItem.id)) {
              _issues.add(newItem);
            }
          }
          if (userRole == 'user') _applySorting();
        });
      }
    } catch (e) {
      debugPrint("FireStore Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applySorting() {
    _issues.sort((a, b) {
      int getP(Issue i) {
        String r = i.region.toLowerCase().trim();
        String s = i.street.toLowerCase().trim();
        if (r == userReg.toLowerCase().trim() && s == userStr.toLowerCase().trim()) return 0;
        if (r == userReg.toLowerCase().trim()) return 1;
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
    
    final filteredList = _issues.where((issue) {
      final q = _searchQuery.toLowerCase();
      return issue.title.toLowerCase().contains(q) || issue.category.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: backgroundColor,
      body: RefreshIndicator(
        onRefresh: () => _fetchIssues(isRefresh: true),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildAppBar(isAdmin, currentUid),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isAdmin ? "Sector Administration" : "Community Feed", 
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textDark)),
                    if (isAdmin) _buildAdminStats(isAdmin),
                    const SizedBox(height: 15),
                    _buildSearchBar(),
                  ],
                ),
              ),
            ),
            filteredList.isEmpty && !_isLoading 
            ? SliverFillRemaining(child: _buildEmptyState())
            : SliverPadding(
                padding: const EdgeInsets.only(bottom: 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == filteredList.length) {
                        return _hasMore ? _buildIssueShimmer() : _buildEndOfList();
                      }
                      return _buildIssueCard(filteredList[index], userReg, userStr, isAdmin);
                    },
                    childCount: filteredList.length + 1,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: isAdmin ? null : _buildReportButton(),
    );
  }

  Widget _buildAppBar(bool isAdmin, String uid) {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        title: Row(
          children: [
            if (isAdmin)
               const Icon(Icons.admin_panel_settings, color: Color(0xFF3F51B5))
            else
               Image.asset('assets/logo.png', height: 40),
            const SizedBox(width: 10),
            Text(isAdmin ? "Admin Console" : "VoiceLocal", 
              style: const TextStyle(color: Color(0xFF3F51B5), fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
      ),
      actions: [
        _buildProfileButton(uid),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 24),
          onPressed: () => FirebaseAuth.instance.signOut(),
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: "Search issues or categories...",
          prefixIcon: Icon(Icons.search_rounded, color: primaryColor.withOpacity(0.5)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildAdminStats(bool isAdmin) {
    Query query = FirebaseFirestore.instance.collection('Issues');
    // SECTOR ADMIN FILTERING LOGIC
    if (userRole == 'sector_admin' && adminSector != null) {
      query = query
          .where('category', isEqualTo: _toTitleCase(adminSector!))
          .where('region', isEqualTo: _toTitleCase(adminRegion ?? userReg));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 10);
        int total = snapshot.data!.docs.length;
        int resolved = snapshot.data!.docs.where((doc) => doc['status'] == 'Resolved').length;
        int pending = total - resolved;

        return Container(
          margin: const EdgeInsets.only(top: 15),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [primaryColor, primaryColor.withBlue(200)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem("Total", total.toString(), Colors.white),
              _statItem("Pending", pending.toString(), Colors.white.withOpacity(0.8)),
              _statItem("Resolved", resolved.toString(), Colors.white.withOpacity(0.8)),
            ],
          ),
        );
      },
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
        Text(label.toUpperCase(), style: TextStyle(fontSize: 10, letterSpacing: 1, color: color.withOpacity(0.7), fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildIssueCard(Issue issue, String uReg, String uStr, bool isAdmin) {
    bool isMyStreet = issue.region.toLowerCase().trim() == uReg.toLowerCase().trim() && 
                      issue.street.toLowerCase().trim() == uStr.toLowerCase().trim();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _handleIssueTap(issue, isAdmin),
        child: Padding(
          padding: const EdgeInsets.all(15),
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
                        _badge(isMyStreet ? "MY STREET" : issue.category.toUpperCase(), 
                               isMyStreet ? primaryColor : textLight),
                        _statusDot(issue.status),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(issue.title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textDark), maxLines: 1),
                    Text("${issue.region}, ${issue.street}", style: TextStyle(color: textLight, fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                    _buildIssueFooter(issue),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIssueFooter(Issue issue) {
    return StreamBuilder<DocumentSnapshot>(
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
            _miniStat(Icons.thumb_up_rounded, "$votes"),
            const SizedBox(width: 15),
            _miniStat(Icons.mode_comment_rounded, "$comments"),
            const Spacer(),
            Text(issue.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: issue.status == 'Resolved' ? Colors.green : Colors.orange)),
          ],
        );
      },
    );
  }

  void _handleIssueTap(Issue issue, bool isAdmin) async {
    if (isAdmin) {
      showModalBottomSheet(
        context: context,
        backgroundColor: surfaceColor,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        builder: (context) => Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFE3F2FD), child: Icon(Icons.visibility, color: Colors.blue)),
                title: const Text("Detailed Analysis", style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => IssueDetailScreen(issue: issue))); },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFFFF3E0), child: Icon(Icons.edit_note, color: Colors.orange)),
                title: const Text("Change Resolution Status", style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () { Navigator.pop(context); showDialog(context: context, builder: (context) => StatusUpdateDialog(issueId: issue.id, currentStatus: issue.status)); },
              ),
            ],
          ),
        ),
      );
    } else {
      await Navigator.push(context, MaterialPageRoute(builder: (context) => IssueDetailScreen(issue: issue)));
      _fetchIssues(isRefresh: true); 
    }
  }

  Widget _buildReportButton() {
    return FloatingActionButton.extended(
      backgroundColor: primaryColor,
      onPressed: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddIssueScreen()));
        _fetchIssues(isRefresh: true);
      },
      icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
      label: const Text("Report Issue", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildProfileButton(String uid) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('Users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        String? url = (snapshot.data?.data() as Map<String, dynamic>?)?['profilePic'];
        return InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
          child: CircleAvatar(
            backgroundColor: primaryColor.withOpacity(0.1),
            radius: 18,
            backgroundImage: (url != null && url.isNotEmpty) ? NetworkImage(url) : null,
            child: (url == null || url.isEmpty) ? Icon(Icons.person, color: primaryColor, size: 20) : null,
          ),
        );
      },
    );
  }

  Widget _buildLeadingMedia(Issue issue) {
    bool looksLikeVideo = issue.isVideo || 
        (issue.attachmentUrl?.toLowerCase().contains('.mp4') ?? false) ||
        (issue.attachmentUrl?.toLowerCase().contains('.mov') ?? false);

    return Container(
      width: 85, height: 85,
      decoration: BoxDecoration(
        color: textDark.withOpacity(0.05), 
        borderRadius: BorderRadius.circular(15)
      ),
      child: issue.attachmentUrl != null && issue.attachmentUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: looksLikeVideo 
                ? VideoPreviewThumbnail(url: issue.attachmentUrl!) 
                : Image.network(
                    issue.attachmentUrl!, 
                    fit: BoxFit.cover, 
                    errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.grey),
                  ),
            )
          : Icon(Icons.image_outlined, color: primaryColor.withOpacity(0.2), size: 30),
    );
  }

  Widget _miniStat(IconData icon, String count) => Row(children: [Icon(icon, size: 16, color: textLight), const SizedBox(width: 5), Text(count, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark))]);
  Widget _badge(String label, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)));
  Widget _statusDot(String status) => Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: status == 'Resolved' ? Colors.green : Colors.orange, border: Border.all(color: Colors.white, width: 2)));
  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inbox_outlined, size: 80, color: textLight.withOpacity(0.3)), const SizedBox(height: 10), Text("No reports found", style: TextStyle(fontWeight: FontWeight.bold, color: textLight))]));
  Widget _buildEndOfList() => Padding(padding: const EdgeInsets.all(40), child: Center(child: Text("YOU'RE ALL CAUGHT UP", style: TextStyle(color: textLight, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1))));
  Widget _buildIssueShimmer() => Shimmer.fromColors(baseColor: Colors.white, highlightColor: backgroundColor, child: Container(margin: const EdgeInsets.all(16), height: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))));

  @override
  void dispose() {
    _realtimeSubscription?.cancel(); 
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}


class VideoPreviewThumbnail extends StatefulWidget {
  final String url;
  const VideoPreviewThumbnail({super.key, required this.url});

  @override
  State<VideoPreviewThumbnail> createState() => _VideoPreviewThumbnailState();
}

class _VideoPreviewThumbnailState extends State<VideoPreviewThumbnail> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _controller.seekTo(const Duration(seconds: 1)); 
          });
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          ),
        ),
        const Icon(Icons.play_circle_outline, color: Colors.white70, size: 28),
      ],
    );
  }
}