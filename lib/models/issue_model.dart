import 'package:cloud_firestore/cloud_firestore.dart';

class Issue {
  final String id;
  final String title;
  final String description;
  final String? attachmentUrl; // Added: Stores the Cloudinary link
  final String status; // "Open", "In Review", "Resolved"
  final int voteCount;
  final String createdBy;
  final DateTime createdAt;

  Issue({
    required this.id,
    required this.title,
    required this.description,
    this.attachmentUrl, // Optional field
    required this.status,
    required this.voteCount,
    required this.createdBy,
    required this.createdAt,
  });

  // Convert Firestore document to Issue object
  factory Issue.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Issue(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      attachmentUrl: data['attachmentUrl'], // Maps the Firestore field
      status: data['status'] ?? 'Open',
      voteCount: data['voteCount'] ?? 0,
      createdBy: data['createdBy'] ?? '',
      // Safe check for null timestamps
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  // Convert Issue object to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'attachmentUrl': attachmentUrl, // Include in map
      'status': status,
      'voteCount': voteCount,
      'createdBy': createdBy,
      'createdAt': createdAt,
    };
  }
}