import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String issueId;
  final String userId;
  final String userName;
  final String text;
  final String? parentId;
  final String? replyToName;
  final DateTime createdAt;
  final bool isEdited; // Added this

  Comment({
    required this.id,
    required this.issueId,
    required this.userId,
    required this.userName,
    required this.text,
    this.parentId,
    this.replyToName,
    required this.createdAt,
    this.isEdited = false, // Added this
  });

  factory Comment.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Comment(
      id: doc.id,
      issueId: data['issueId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'User',
      text: data['text'] ?? '',
      parentId: data['parentId'],
      replyToName: data['replyToName'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isEdited: data['isEdited'] ?? false, // Added this
    );
  }
}