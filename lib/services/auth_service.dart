import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // FR-1: User Registration
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
        await _db.collection('Users').doc(user.uid).set({
          'uid': user.uid,
          'name': name,
          'email': email,
          'region': region,
          'street': street,
          'profilePic': "",
          'bio': "Resident of $region",
          'role': 'user',
          'assignedSector': null,
          'assignedRegion': null,
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

  // NEW: Forgot Password / Password Reset
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      print("Password Reset Error: $e");
      rethrow;
    }
  }

  // NEW: Cross-Platform Google Sign-In (Web, Android, iOS)
  // FULLY UPDATED for google_sign_in v7.2.0
  Future<UserCredential?> signInWithGoogle() async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        // Web flow: Uses Popup
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        // Mobile flow: Android & iOS
        // 1. Initialize the singleton instance (Mandatory in v7+)
        await GoogleSignIn.instance.initialize();

        // 2. Use authenticate() instead of signIn()
        final GoogleSignInAccount googleUser = await GoogleSignIn.instance.authenticate();
        
        if (googleUser == null) return null;

        // 3. authentication is a synchronous property in v7+
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;
        
        // 4. Create the credential using the idToken 
        final AuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        userCredential = await _auth.signInWithCredential(credential);
      }

      // Sync user data to Firestore if they are new
      if (userCredential.user != null) {
        await _syncGoogleUserToFirestore(userCredential.user!);
      }

      return userCredential;
    } on GoogleSignInException catch (e) {
      print("Google Sign-In Error Code: ${e.code}");
      return null;
    } catch (e) {
      print("Global Google Sign-In Error: $e");
      rethrow;
    }
  }

  // Helper: Ensures Google users have a Firestore document
  Future<void> _syncGoogleUserToFirestore(User user) async {
    final docRef = _db.collection('Users').doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'uid': user.uid,
        'name': user.displayName ?? "New User",
        'email': user.email,
        'region': "", 
        'street': "", 
        'profilePic': user.photoURL ?? "",
        'bio': "Community Member",
        'role': 'user',
        'assignedSector': null,
        'assignedRegion': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Fetch specific UserModel for routing/dashboard context
  Future<UserModel?> getUserModel(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('Users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
    } catch (e) {
      print("Error fetching user model: $e");
    }
    return null;
  }

  // Stream of all users for the Super Admin Management Screen
  Stream<List<UserModel>> getAllUsers() {
    return _db.collection('Users').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Super Admin promoting a user
  Future<void> promoteUserToAdmin({
    required String targetUid,
    required String role,
    String? sector,
    String? region,
  }) async {
    try {
      await _db.collection('Users').doc(targetUid).update({
        'role': role,
        'assignedSector': sector,
        'assignedRegion': region,
      });
    } catch (e) {
      print("Promotion Error: $e");
      rethrow;
    }
  }

  // FR-3: Logout (Handles both Google and Email)
  Future<void> logout() async {
    try {
      if (!kIsWeb) {
        await GoogleSignIn.instance.signOut();
      }
    } catch (e) {
      print("Google Sign-Out Error: $e");
    }
    await _auth.signOut();
  }

  // Update profile with location data
  Future<void> updateUserProfile(
    String uid, {
    String? name,
    String? bio,
    String? profilePic,
    String? region,
    String? street,
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
