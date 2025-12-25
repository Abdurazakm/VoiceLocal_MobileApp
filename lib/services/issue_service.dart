import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/issue_model.dart'; 
import '../models/comment_model.dart';

class IssueService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cloudinary Configuration
  final cloudinary = CloudinaryPublic(
    'dqokyquo6', 
    'voicelocal_preset', 
    cache: false,
  );

  // --- ISSUE METHODS ---

  Stream<List<Issue>> getIssues() {
    return _db.collection('Issues')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Issue.fromFirestore(doc))
            .toList());
  }

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
      print("Cloudinary Error: $e");
      return null;
    }
  }

  Future<void> voteForIssue(String issueId) async {
    try {
      await _db.collection('Issues').doc(issueId).update({
        'voteCount': FieldValue.increment(1),
      });
    } catch (e) {
      print("Error voting: $e");
    }
  }

  Future<void> createIssue(String title, String description, String? fileUrl) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db.collection('Issues').add({
      'title': title,
      'description': description,
      'attachmentUrl': fileUrl,
      'status': 'Open',
      'voteCount': 0,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // UPDATED: Delete Issue
  Future<void> deleteIssue(String issueId) async {
    try {
      await _db.collection('Issues').doc(issueId).delete();
    } catch (e) {
      print("Error deleting issue: $e");
    }
  }

  // NEW FEATURE: Update Issue
  Future<void> updateIssue(String issueId, String newTitle, String newDescription) async {
    try {
      await _db.collection('Issues').doc(issueId).update({
        'title': newTitle,
        'description': newDescription,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error updating issue: $e");
    }
  }

  // --- DISCUSSION/COMMENT METHODS ---

  Future<void> postComment(String issueId, String text, {String? parentId, String? replyToName}) async {
    try {
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
    } catch (e) {
      print("Error posting comment: $e");
    }
  }

  Future<void> updateComment(String commentId, String newText) async {
    try {
      await _db.collection('Comments').doc(commentId).update({
        'text': newText,
        'isEdited': true,
      });
    } catch (e) {
      print("Error updating comment: $e");
    }
  }

  Future<void> deleteComment(String commentId) async {
    try {
      await _db.collection('Comments').doc(commentId).delete();
    } catch (e) {
      print("Error deleting comment: $e");
    }
  }

  Stream<List<Comment>> getComments(String issueId) {
    return _db.collection('Comments')
        .where('issueId', isEqualTo: issueId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Comment.fromFirestore(doc))
            .toList());
  }
}