import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String profilePic;
  final String bio;
  
  // Roles: "user" (default), "sector_admin", "super_admin"
  final String role; 

  // Location for the community feed
  final String region; 
  final String street; 

  // Administrative Jurisdictions (SRS FR-12, FR-13)
  // These are used when role is "sector_admin" or "super_admin"
  final String? assignedSector; // e.g., "Water", "Electric", "Roads"
  final String? assignedRegion; // e.g., "Addis Ababa", "Oromia"

  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.profilePic,
    required this.bio,
    required this.role,
    required this.region,
    required this.street,
    this.assignedSector,
    this.assignedRegion,
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
      
      // Kept "user" as default to match your current implementation
      role: data['role'] ?? 'user',
      
      region: data['region'] ?? '',
      street: data['street'] ?? '',
      
      // Admin-specific fields from Firestore
      assignedSector: data['assignedSector'],
      assignedRegion: data['assignedRegion'],
      
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
      'region': region,
      'street': street,
      'assignedSector': assignedSector,
      'assignedRegion': assignedRegion,
      'createdAt': createdAt,
    };
  }
}