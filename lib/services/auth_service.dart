import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // FR-1: User Registration
  Future<User?> register(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      User? user = result.user;

      if (user != null) {
        await _db.collection('Users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
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
          email: email, password: password);
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
  // Updated with verifyBeforeUpdateEmail for Firebase Auth 6+ compatibility
  Future<void> updateAdminCredentials(String newEmail, String newPassword) async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        // Modern Firebase way: Sends verification to the new email
        await user.verifyBeforeUpdateEmail(newEmail);
        
        // Update password
        await user.updatePassword(newPassword);
        
        // Update the email record in Firestore
        await _db.collection('Users').doc(user.uid).update({
          'email': newEmail,
        });
      } on FirebaseAuthException catch (e) {
        print("Credential Update Error: ${e.message}");
        rethrow;
      }
    }
  }

  // FR-3: Logout
  Future<void> logout() async => await _auth.signOut();
}