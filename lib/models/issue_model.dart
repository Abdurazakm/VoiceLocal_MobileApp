import 'package:cloud_firestore/cloud_firestore.dart';

class Issue {
  final String id;
  final String title;
  final String description;
  final String category;
  final String region;
  final String street;
  final String? attachmentUrl;
  final bool isVideo;
  final String status;
  final int voteCount;
  final int commentCount; // NEW FIELD
  final List<String> votedUids;
  final String createdBy;
  final DateTime createdAt;

  Issue({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.region,
    required this.street,
    this.attachmentUrl,
    this.isVideo = false,
    required this.status,
    required this.voteCount,
    required this.commentCount, // ADDED
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
      street: data['street'] ?? 'No street provided',
      attachmentUrl: data['attachmentUrl'],
      isVideo: data['isVideo'] ?? false,
      status: data['status'] ?? 'Open',
      voteCount: data['voteCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0, // PARSING NEW FIELD
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
      'street': street,
      'attachmentUrl': attachmentUrl,
      'status': status,
      'voteCount': voteCount,
      'commentCount': commentCount, // ADDED TO MAP
      'votedUids': votedUids,
      'createdBy': createdBy,
      'createdAt': createdAt,
    };
  }

  // Updated copyWith to include commentCount
  Issue copyWith({
    String? status,
    int? voteCount,
    int? commentCount,
    List<String>? votedUids,
    String? category,
    String? region,
    String? street,
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
      commentCount: commentCount ?? this.commentCount,
      votedUids: votedUids ?? this.votedUids,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }
}