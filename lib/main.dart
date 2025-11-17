import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clerk_flutter/clerk_flutter.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(
    ProviderScope(
      child: ClerkAuth(
        config: ClerkAuthConfig(
          // <-- replace this with your real publishable key
          publishableKey: "pk_test_cmVuZXdlZC1sYWJyYWRvci03Mi5jbGVyay5hY2NvdW50cy5kZXYk",
        ),
        child: const PennywiseApp(),
      ),
    ),
  );
}
