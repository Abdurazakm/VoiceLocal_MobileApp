import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:voicelocal/services/auth_service.dart';
import 'firebase_options.dart';

// Import screens according to your defined folder structure
import 'package:voicelocal/screens/auth/login_screen.dart';
import 'package:voicelocal/screens/user/home_screen.dart';

// COMMENTED OUT UNTIL FILE IS CREATED:
// import 'package:voicelocal/screens/admin/admin_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const VoiceLocalApp());
}

class VoiceLocalApp extends StatelessWidget {
  const VoiceLocalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoiceLocal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        return FutureBuilder<String>(
          future: authService.getUserRole(snapshot.data!.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Route to Admin Dashboard if the role is 'admin'
            if (roleSnapshot.data == 'admin') {
              // Using a placeholder until the file exists to prevent errors
              return const PlaceholderAdminDashboard();
            }

            // Default route for standard users
            return const UserHome();
          },
        );
      },
    );
  }
}

// TEMPORARY PLACEHOLDER FOR ADMIN DASHBOARD
class PlaceholderAdminDashboard extends StatelessWidget {
  const PlaceholderAdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Dashboard")),
      body: const Center(child: Text("Admin Dashboard coming soon!")),
    );
  }
}