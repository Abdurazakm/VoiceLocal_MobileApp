import 'package:cloud_firestore/cloud_firestore.dart';

class Issue {
  final String id;
  final String title;
  final String description;
  final String? attachmentUrl; 
  final String status; 
  final int voteCount;
  final List<String> votedUids; // ADDED: To track who voted
  final String createdBy;
  final DateTime createdAt;

  Issue({
    required this.id,
    required this.title,
    required this.description,
    this.attachmentUrl,
    required this.status,
    required this.voteCount,
    required this.votedUids, // ADDED
    required this.createdBy,
    required this.createdAt,
  });

  factory Issue.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Issue(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      attachmentUrl: data['attachmentUrl'], 
      status: data['status'] ?? 'Open',
      voteCount: data['voteCount'] ?? 0,
      votedUids: List<String>.from(data['votedUids'] ?? []), // ADDED: Convert dynamic list to String list
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
      'attachmentUrl': attachmentUrl, 
      'status': status,
      'voteCount': voteCount,
      'votedUids': votedUids, // ADDED
      'createdBy': createdBy,
      'createdAt': createdAt,
    };
  }

  Issue copyWith({
    String? status,
    int? voteCount,
    List<String>? votedUids, // ADDED
  }) {
    return Issue(
      id: id,
      title: title,
      description: description,
      attachmentUrl: attachmentUrl,
      status: status ?? this.status,
      voteCount: voteCount ?? this.voteCount,
      votedUids: votedUids ?? this.votedUids, // ADDED
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }
}