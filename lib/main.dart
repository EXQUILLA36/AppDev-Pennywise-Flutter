import 'package:flutter/material.dart';
import 'package:clerk_flutter/clerk_flutter.dart';
import 'app.dart';

void main() {
  runApp(
    ClerkAuth(
      config: ClerkAuthConfig(
        publishableKey: "pk_test_cmVuZXdlZC1sYWJyYWRvci03Mi5jbGVyay5hY2NvdW50cy5kZXYk", // replace with your key
      ),
      child: const PennywiseApp(),
    ),
  );
}