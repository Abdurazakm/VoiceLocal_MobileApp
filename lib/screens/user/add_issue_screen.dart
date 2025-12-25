import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/issue_service.dart';

class AddIssueScreen extends StatefulWidget {
  const AddIssueScreen({super.key});
  @override
  State<AddIssueScreen> createState() => _AddIssueScreenState();
}

class _AddIssueScreenState extends State<AddIssueScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final IssueService _issueService = IssueService();
  
  File? _selectedFile;
  bool _isVideo = false; // Added to track file type for Cloudinary
  bool _isUploading = false;

  // Handles picking media as required by FR-4
  Future<void> _pickFile(ImageSource source, bool isVideo) async {
    final picker = ImagePicker();
    final pickedFile = isVideo 
        ? await picker.pickVideo(source: source)
        : await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _selectedFile = File(pickedFile.path);
        _isVideo = isVideo; // Store the type so Cloudinary handles it correctly
      });
    }
  }

  // Implements FR-5: Submit issue with media link
  void _submitIssue() async {
    if (_titleController.text.isEmpty) return;

    setState(() => _isUploading = true);
    
    String? fileUrl;
    try {
      if (_selectedFile != null) {
        // Updated to use the Cloudinary upload method with role-based folder logic
        fileUrl = await _issueService.uploadToCloudinary(_selectedFile!, _isVideo);
      }

      // Stores issue details in Firestore as per FR-5
      await _issueService.createIssue(
        _titleController.text,
        _descController.text,
        fileUrl,
      );
    } catch (e) {
      debugPrint("Error submitting issue: $e");
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
        Navigator.pop(context); // Return to home_screen
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Report Issue")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // FR-4: Providing details for the issue
            TextField(
              controller: _titleController, 
              decoration: const InputDecoration(labelText: "Issue Title")
            ),
            TextField(
              controller: _descController, 
              decoration: const InputDecoration(labelText: "Description"), 
              maxLines: 3
            ),
            const SizedBox(height: 20),
            
            // Visual feedback for selected attachment
            _selectedFile != null 
                ? Column(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      Text("File Ready: ${_selectedFile!.path.split('/').last}"),
                    ],
                  )
                : const Text("No media attached (optional)"),
            
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickFile(ImageSource.gallery, false),
                  icon: const Icon(Icons.image),
                  label: const Text("Add Image"),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickFile(ImageSource.gallery, true),
                  icon: const Icon(Icons.videocam),
                  label: const Text("Add Video"),
                ),
              ],
            ),
            const SizedBox(height: 30),
            
            // Uploading state prevents double submission
            _isUploading 
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _submitIssue,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50)
                    ),
                    child: const Text("Submit Community Report"),
                  ),
          ],
        ),
      ),
    );
  }
}