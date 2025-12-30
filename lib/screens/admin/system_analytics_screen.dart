import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SystemAnalyticsScreen extends StatelessWidget {
  const SystemAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("System Analytics"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Issues').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          
          // Data Processing with safety checks
          int total = docs.length;
          int resolved = 0;
          int pending = 0;

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            // Safeguard for status field
            String status = data.containsKey('status') ? data['status'] : 'Open';
            if (status == 'Resolved') {
              resolved++;
            } else {
              pending++;
            }
          }

          double resolutionRate = total == 0 ? 0 : (resolved / total) * 100;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Key Performance Indicators", 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    _buildKPICard("Resolution Rate", "${resolutionRate.toStringAsFixed(1)}%", Colors.green),
                    const SizedBox(width: 12),
                    _buildKPICard("Total Reports", "$total", Colors.blue),
                  ],
                ),
                const SizedBox(height: 24),

                const Text("Issues by Sector", 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                // Pass the safe data processor
                _buildSectorBreakdown(docs),
                
                const SizedBox(height: 24),
                const Text("Task Summary", 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                _buildStatusSummary(resolved, pending),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildKPICard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(fontSize: 14, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectorBreakdown(List<QueryDocumentSnapshot> docs) {
    Map<String, int> sectorCounts = {};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      // FIX: Check if key exists before accessing to prevent "Bad state" error
      String cat = data.containsKey('category') ? data['category'] : 'Uncategorized';
      sectorCounts[cat] = (sectorCounts[cat] ?? 0) + 1;
    }

    if (docs.isEmpty) return const Text("No data available to display sectors.");

    return Column(
      children: sectorCounts.entries.map((entry) {
        double progress = entry.value / docs.length;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text("${entry.value} reports"),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[200],
                color: Colors.indigo,
                minHeight: 10,
                borderRadius: BorderRadius.circular(5),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusSummary(int resolved, int pending) {
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _summaryRow(Icons.check_circle, "Resolved", resolved, Colors.green),
            const Divider(),
            _summaryRow(Icons.hourglass_empty, "Pending/Review", pending, Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 16)),
          const Spacer(),
          Text("$count", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}