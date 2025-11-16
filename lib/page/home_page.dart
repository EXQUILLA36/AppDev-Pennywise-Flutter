import 'package:flutter/material.dart';
import 'package:clerk_flutter/clerk_flutter.dart';
import 'auth_wrapper.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the current logged-in user
    final user = ClerkAuth.of(context).user;

    // Fetch the Clerk ID
    final clerkId = user?.id ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ClerkAuth.of(context).signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AuthWrapper()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome to Pennywise!'),
            const SizedBox(height: 20),
            Text('Your Clerk ID: $clerkId'),
          ],
        ),
      ),
    );
  }
}
