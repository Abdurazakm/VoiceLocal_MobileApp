import 'package:cloud_firestore/cloud_firestore.dart';

class SeedService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final List<String> _userIds = [
    "2LnW3j0935fdYzwsVQU0WCMKGLb2",
    "J7mdYEosNBSMGiwuNFDzmANzRgH3",
    "LUbt88ZS57PGKAfScOnW3WkwRaS2",
    "Uq9vpbxe3YdvNwJuNeFoOWs5Mws1"
  ];

  final List<String> _names = ["Abdurazak", "Mulugeta", "Selam", "Dawit"];

  Future<void> seedIssuesWithComments() async {
    final List<Map<String, dynamic>> dummyIssues = [
      {'title': 'Transformer Explosion - Bole Atlas', 'description': 'The transformer caught fire near Shala Park.', 'category': 'Electric', 'region': 'Addis Ababa', 'street': 'Bole Atlas', 'status': 'Open', 'voteCount': 156, 'comments': [{'text': 'Is the power back?', 'userIndex': 1}, {'text': 'Workers are on site.', 'userIndex': 2}]},
      {'title': 'Fibre Optic Cut - Megenagna', 'description': 'Main internet line cut.', 'category': 'Telecom', 'region': 'Addis Ababa', 'street': 'Megenagna', 'status': 'In Progress', 'voteCount': 312, 'comments': [{'text': 'Internet down.', 'userIndex': 0}]},
      {'title': 'Sewerage Overflow - Piazza', 'description': 'Old pipes burst near post office.', 'category': 'Waste', 'region': 'Addis Ababa', 'street': 'Cunningham St', 'status': 'Open', 'voteCount': 45, 'comments': [{'text': 'Bad smell.', 'userIndex': 2}]},
      {'title': 'Main Water Line Burst - Adama', 'description': 'Clean water wasting into shops.', 'category': 'Water', 'region': 'Oromia', 'street': 'Market Road', 'status': 'In Progress', 'voteCount': 88, 'comments': [{'text': 'Third time this month!', 'userIndex': 3}]},
      {'title': 'Road Erosion - Bishoftu', 'description': 'Heavy rain washed away road.', 'category': 'Roads', 'region': 'Oromia', 'street': 'Lake Front Drive', 'status': 'Open', 'voteCount': 190, 'comments': []},
      {'title': 'High Voltage Line Down - Bahir Dar', 'description': 'Cable lying on ground.', 'category': 'Electric', 'region': 'Amhara', 'street': 'Lake Side Way', 'status': 'Open', 'voteCount': 210, 'comments': [{'text': 'Dangerous!', 'userIndex': 0}]},
      {'title': 'Bridge Crack - Blue Nile', 'description': 'Significant structural crack.', 'category': 'Roads', 'region': 'Amhara', 'street': 'Nile Bridge Hwy', 'status': 'Open', 'voteCount': 560, 'comments': [{'text': 'Safe for trucks?', 'userIndex': 3}]},
      {'title': 'Internet Signal Loss - Mekelle', 'description': 'Tower signal low for 3 days.', 'category': 'Telecom', 'region': 'Tigray', 'street': 'Airport Rd', 'status': 'Open', 'voteCount': 42, 'comments': []},
      {'title': 'Sanitation Truck Delay', 'description': 'Waste collection delayed 2 weeks.', 'category': 'Waste', 'region': 'Tigray', 'street': 'Romanat Square', 'status': 'In Progress', 'voteCount': 29, 'comments': []},
      {'title': 'Water Pump Failure - Hawassa', 'description': 'Main pump failed.', 'category': 'Water', 'region': 'Sidama', 'street': 'Tabor Hill Rd', 'status': 'Resolved', 'voteCount': 120, 'comments': [{'text': 'Back now.', 'userIndex': 0}]},
      {'title': 'Street Light Outage - Hawassa', 'description': 'Entire street dark.', 'category': 'Electric', 'region': 'Sidama', 'street': 'Lake Side Path', 'status': 'Open', 'voteCount': 18, 'comments': []},
      {'title': 'Railway Drainage Blocked', 'description': 'Sand filled drainage pipes.', 'category': 'Roads', 'region': 'Dire Dawa', 'street': 'Ashelwa', 'status': 'Open', 'voteCount': 55, 'comments': []},
      {'title': 'Telecom Cable Vandalism', 'description': 'Copper wires stolen.', 'category': 'Telecom', 'region': 'Dire Dawa', 'street': 'Industries Zone', 'status': 'Open', 'voteCount': 74, 'comments': []},
      {'title': 'Chemical Waste Spill', 'description': 'Liquid flowing into stream.', 'category': 'Waste', 'region': 'Addis Ababa', 'street': 'Akaki Kaliti', 'status': 'Open', 'voteCount': 240, 'comments': [{'text': 'Gray water!', 'userIndex': 1}]},
      {'title': 'Low Water Pressure', 'description': 'No pressure even at night.', 'category': 'Water', 'region': 'Amhara', 'street': 'Gondar Center', 'status': 'In Progress', 'voteCount': 67, 'comments': []},
    ];

    print("--- Starting Seed Process: Total ${dummyIssues.length} items ---");

    for (int i = 0; i < dummyIssues.length; i++) {
      final issueData = dummyIssues[i];
      
      try {
        // 1. Generate a new document reference with a unique ID
        DocumentReference issueRef = _db.collection('Issues').doc(); 

        // 2. Set the main Issue document
        await issueRef.set({
          'id': issueRef.id, // Store ID inside document for convenience
          'title': issueData['title'],
          'description': issueData['description'],
          'category': issueData['category'],
          'region': issueData['region'],
          'street': issueData['street'] ?? 'Unknown',
          'status': issueData['status'],
          'voteCount': issueData['voteCount'],
          'commentCount': (issueData['comments'] as List).length,
          'votedUids': [],
          'createdBy': _userIds[i % _userIds.length],
          'createdAt': FieldValue.serverTimestamp(),
          'attachmentUrl': null,
        });

        print("✅ Added Issue $i: ${issueData['title']}");

        // 3. Add Comments to the 'comments' sub-collection of THIS issue
        List comments = issueData['comments'] as List;
        if (comments.isNotEmpty) {
          for (var commentData in comments) {
            int uIdx = commentData['userIndex'];
            
            // This specifically targets: /Issues/{issueRef.id}/comments/{auto-id}
            await issueRef.collection('comments').add({
              'issueId': issueRef.id,
              'userId': _userIds[uIdx],
              'userName': _names[uIdx],
              'text': commentData['text'],
              'createdAt': FieldValue.serverTimestamp(),
              'isEdited': false,
              'parentId': null,
            });
            print("   💬 Comment added for: ${issueData['title']}");
          }
        }
      } catch (e) {
        print("❌ Error seeding Issue $i: $e");
      }
    }
    print("--- 🏁 Seeding Finished! ---");
  }
}