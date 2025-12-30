import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // FR-1: User Registration - UPDATED to include region and street
  Future<User?> register({
    required String email,
    required String password,
    required String name,
    required String region,
    required String street,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        // Storing the full profile including location data
        await _db.collection('Users').doc(user.uid).set({
          'uid': user.uid,
          'name': name,
          'email': email,
          'region': region, // NEW
          'street': street, // NEW
          'profilePic': "",
          'bio': "Resident of $region", // Updated default bio
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

  // Update user profile information - UPDATED to include location fields
  Future<void> updateUserProfile(
    String uid, {
    String? name,
    String? bio,
    String? profilePic,
    String? region, // Added
    String? street, // Added
  }) async {
    try {
      Map<String, dynamic> updates = {};
      if (name != null) updates['name'] = name;
      if (bio != null) updates['bio'] = bio;
      if (profilePic != null) updates['profilePic'] = profilePic;
      if (region != null) updates['region'] = region;
      if (street != null) updates['street'] = street;

      await _db.collection('Users').doc(uid).update(updates);
    } catch (e) {
      print("Error updating profile: $e");
      rethrow;
    }
  }
}
