import 'package:cloud_firestore/cloud_firestore.dart';

class Issue {
  final String id;
  final String title;
  final String description;
  final String category; // e.g., Water, Electric, Roads
  final String region;   // e.g., Addis Ababa, Oromia, Amhara
  final String street;   // New: Specific street name or landmark
  final String? attachmentUrl; 
  final String status; 
  final int voteCount;
  final List<String> votedUids; 
  final String createdBy;
  final DateTime createdAt;

  Issue({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.region,
    required this.street, // Added street
    this.attachmentUrl,
    required this.status,
    required this.voteCount,
    required this.votedUids, 
    required this.createdBy,
    required this.createdAt,
  });

  factory Issue.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Issue(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? 'General',
      region: data['region'] ?? 'Unknown',
      street: data['street'] ?? 'No street provided', // Added street parsing
      attachmentUrl: data['attachmentUrl'], 
      status: data['status'] ?? 'Open',
      voteCount: data['voteCount'] ?? 0,
      votedUids: List<String>.from(data['votedUids'] ?? []), 
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'region': region,
      'street': street, // Added street for Firestore
      'attachmentUrl': attachmentUrl, 
      'status': status,
      'voteCount': voteCount,
      'votedUids': votedUids, 
      'createdBy': createdBy,
      'createdAt': createdAt,
    };
  }

  Issue copyWith({
    String? status,
    int? voteCount,
    List<String>? votedUids,
    String? category,
    String? region,
    String? street, // Added street to copyWith
  }) {
    return Issue(
      id: id,
      title: title,
      description: description,
      category: category ?? this.category,
      region: region ?? this.region,
      street: street ?? this.street,
      attachmentUrl: attachmentUrl,
      status: status ?? this.status,
      voteCount: voteCount ?? this.voteCount,
      votedUids: votedUids ?? this.votedUids, 
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }
}