import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import '../../services/issue_service.dart';

class AddIssueScreen extends StatefulWidget {
  const AddIssueScreen({super.key});
  @override
  State<AddIssueScreen> createState() => _AddIssueScreenState();
}

class _AddIssueScreenState extends State<AddIssueScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _streetController = TextEditingController();
  final IssueService _issueService = IssueService();
  final Color primaryColor = const Color(0xFF3F51B5);
  
  File? _selectedFile;
  bool _isVideo = false; 
  bool _isUploading = false;

  String? _selectedCategory;
  String? _selectedRegion;

  final List<String> _sectors = ['Water', 'Electric', 'Roads', 'Waste', 'Telecom'];
  final List<String> _regions = ['Addis Ababa', 'Oromia', 'Amhara', 'Sidama', 'Tigray', 'Dire Dawa'];

  // This method is now correctly triggered with the isVideo flag
  Future<void> _pickFile(ImageSource source, bool isVideo) async {
    final picker = ImagePicker();
    try {
      final pickedFile = isVideo 
          ? await picker.pickVideo(source: source)
          : await picker.pickImage(source: source);

      if (pickedFile != null) {
        setState(() {
          _selectedFile = File(pickedFile.path);
          _isVideo = isVideo; 
        });
      }
    } catch (e) {
      debugPrint("Error picking file: $e");
    }
  }

  // Helper to show a choice between Image and Video
  void _showPickerOptions(ImageSource source) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.image, color: primaryColor),
              title: const Text('Pick Image'),
              onTap: () {
                Navigator.pop(context);
                _pickFile(source, false);
              },
            ),
            ListTile(
              leading: Icon(Icons.videocam, color: primaryColor),
              title: const Text('Pick Video'),
              onTap: () {
                Navigator.pop(context);
                _pickFile(source, true);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _submitIssue() async {
    if (_titleController.text.isEmpty || 
        _selectedCategory == null || 
        _selectedRegion == null || 
        _streetController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all fields (Title, Sector, Region, and Street)"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);
    
    String? fileUrl;
    try {
      if (_selectedFile != null) {
        fileUrl = await _issueService.uploadToCloudinary(_selectedFile!, _isVideo);
      }

      final String issueId = await _issueService.createIssue(
        _titleController.text,
        _descController.text,
        fileUrl,
        category: _selectedCategory!,
        region: _selectedRegion!,
        street: _streetController.text.trim(),
      );

      await FirebaseFirestore.instance.collection('Notifications').add({
        'title': 'New $_selectedCategory Issue',
        'body': '${_titleController.text} at ${_streetController.text.trim()}',
        'sector': _selectedCategory,
        'region': _selectedRegion,
        'issueId': issueId,
        'type': 'new_issue',
        'timestamp': FieldValue.serverTimestamp(),
        'readBy': [], 
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Issue reported successfully!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context); 
      }
    } catch (e) {
      debugPrint("Error submitting issue: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Submission failed: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: primaryColor),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Report Issue", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader("Basic Information"),
                TextField(controller: _titleController, decoration: _inputStyle("Issue Title (e.g. Water Leak)", Icons.title)),
                const SizedBox(height: 15),
                TextField(controller: _descController, maxLines: 3, decoration: _inputStyle("Detailed Description", Icons.description)),
                
                const SizedBox(height: 25),
                _sectionHeader("Location Details"),
                TextField(
                  controller: _streetController, 
                  decoration: _inputStyle("Street Name / Landmark", Icons.location_on),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  initialValue: _selectedRegion,
                  decoration: _inputStyle("Region", Icons.map),
                  items: _regions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (val) => setState(() => _selectedRegion = val),
                ),
                
                const SizedBox(height: 25),
                _sectionHeader("Department / Sector"),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: _inputStyle("Responsible Sector", Icons.business_center),
                  items: _sectors.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) => setState(() => _selectedCategory = val),
                ),
                
                const SizedBox(height: 25),
                _sectionHeader("Evidence (Image or Video)"),
                _buildFilePicker(),
                
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _isUploading ? null : _submitIssue,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 55),
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 0,
                  ),
                  child: const Text("SUBMIT REPORT", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
          if (_isUploading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor.withOpacity(0.8))),
    );
  }

  Widget _buildFilePicker() {
    if (_selectedFile != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: primaryColor.withOpacity(0.2))),
        child: Row(
          children: [
            Icon(_isVideo ? Icons.videocam : Icons.image, color: primaryColor),
            const SizedBox(width: 12),
            Expanded(child: Text("Selected: ${_selectedFile!.path.split('/').last}", style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
            IconButton(icon: const Icon(Icons.cancel, color: Colors.redAccent), onPressed: () => setState(() => _selectedFile = null)),
          ],
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: _outlinedPickerButton("Gallery", Icons.photo_library, () => _showPickerOptions(ImageSource.gallery)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _outlinedPickerButton("Camera", Icons.camera_alt, () => _showPickerOptions(ImageSource.camera)),
        ),
      ],
    );
  }

  Widget _outlinedPickerButton(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 15),
        side: BorderSide(color: primaryColor.withOpacity(0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        foregroundColor: primaryColor,
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(25.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: primaryColor),
                const SizedBox(height: 20),
                const Text("Uploading evidence...", style: TextStyle(fontWeight: FontWeight.bold)),
                const Text("Please wait a moment", style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}