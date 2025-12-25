import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/issue_model.dart'; 
import '../models/comment_model.dart'; // Make sure this model file is created

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

  // FR-6: Fetch issues for Home Screen
  Stream<List<Issue>> getIssues() {
    return _db.collection('Issues')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Issue.fromFirestore(doc))
            .toList());
  }

  // FR-5: Media Upload
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

  // FR-8: Voting
  Future<void> voteForIssue(String issueId) async {
    try {
      await _db.collection('Issues').doc(issueId).update({
        'voteCount': FieldValue.increment(1),
      });
    } catch (e) {
      print("Error voting: $e");
    }
  }

  // FR-4: Create Issue
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

  // --- DISCUSSION/COMMENT METHODS ---

  // Post a comment (John) or a linked reply (Alexa/Jack)
  Future<void> postComment(String issueId, String text, {String? parentId, String? replyToName}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _db.collection('Comments').add({
        'issueId': issueId,
        'userId': user.uid,
        'userName': user.email?.split('@')[0] ?? 'User',
        'text': text,
        'parentId': parentId,      // This links Alexa to John, or Jack to Alexa
        'replyToName': replyToName, // Used for the "@Alexa" redirect label
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error posting comment: $e");
    }
  }

  // Stream comments in order so the "Jump to Parent" logic works correctly
  Stream<List<Comment>> getComments(String issueId) {
    return _db.collection('Comments')
        .where('issueId', isEqualTo: issueId)
        .orderBy('createdAt', descending: false) // Oldest first for chronological reading
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Comment.fromFirestore(doc))
            .toList());
  }
}