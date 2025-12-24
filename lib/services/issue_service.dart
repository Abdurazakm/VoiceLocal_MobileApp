import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// IMPORTANT: Ensure this import path is correct for your project
import '../models/issue_model.dart'; 

class IssueService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Configuration with your Cloud Name
  final cloudinary = CloudinaryPublic(
    'dqokyquo6', 
    'voicelocal_preset', 
    cache: false,
  );

  // FR-6: Fetch issues as a stream for real-time updates
  // This is the method your home_screen.dart was missing!
  Stream<List<Issue>> getIssues() {
    return _db.collection('Issues')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Issue.fromFirestore(doc))
            .toList());
  }

  // FR-5: Upload to Cloudinary
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

  // FR-8: Voting logic using atomic increment
  Future<void> voteForIssue(String issueId) async {
    try {
      await _db.collection('Issues').doc(issueId).update({
        'voteCount': FieldValue.increment(1),
      });
    } catch (e) {
      print("Error voting: $e");
    }
  }

  // FR-4: Create Issue document in Firestore
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
}