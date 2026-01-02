import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SystemAnalyticsScreen extends StatelessWidget {
  const SystemAnalyticsScreen({super.key});

  final Color primaryColor = const Color(0xFF1A237E); // Deep Indigo
  final Color backgroundColor = const Color(0xFFF8F9FE);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: const Text("System Analytics", 
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        centerTitle: true,
        backgroundColor: primaryColor,
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
            String status = data.containsKey('status') ? data['status'] : 'Open';
            if (status == 'Resolved') {
              resolved++;
            } else {
              pending++;
            }
          }

          double resolutionRate = total == 0 ? 0 : (resolved / total) * 100;

          return CustomScrollView(
            slivers: [
              // Styled Top Header (Matching Dashboard & User Management)
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 35),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Overall Efficiency",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${resolutionRate.toStringAsFixed(1)}%",
                        style: const TextStyle(
                          color: Colors.white, 
                          fontSize: 42, 
                          fontWeight: FontWeight.w900
                        ),
                      ),
                      const Text(
                        "Issues Resolved Successfully",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.all(20.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const Text("KEY PERFORMANCE INDICATORS", 
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 1.2)),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        _buildKPICard("Total Reports", "$total", Colors.indigo, Icons.analytics),
                        const SizedBox(width: 12),
                        _buildKPICard("Active Pending", "$pending", Colors.orange.shade800, Icons.pending_actions),
                      ],
                    ),
                    
                    const SizedBox(height: 30),
                    const Text("ISSUES BY SECTOR", 
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    
                    _buildSectorBreakdown(docs),
                    
                    const SizedBox(height: 30),
                    const Text("TASK SUMMARY", 
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    _buildStatusSummary(resolved, pending),
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKPICard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), 
              blurRadius: 10, 
              offset: const Offset(0, 4)
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color.withValues(alpha: 0.5), size: 20),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color)),
            Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectorBreakdown(List<QueryDocumentSnapshot> docs) {
    Map<String, int> sectorCounts = {};
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      String cat = data.containsKey('category') ? data['category'] : 'Uncategorized';
      sectorCounts[cat] = (sectorCounts[cat] ?? 0) + 1;
    }

    if (docs.isEmpty) return const Center(child: Text("No data available."));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: Column(
        children: sectorCounts.entries.map((entry) {
          double progress = entry.value / docs.length;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text("${entry.value} Reports", style: TextStyle(color: primaryColor, fontWeight: FontWeight.w800, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade100,
                    color: primaryColor.withValues(alpha: 0.8),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusSummary(int resolved, int pending) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: Column(
        children: [
          _summaryRow(Icons.check_circle_rounded, "Total Resolved", resolved, Colors.green.shade600),
          Divider(height: 1, color: Colors.grey.shade100, indent: 20, endIndent: 20),
          _summaryRow(Icons.bolt_rounded, "Total Pending", pending, Colors.orange.shade700),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 15),
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF263238))),
          const Spacer(),
          Text("$count", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}