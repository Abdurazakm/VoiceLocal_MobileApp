import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StatusUpdateDialog extends StatefulWidget {
  final String issueId;
  final String currentStatus;

  const StatusUpdateDialog({
    super.key, 
    required this.issueId, 
    required this.currentStatus
  });

  @override
  State<StatusUpdateDialog> createState() => _StatusUpdateDialogState();
}

class _StatusUpdateDialogState extends State<StatusUpdateDialog> {
  late String _selectedStatus;
  bool _isUpdating = false;

  final List<String> _statusOptions = [
    'Pending',
    'In Review',
    'In Progress',
    'Resolved',
    'Closed'
  ];

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.currentStatus;
  }

  Future<void> _updateStatus() async {
    setState(() => _isUpdating = true);
    try {
      await FirebaseFirestore.instance
          .collection('Issues')
          .doc(widget.issueId)
          .update({
        'status': _selectedStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Update failed: $e");
      setState(() => _isUpdating = false);
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
            onChanged: (val) => setState(() => _selectedStatus = val!),
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _isUpdating ? null : _updateStatus,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3F51B5),
            foregroundColor: Colors.white,
          ),
          child: _isUpdating 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text("Update"),
        ),
      ],
    );
  }
}