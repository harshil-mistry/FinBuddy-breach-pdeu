import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/navigation/main_navigation.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: const FinBuddyApp(),
    ),
  );
}

class FinBuddyApp extends StatelessWidget {
  const FinBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinBuddy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Something went wrong!')),
          );
        }

        if (snapshot.hasData) {
          // User is logged in — check if onboarding is complete
          return const OnboardingCheckWrapper();
        }

        // User is NOT logged in
        return const LoginScreen();
      },
    );
  }
}

/// Checks Firestore to see if the user has completed onboarding.
/// Routes to OnboardingScreen or MainNavigation accordingly.
class OnboardingCheckWrapper extends StatefulWidget {
  const OnboardingCheckWrapper({super.key});

  @override
  State<OnboardingCheckWrapper> createState() => _OnboardingCheckWrapperState();
}

class _OnboardingCheckWrapperState extends State<OnboardingCheckWrapper> {
  bool? _isSetupComplete;
  bool _isLoading = true;
  bool _docMissing = false;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        // User doc doesn't exist — need to create it and go to onboarding
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'uid': user.uid,
          'displayName': user.displayName ?? '',
          'email': user.email ?? '',
          'photoUrl': user.photoURL ?? '',
          'upiId': '',
          'isSetupComplete': false,
          'recurringIncomes': [],
          'recurringExpenses': [],
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          setState(() {
            _isSetupComplete = false;
            _isLoading = false;
          });
        }
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _isSetupComplete = data['isSetupComplete'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking onboarding status: $e');
      // On error, still show onboarding to avoid being stuck
      if (mounted) {
        setState(() {
          _isSetupComplete = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const LoginScreen();

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isSetupComplete == true) {
      return const MainNavigation();
    } else {
      return const OnboardingScreen();
    }
  }
}
