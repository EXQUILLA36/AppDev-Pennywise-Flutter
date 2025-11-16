import 'package:flutter/material.dart';
import 'package:clerk_flutter/clerk_flutter.dart';
import 'home_page.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = ClerkAuth.of(context).user; // current logged-in user
    print('Current user: $user');

    if (user == null) {
      // Not logged in → show Clerk login
      return const Scaffold(
        body: SafeArea(child: ClerkAuthentication()),
      );
    } else {
      // Logged in → go to HomePage
      return const HomePage();
    }
  }
}
