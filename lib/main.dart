import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:voicelocal/services/auth_service.dart';
import 'package:voicelocal/models/user_model.dart';
import 'firebase_options.dart';

// Import screens according to your defined folder structure
import 'package:voicelocal/screens/auth/login_screen.dart';
import 'package:voicelocal/screens/user/home_screen.dart';
import 'package:voicelocal/screens/admin/admin_dashboard.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
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
        // 1. If not logged in, show Login Screen
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // 2. Fetch the full UserModel to check roles and jurisdictions (FR-11, FR-13)
        return FutureBuilder<UserModel?>(
          future: authService.getUserModel(snapshot.data!.uid), 
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final user = userSnapshot.data;

            if (user == null) {
              return const LoginScreen(); // Safety fallback
            }

            // 3. Routing Logic based on SRS Roles
            // If the role is sector_admin or super_admin, go to Admin Dashboard
            if (user.role == 'sector_admin' || user.role == 'super_admin') {
              return AdminDashboard(currentUser: user);
            }

            // Default route for standard "user" role (Resident side)
            return const UserHome();
          },
        );
      },
    );
  }
}