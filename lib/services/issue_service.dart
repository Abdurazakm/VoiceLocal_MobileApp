import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/issue_model.dart';
import '../models/comment_model.dart';

class IssueService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final cloudinary = CloudinaryPublic(
    'dqokyquo6',
    'voicelocal_preset',
    cache: false,
  );

  // --- PAGINATION METHOD (NEW) ---

  /// Fetches issues in pages of 10 for better performance.
  /// [lastDocument] is the pointer to where the previous page ended.
  Future<QuerySnapshot> getIssuesPaged({DocumentSnapshot? lastDocument, int limit = 10}) async {
    Query query = _db.collection('Issues')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return await query.get();
  }

  // --- LEGACY STREAM (Optional: Keep for small lists or admin views) ---
  Stream<List<Issue>> getIssues() {
    return _db
        .collection('Issues')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Issue.fromFirestore(doc)).toList(),
        );
  }

  // --- CLOUDINARY METHODS ---

  Future<String?> uploadToCloudinary(File file, bool isVideo) async {
    try {
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: isVideo
              ? CloudinaryResourceType.Video
              : CloudinaryResourceType.Image,
          folder: 'voicelocal_uploads',
        ),
      );
      return response.secureUrl;
    } catch (e) {
      return null;
    }
  }

  // --- ISSUE METHODS ---

  Future<void> voteForIssue(String issueId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final docRef = _db.collection('Issues').doc(issueId);
      final doc = await docRef.get();
      if (!doc.exists) return;

      List<dynamic> votedUids = doc.data()?['votedUids'] ?? [];

      if (votedUids.contains(user.uid)) {
        await docRef.update({
          'voteCount': FieldValue.increment(-1),
          'votedUids': FieldValue.arrayRemove([user.uid]),
        });
      } else {
        await docRef.update({
          'voteCount': FieldValue.increment(1),
          'votedUids': FieldValue.arrayUnion([user.uid]),
        });
      }
    } catch (e) {
      print("Error voting: $e");
    }
  }

  Future<void> createIssue(
    String title,
    String description,
    String? fileUrl, {
    required String category,
    required String region,
    required String street,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db.collection('Issues').add({
      'title': title,
      'description': description,
      'attachmentUrl': fileUrl,
      'category': category,
      'region': region,
      'street': street,
      'status': 'Open',
      'voteCount': 0,
      'commentCount': 0,
      'votedUids': [],
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateIssue(String id, String title, String desc) async {
    await _db.collection('Issues').doc(id).update({
      'title': title,
      'description': desc,
    });
  }

  Future<void> deleteIssue(String id) async {
    await _db.collection('Issues').doc(id).delete();
  }

  // --- COMMENT METHODS ---

  Future<void> postComment(
    String issueId,
    String text, {
    String? parentId,
    String? replyToName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db.collection('Comments').add({
      'issueId': issueId,
      'userId': user.uid,
      'userName': user.email?.split('@')[0] ?? 'User',
      'text': text,
      'parentId': parentId,
      'replyToName': replyToName,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('Issues').doc(issueId).update({
      'commentCount': FieldValue.increment(1),
    });
  }

  Future<void> updateComment(String id, String text) async {
    await _db.collection('Comments').doc(id).update({
      'text': text,
      'isEdited': true,
    });
  }

  Future<void> deleteComment(String commentId, String issueId) async {
    await _db.collection('Comments').doc(commentId).delete();
    await _db.collection('Issues').doc(issueId).update({
      'commentCount': FieldValue.increment(-1),
    });
  }

  Stream<List<Comment>> getComments(String issueId) {
    return _db
        .collection('Comments')
        .where('issueId', isEqualTo: issueId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snaps) =>
              snaps.docs.map((doc) => Comment.fromFirestore(doc)).toList(),
        );
  }

  // --- STATS METHODS ---

  Future<int> getTotalVotesReceived(String uid) async {
    try {
      final querySnapshot = await _db
          .collection('Issues')
          .where('createdBy', isEqualTo: uid)
          .get();

      int totalVotes = 0;
      for (var doc in querySnapshot.docs) {
        totalVotes += (doc.data()['voteCount'] ?? 0) as int;
      }
      return totalVotes;
    } catch (e) {
      return 0;
    }
  }

  Future<int> getTotalCommentsMade(String uid) async {
    try {
      final querySnapshot = await _db
          .collection('Comments')
          .where('userId', isEqualTo: uid)
          .get();
      return querySnapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }
}