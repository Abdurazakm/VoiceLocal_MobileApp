import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:voicelocal/services/auth_service.dart';
import 'package:voicelocal/models/user_model.dart';
import 'firebase_options.dart';

// Import screens
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
        textTheme: GoogleFonts.robotoTextTheme(Theme.of(context).textTheme),
      ),
      // AuthGate handles all navigation based on login state
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
        // 1. Handle connection errors
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text("Authentication Error. Please restart the app.")),
          );
        }

        // 2. If user is NOT logged in, show Login Screen
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // 3. If user IS logged in, fetch their role from Firestore
        return FutureBuilder<UserModel?>(
          future: authService.getUserModel(snapshot.data!.uid),
          builder: (context, userSnapshot) {
            // Show loading while fetching user role
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final user = userSnapshot.data;

            // Safety check: if Firebase Auth is active but user document is missing
            if (user == null) {
              FirebaseAuth.instance.signOut();
              return const LoginScreen();
            }

            // 4. Role-based Routing Logic
            if (user.role == 'sector_admin' || user.role == 'super_admin') {
              return AdminDashboard(currentUser: user);
            }

            // Default for regular users
            return const UserHome();
          },
        );
      },
    );
  }
}