// File path: lib/screens/admin/status_update_dialog.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StatusUpdateDialog extends StatefulWidget {
  final String issueId;
  final String currentStatus;

  const StatusUpdateDialog({
    super.key,
    required this.issueId,
    required this.currentStatus,
  });

  @override
  State<StatusUpdateDialog> createState() => _StatusUpdateDialogState();
}

class _StatusUpdateDialogState extends State<StatusUpdateDialog> {
  late String _selectedStatus;
  
  // Status options defined in SRS Section 8.2 
  final List<String> _statusOptions = ["Open", "In Review", "Resolved"];

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.currentStatus;
  }

  Future<void> _updateStatus() async {
    try {
      await FirebaseFirestore.instance
          .collection('Issues')
          .doc(widget.issueId)
          .update({'status': _selectedStatus}); // Implementation of FR-9 [cite: 96]

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Status updated to $_selectedStatus")),
        );
      }
    } catch (e) {
      debugPrint("Error updating status: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Update Issue Status"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: _statusOptions.map((status) {
          return RadioListTile<String>(
            title: Text(status),
            value: status,
            groupValue: _selectedStatus,
            onChanged: (value) {
              setState(() => _selectedStatus = value!);
            },
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _updateStatus,
          child: const Text("Update"),
        ),
      ],
    );
  }
}