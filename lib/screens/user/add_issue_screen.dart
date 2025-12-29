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
  final _streetController = TextEditingController(); // SRS FR-5: Precise Location
  final IssueService _issueService = IssueService();
  
  File? _selectedFile;
  bool _isVideo = false; 
  bool _isUploading = false;

  // Ethiopia Context Selection Data (SRS FR-14, FR-15)
  String? _selectedCategory;
  String? _selectedRegion;

  final List<String> _sectors = ['Water', 'Electric', 'Roads', 'Waste', 'Telecom'];
  final List<String> _regions = ['Addis Ababa', 'Oromia', 'Amhara', 'Sidama', 'Tigray', 'Dire Dawa'];

  Future<void> _pickFile(ImageSource source, bool isVideo) async {
    final picker = ImagePicker();
    final pickedFile = isVideo 
        ? await picker.pickVideo(source: source)
        : await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _selectedFile = File(pickedFile.path);
        _isVideo = isVideo; 
      });
    }
  }

  void _submitIssue() async {
    // Validation: Ensures all routing data required by the SRS is present
    if (_titleController.text.isEmpty || 
        _selectedCategory == null || 
        _selectedRegion == null || 
        _streetController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields (Title, Sector, Region, and Street)")),
      );
      return;
    }

    setState(() => _isUploading = true);
    
    String? fileUrl;
    try {
      if (_selectedFile != null) {
        // Upload to Cloudinary using the logic previously verified
        fileUrl = await _issueService.uploadToCloudinary(_selectedFile!, _isVideo);
      }

      // Create issue with all metadata for Admin routing
      await _issueService.createIssue(
        _titleController.text,
        _descController.text,
        fileUrl,
        category: _selectedCategory!,
        region: _selectedRegion!,
        street: _streetController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Issue reported successfully!")),
        );
        Navigator.pop(context); 
      }
    } catch (e) {
      debugPrint("Error submitting issue: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Submission failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Report Community Issue"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Basic Information", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _titleController, 
              decoration: const InputDecoration(labelText: "Issue Title (e.g. Broken Pipe)", border: OutlineInputBorder())
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _descController, 
              decoration: const InputDecoration(labelText: "Detailed Description", border: OutlineInputBorder()), 
              maxLines: 3
            ),
            const SizedBox(height: 25),

            const Text("Location Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _streetController, 
              decoration: const InputDecoration(
                labelText: "Street Name / Landmark", 
                hintText: "e.g. Behind Edna Mall or Near Bole High School",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_pin)
              )
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _selectedRegion,
              hint: const Text("Select Region"),
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _regions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (val) => setState(() => _selectedRegion = val),
            ),
            const SizedBox(height: 25),

            const Text("Responsible Sector", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              hint: const Text("Select Sector (e.g. Water, Electric)"),
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _sectors.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) => setState(() => _selectedCategory = val),
            ),
            const SizedBox(height: 25),

            const Text("Evidence (Image/Video)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _selectedFile != null 
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Icon(_isVideo ? Icons.videocam : Icons.image, color: Colors.blue),
                        const SizedBox(width: 10),
                        Expanded(child: Text("Ready: ${_selectedFile!.path.split('/').last}", overflow: TextOverflow.ellipsis)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _selectedFile = null)),
                      ],
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _pickFile(ImageSource.gallery, false),
                          icon: const Icon(Icons.image),
                          label: const Text("Image"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _pickFile(ImageSource.gallery, true),
                          icon: const Icon(Icons.videocam),
                          label: const Text("Video"),
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 40),
            
            _isUploading 
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _submitIssue,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 55),
                      backgroundColor: Colors.blue[900],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                    ),
                    child: const Text("SUBMIT COMMUNITY REPORT", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}