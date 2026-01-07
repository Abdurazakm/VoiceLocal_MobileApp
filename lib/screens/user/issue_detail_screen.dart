import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../models/issue_model.dart';
import '../../models/comment_model.dart';
import '../../services/issue_service.dart';
import 'profile/ProfileScreen.dart';

class IssueDetailScreen extends StatefulWidget {
  final Issue issue;
  const IssueDetailScreen({super.key, required this.issue});

  @override
  State<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final IssueService _issueService = IssueService();
  final Set<String> _visibleReplies = {};

  // Video playback controllers
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;

  // Theme Colors
  final Color primaryColor = const Color(0xFF1A237E); 
  final Color accentColor = const Color(0xFF3949AB);

  @override
  void initState() {
    super.initState();
    _checkAndInitMedia();
  }

  // Helper to determine if we should treat the attachment as a video
  bool _isActuallyAVideo() {
    final url = widget.issue.attachmentUrl?.toLowerCase() ?? "";
    bool hasVideoExtension = url.contains(".mp4") || 
                             url.contains(".mov") || 
                             url.contains(".avi") || 
                             url.contains(".m4v");
    return widget.issue.isVideo || hasVideoExtension;
  }

  void _checkAndInitMedia() {
    if (_isActuallyAVideo() && widget.issue.attachmentUrl != null) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    try {
      // Dispose old controller if exists (useful after edit)
      await _videoPlayerController?.dispose();
      _chewieController?.dispose();

      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.issue.attachmentUrl!),
      );

      await _videoPlayerController!.initialize();
      
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        placeholder: Container(color: Colors.black),
        materialProgressColors: ChewieProgressColors(
          playedColor: primaryColor,
          handleColor: accentColor,
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(errorMessage, style: const TextStyle(color: Colors.white)),
          );
        },
      );

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("Video Initialization Error: $e");
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _commentController.dispose();
    super.dispose();
  }

  // --- UI COMPONENTS ---

  Widget _buildMedia(String? url) {
    if (url == null || url.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black, 
        borderRadius: BorderRadius.circular(16), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _isActuallyAVideo() ? _buildVideoPlayer() : _buildImage(url),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_isVideoInitialized && _chewieController != null) {
      return AspectRatio(
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        child: Chewie(controller: _chewieController!),
      );
    } else {
      return Container(
        height: 220,
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 12),
              Text("Loading video...", style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildImage(String url) {
    return Image.network(
      url, 
      fit: BoxFit.cover, 
      errorBuilder: (c, e, s) => Container(
        height: 150, 
        color: Colors.grey[200], 
        child: const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey))
      ),
    );
  }

  // --- APP BUILD ---

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('Issues').doc(widget.issue.id).snapshots(),
      builder: (context, snapshot) {
        Issue currentIssue = snapshot.hasData && snapshot.data!.exists 
            ? Issue.fromFirestore(snapshot.data!) 
            : widget.issue;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Text("Issue Details", style: TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              if (currentIssue.createdBy == uid) ...[
                IconButton(icon: const Icon(Icons.edit_note_rounded), onPressed: () => _showEditIssueSheet(currentIssue)),
                IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent), onPressed: () => _confirmDeleteIssue(currentIssue.id)),
              ],
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(currentIssue),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAuthorRow(currentIssue, uid),
                            const SizedBox(height: 20),
                            Text(currentIssue.description, style: const TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF263238))),
                            _buildMedia(currentIssue.attachmentUrl),
                            const Divider(height: 40),
                            _buildVoteSection(currentIssue, uid),
                            const SizedBox(height: 30),
                            const Text("Community Discussion", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                            const SizedBox(height: 10),
                            _buildCommentsList(currentIssue, uid),
                          ],
                        ),
                      ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          floatingActionButton: _buildAddCommentButton(),
        );
      },
    );
  }

  // --- REFACTORED SUB-WIDGETS ---

  Widget _buildHeader(Issue currentIssue) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryColor, 
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusChip(currentIssue.status),
              Text(currentIssue.category.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Text(currentIssue.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.location_on, color: Colors.white60, size: 16),
            const SizedBox(width: 4),
            Expanded(child: Text("${currentIssue.street}, ${currentIssue.region}", style: const TextStyle(color: Colors.white70, fontSize: 14))),
          ]),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = status == 'Resolved' ? Colors.green : (status == 'In Progress' ? Colors.orange : Colors.blueGrey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  Widget _buildAuthorRow(Issue currentIssue, String uid) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('Users').doc(currentIssue.createdBy).snapshots(),
      builder: (context, userSnap) {
        String name = "User";
        String? pic;
        if (userSnap.hasData && userSnap.data!.exists) {
          final userData = userSnap.data!.data() as Map<String, dynamic>?;
          name = userData?['name'] ?? "User";
          pic = userData?['profilePic'] as String?;
        }

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('Users').doc(uid).get(),
          builder: (context, roleSnap) {
            bool isAdmin = false;
            if (roleSnap.hasData && roleSnap.data!.exists) {
              final roleData = roleSnap.data!.data() as Map<String, dynamic>?;
              isAdmin = ['admin', 'super_admin', 'sector_admin'].contains(roleData?['role']);
            }
            return Row(
              children: [
                GestureDetector(
                  onTap: () => _navigateToProfile(currentIssue.createdBy),
                  child: CircleAvatar(radius: 20, backgroundImage: (pic != null && pic.isNotEmpty) ? NetworkImage(pic) : null, child: pic == null ? const Icon(Icons.person) : null),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const Text("Reporter", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ]),
                ),
                if (isAdmin)
                  TextButton.icon(
                    onPressed: () => _showStatusUpdateSheet(currentIssue.id, currentIssue.status),
                    icon: const Icon(Icons.settings_suggest_rounded, size: 20),
                    label: const Text("Manage"),
                    style: TextButton.styleFrom(foregroundColor: accentColor),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildVoteSection(Issue currentIssue, String uid) {
    bool hasVoted = currentIssue.votedUids.contains(uid);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _issueService.voteForIssue(currentIssue.id),
            icon: Icon(hasVoted ? Icons.thumb_up_rounded : Icons.thumb_up_outlined),
            style: IconButton.styleFrom(
              backgroundColor: hasVoted ? primaryColor : Colors.white,
              foregroundColor: hasVoted ? Colors.white : primaryColor,
              side: BorderSide(color: primaryColor.withOpacity(0.2)),
            ),
          ),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("${currentIssue.voteCount} Community Votes", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const Text("High votes increase fix priority", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        ],
      ),
    );
  }

  Widget _buildCommentsList(Issue currentIssue, String uid) {
    return StreamBuilder<List<Comment>>(
      stream: _issueService.getComments(currentIssue.id),
      builder: (context, snapshot) {
        final allComments = snapshot.data ?? [];
        final parents = allComments.where((c) => c.parentId == null).toList();
        if (parents.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Text("No comments yet.", style: TextStyle(color: Colors.grey))));

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: parents.length,
          itemBuilder: (context, index) {
            final parent = parents[index];
            final replies = allComments.where((c) => c.parentId == parent.id).toList();
            return _buildCommentThread(parent, replies, uid, currentIssue.id);
          },
        );
      },
    );
  }

  Widget _buildCommentThread(Comment parent, List<Comment> replies, String uid, String issueId) {
    return Column(
      children: [
        ListTile(
          leading: _buildCommentAvatar(parent.userId),
          title: Text(parent.userName, style: TextStyle(fontWeight: FontWeight.bold, color: accentColor, fontSize: 14)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(parent.text, style: const TextStyle(color: Colors.black87)),
            if (replies.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _visibleReplies.contains(parent.id) ? _visibleReplies.remove(parent.id) : _visibleReplies.add(parent.id)),
                child: Text(_visibleReplies.contains(parent.id) ? "Hide Replies" : "Show ${replies.length} Replies", style: const TextStyle(fontSize: 12)),
              ),
          ]),
          trailing: _buildCommentActions(parent, parent.userId == uid, issueId),
        ),
        if (_visibleReplies.contains(parent.id))
          Padding(
            padding: const EdgeInsets.only(left: 45),
            child: Column(
              children: replies.map((r) => ListTile(
                dense: true,
                leading: _buildCommentAvatar(r.userId, small: true),
                title: Text(r.userName, style: TextStyle(fontWeight: FontWeight.bold, color: accentColor, fontSize: 13)),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (r.replyToName != null) Text("@${r.replyToName}", style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 11)),
                  Text(r.text),
                ]),
                trailing: _buildCommentActions(r, r.userId == uid, issueId, rootId: parent.id),
              )).toList(),
            ),
          ),
        const Divider(indent: 70, height: 1),
      ],
    );
  }

  Widget _buildCommentAvatar(String userId, {bool small = false}) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('Users').doc(userId).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        String? pic = data != null ? (data['profilePic'] as String?) : null;
        return CircleAvatar(
          radius: small ? 12 : 16,
          backgroundImage: (pic != null && pic.isNotEmpty) ? NetworkImage(pic) : null,
          child: pic == null ? const Icon(Icons.person, size: 16) : null,
        );
      },
    );
  }

  Widget _buildCommentActions(Comment c, bool isOwner, String issueId, {String? rootId}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(icon: const Icon(Icons.reply_rounded, size: 18), onPressed: () => _showReplySheet(pId: rootId ?? c.id, rName: c.userName)),
        if (isOwner)
          IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent), onPressed: () => _confirmDeleteComment(c.id, issueId)),
      ],
    );
  }

  Widget _buildAddCommentButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 5),
        onPressed: () => _showReplySheet(),
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text("Add a Comment", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- ACTIONS ---

  void _navigateToProfile(String userId) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(targetUserId: userId)));
  }

  void _confirmDeleteIssue(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Report?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await _issueService.deleteIssue(id);
              if (mounted) { Navigator.pop(context); Navigator.pop(context); }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteComment(String commentId, String issueId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Comment?"),
        content: const Text("Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await _issueService.deleteComment(commentId, issueId);
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showStatusUpdateSheet(String issueId, String currentStatus) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Pending', 'In Progress', 'Resolved'].map((status) {
            bool isSelected = status == currentStatus;
            return ListTile(
              leading: Icon(status == 'Resolved' ? Icons.check_circle : Icons.pending, color: isSelected ? primaryColor : Colors.grey),
              title: Text(status, style: TextStyle(color: isSelected ? primaryColor : Colors.black87)),
              onTap: () async {
                await FirebaseFirestore.instance.collection('Issues').doc(issueId).update({'status': status});
                if (mounted) Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
// --- UPDATED EDIT SHEET WITH STORAGE CLEANUP & INSTANT SYNC ---
  void _showEditIssueSheet(Issue currentIssue) {
    final tEdit = TextEditingController(text: currentIssue.title);
    final dEdit = TextEditingController(text: currentIssue.description);
    final sEdit = TextEditingController(text: currentIssue.street);

    String selectedCategory = currentIssue.category;
    String selectedRegion = currentIssue.region;

    File? _newMediaFile;
    bool _isNewVideo = false;
    bool _isUploading = false;

    final List<String> categories = ['Pothole', 'Water Leak', 'Power Outage', 'Waste', 'Street Light', 'Road Block', 'Other'];
    final List<String> regions = ['Downtown', 'North District', 'East Side', 'West Park', 'South Valley', 'Industrial Zone'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                ),
                const SizedBox(height: 20),
                const Text("Update Report", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 20),

                // --- MEDIA PREVIEW SECTION ---
                const Text("Evidence Media", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final source = await showModalActionSheet(context);
                    if (source == null) return;

                    final XFile? pickedFile = source == 'image'
                        ? await picker.pickImage(source: ImageSource.gallery)
                        : await picker.pickVideo(source: ImageSource.gallery);

                    if (pickedFile != null) {
                      setSheetState(() {
                        _newMediaFile = File(pickedFile.path);
                        _isNewVideo = source == 'video';
                      });
                    }
                  },
                  child: Stack(
                    children: [
                      Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(15),
                          image: _newMediaFile != null && !_isNewVideo
                              ? DecorationImage(image: FileImage(_newMediaFile!), fit: BoxFit.cover)
                              : (currentIssue.attachmentUrl != null && !currentIssue.isVideo && _newMediaFile == null
                                  ? DecorationImage(image: NetworkImage(currentIssue.attachmentUrl!), fit: BoxFit.cover)
                                  : null),
                        ),
                        child: (_isNewVideo || (currentIssue.isVideo && _newMediaFile == null))
                            ? const Center(
                                child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.play_circle_fill, size: 50, color: Colors.white),
                                  Text("Video Attached", style: TextStyle(color: Colors.white)),
                                ],
                              ))
                            : (_newMediaFile == null && currentIssue.attachmentUrl == null
                                ? const Icon(Icons.add_a_photo, size: 40, color: Colors.white54)
                                : null),
                      ),
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(20)),
                          child: const Row(
                            children: [
                              Icon(Icons.edit, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text("Change Media", style: TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // --- FORM FIELDS ---
                TextField(
                    controller: tEdit,
                    decoration: InputDecoration(
                        labelText: "Issue Title",
                        prefixIcon: const Icon(Icons.title),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 15),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: categories.contains(selectedCategory) ? selectedCategory : 'Other',
                        decoration: InputDecoration(labelText: "Category", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (val) => setSheetState(() => selectedCategory = val!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: regions.contains(selectedRegion) ? selectedRegion : regions.first,
                        decoration: InputDecoration(labelText: "Region", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        items: regions.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (val) => setSheetState(() => selectedRegion = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                TextField(
                    controller: sEdit,
                    decoration: InputDecoration(
                        labelText: "Street Address",
                        prefixIcon: const Icon(Icons.map_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 15),

                TextField(
                    controller: dEdit,
                    maxLines: 3,
                    decoration: InputDecoration(
                        labelText: "Detailed Description",
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 25),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: _isUploading ? null : () async {
                    setSheetState(() => _isUploading = true);

                    String? finalUrl = currentIssue.attachmentUrl;
                    bool finalIsVideo = currentIssue.isVideo;

                    if (_newMediaFile != null) {
                      // 1. Cleanup old storage file if it exists
                      if (currentIssue.attachmentUrl != null) {
                        try {
                          await FirebaseStorage.instance.refFromURL(currentIssue.attachmentUrl!).delete();
                        } catch (e) {
                          debugPrint("Old file deletion failed: $e");
                        }
                      }
                      // 2. Upload new file
                      String fileName = "update_${DateTime.now().millisecondsSinceEpoch}";
                      Reference ref = FirebaseStorage.instance.ref().child('issue_attachments/$fileName');
                      await ref.putFile(_newMediaFile!);
                      finalUrl = await ref.getDownloadURL();
                      finalIsVideo = _isNewVideo;
                    }

                    // 3. Update Firestore
                    await FirebaseFirestore.instance.collection('Issues').doc(currentIssue.id).update({
                      'title': tEdit.text,
                      'description': dEdit.text,
                      'category': selectedCategory,
                      'street': sEdit.text,
                      'region': selectedRegion,
                      'attachmentUrl': finalUrl,
                      'isVideo': finalIsVideo,
                    });

                    if (mounted) Navigator.pop(context);
                  },
                  child: _isUploading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Save Changes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<String?> showModalActionSheet(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.image), title: const Text('Photo'), onTap: () => Navigator.pop(context, 'image')),
            ListTile(leading: const Icon(Icons.videocam), title: const Text('Video'), onTap: () => Navigator.pop(context, 'video')),
          ],
        ),
      ),
    );
  }

  // --- UPDATED REPLY SHEET ---
  void _showReplySheet({String? pId, String? rName}) {
    _commentController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(rName != null ? "Replying to @$rName" : "Write a comment", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _commentController, 
              autofocus: true, 
              decoration: const InputDecoration(hintText: "Type something helpful...")
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
              onPressed: () async {
                if (_commentController.text.isEmpty) return;
                await _issueService.postComment(widget.issue.id, _commentController.text, parentId: pId, replyToName: rName);
                if (mounted) Navigator.pop(context);
              },
              child: const Text("Post Comment"),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
