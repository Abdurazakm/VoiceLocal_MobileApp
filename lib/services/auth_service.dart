import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // NEW: Stream of all users for the Super Admin Management Screen
  Stream<List<UserModel>> getAllUsers() {
    return _db.collection('Users').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // FR-11, 12, 13: Super Admin promoting a user
  Future<void> promoteUserToAdmin({
    required String targetUid,
    required String role, // "sector_admin" or "super_admin"
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

  // FR-3: Logout
  Future<void> logout() async => await _auth.signOut();

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
