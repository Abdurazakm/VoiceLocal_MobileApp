import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String profilePic;
  final String bio;
  final String role;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.profilePic,
    required this.bio,
    required this.role,
    required this.createdAt,
  });

  // Convert Firestore data to our Model
  factory UserModel.fromMap(Map<String, dynamic> data, String id) {
    return UserModel(
      uid: id,
      name: data['name'] ?? 'No Name',
      email: data['email'] ?? '',
      profilePic: data['profilePic'] ?? '',
      bio: data['bio'] ?? '',
      role: data['role'] ?? 'user',
      // Handles Firestore Timestamp conversion to Dart DateTime
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Helper to convert Model back to Map for saving to Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'profilePic': profilePic,
      'bio': bio,
      'role': role,
      'createdAt': createdAt,
    };
  }
}