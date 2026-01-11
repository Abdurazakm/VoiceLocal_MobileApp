import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _regionController = TextEditingController();
  final _streetController = TextEditingController();
  
  final AuthService _auth = AuthService();
  bool _isLoading = false;
  
  // Visibility States
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  void _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final userCredential = await _auth.signInWithGoogle();
      if (userCredential != null && userCredential.user != null) {
        final uid = userCredential.user!.uid;
        final userDoc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
        final data = userDoc.data();

        if (data == null || (data['region'] ?? "").toString().isEmpty) {
          _showLocationBottomSheet(uid);
        } else {
          if (mounted) Navigator.pop(context);
        }
      }
    } catch (e) {
      _showError("Google Auth Failed: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showLocationBottomSheet(String uid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 28, right: 28, top: 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text("Complete Your Profile", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text("Help us connect you with your local community.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            _buildTextField(controller: _regionController, label: "Region / Sub-City", icon: Icons.map_outlined),
            _buildTextField(controller: _streetController, label: "Street Name", icon: Icons.location_on_outlined),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  if (_regionController.text.isNotEmpty && _streetController.text.isNotEmpty) {
                    await _auth.updateUserProfile(uid, region: _regionController.text.trim(), street: _streetController.text.trim());
                    if (context.mounted) { Navigator.pop(context); Navigator.pop(context); }
                  } else {
                    _showError("Please fill both fields");
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text("Finalize Registration", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _handleRegister() async {
    if ([_nameController, _emailController, _passwordController, _regionController, _streetController].any((c) => c.text.trim().isEmpty)) {
      _showError("All fields are required");
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError("Passwords do not match");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _auth.register(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        region: _regionController.text.trim(),
        street: _streetController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message), 
      backgroundColor: Colors.redAccent, 
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.indigo)),
          const SizedBox(width: 10),
          const Expanded(child: Divider(thickness: 0.5)),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller, 
    required String label, 
    required IconData icon, 
    bool isPassword = false, 
    bool obscureText = false,
    VoidCallback? onSuffixTap,
    TextInputType type = TextInputType.text
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword ? obscureText : false,
        keyboardType: type,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.indigo[400], size: 22),
          suffixIcon: isPassword 
              ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                  onPressed: onSuffixTap,
                )
              : null,
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[200]!)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.indigo, width: 1.5)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(elevation: 0, backgroundColor: Colors.white, leading: const BackButton(color: Colors.black)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Image.asset('assets/logo.png', height: 120)),
              const SizedBox(height: 24),
              Text("Create Account", style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 8),
              Text("Sign up to start reporting and helping your local community.", style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600])),
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  onPressed: _handleGoogleSignIn,
                  icon: Image.network('https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_"G"_logo.svg/1200px-Google_"G"_logo.svg.png', height: 22),
                  label: Text("Continue with Google", style: GoogleFonts.inter(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 15)),
                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), side: BorderSide(color: Colors.grey[300]!)),
                ),
              ),

              const SizedBox(height: 24),
              Center(child: Text("OR REGISTER WITH EMAIL", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1.2))),
              const SizedBox(height: 16),

              _buildSectionHeader("Personal Information"),
              _buildTextField(controller: _nameController, label: "Full Name", icon: Icons.person_outline),
              _buildTextField(controller: _emailController, label: "Email Address", icon: Icons.email_outlined, type: TextInputType.emailAddress),
              
              _buildSectionHeader("Location Details"),
              _buildTextField(controller: _regionController, label: "Region / Sub-City", icon: Icons.map_outlined),
              _buildTextField(controller: _streetController, label: "Street / Neighborhood", icon: Icons.location_on_outlined),

              _buildSectionHeader("Security"),
              _buildTextField(
                controller: _passwordController, 
                label: "Password", 
                icon: Icons.lock_outline, 
                isPassword: true,
                obscureText: _obscurePassword,
                onSuffixTap: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              _buildTextField(
                controller: _confirmPasswordController, 
                label: "Confirm Password", 
                icon: Icons.lock_reset_outlined, 
                isPassword: true,
                obscureText: _obscureConfirmPassword,
                onSuffixTap: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 0,
                        ),
                        child: Text("Create Account", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14),
                      children: const [
                        TextSpan(text: "Already have an account? "),
                        TextSpan(text: "Login", style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}