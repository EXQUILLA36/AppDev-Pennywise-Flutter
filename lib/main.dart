import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:clerk_flutter/clerk_flutter.dart';
import 'app.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  
  runApp(
    ClerkAuth(
      config: ClerkAuthConfig(
        publishableKey: "pk_test_cmVuZXdlZC1sYWJyYWRvci03Mi5jbGVyay5hY2NvdW50cy5kZXYk", // replace with your key
      ),
      child: const PennywiseApp(),
    ),
  );
}