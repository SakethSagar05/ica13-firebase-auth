import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'authentication_screen.dart';
import 'profile_screen.dart';

/// Chooses the screen from Firebase auth state.
///
/// Signed in  -> ProfileScreen (protected)
/// Signed out -> AuthenticationScreen
///
/// Because the protected screen is only ever built from this stream (no
/// Navigator.push after sign-in), signing out swaps it away immediately and
/// there is no back-stack entry that leads back into the profile.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.authService});

  final AuthService? authService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // One service + one cached stream for the life of the app.
  late final AuthService _authService = widget.authService ?? AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Checking sign-in status...'),
                ],
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Unable to check sign-in status. Restart the app and try again.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        final user = snapshot.data;
        if (user != null) {
          return ProfileScreen(key: ValueKey(user.uid), authService: _authService);
        }
        return AuthenticationScreen(authService: _authService);
      },
    );
  }
}
