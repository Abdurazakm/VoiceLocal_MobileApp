import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // FR-1: User Registration - UPDATED to include name and profile fields
  Future<User?> register(String email, String password, String name) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        // Storing the full profile structure you requested
        await _db.collection('Users').doc(user.uid).set({
          'uid': user.uid,
          'name': name,
          'email': email,
          'profilePic': "", // Default empty
          'bio': "Resident of VoiceLocal", // Default bio
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return user;
    } catch (e) {
      print("Registration Error: $e");
      rethrow;
    }
  }

  // FR-2: User Login
  Future<User?> login(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print("Login Error: $e");
      rethrow;
    }
  }

  // Get current user role from Firestore
  Future<String> getUserRole(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('Users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return (doc.data() as Map<String, dynamic>)['role'] ?? 'user';
      }
    } catch (e) {
      print("Error fetching role: $e");
    }
    return 'user';
  }

  // Admin Credential Management
  Future<void> updateAdminCredentials(
    String newEmail,
    String newPassword,
  ) async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        await user.verifyBeforeUpdateEmail(newEmail);
        await user.updatePassword(newPassword);

        await _db.collection('Users').doc(user.uid).update({'email': newEmail});
      } on FirebaseAuthException catch (e) {
        print("Credential Update Error: ${e.message}");
        rethrow;
      }
    }
  }

  // FR-3: Logout
  Future<void> logout() async => await _auth.signOut();

  // Update user profile information
  Future<void> updateUserProfile(
    String uid, {
    String? name,
    String? bio,
    String? profilePic,
  }) async {
    try {
      Map<String, dynamic> updates = {};
      if (name != null) updates['name'] = name;
      if (bio != null) updates['bio'] = bio;
      if (profilePic != null) updates['profilePic'] = profilePic;

      await _db.collection('Users').doc(uid).update(updates);
    } catch (e) {
      print("Error updating profile: $e");
      rethrow;
    }
  }
}
