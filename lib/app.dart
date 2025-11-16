import 'package:flutter/material.dart';
import 'page/auth_wrapper.dart';
import 'page/home_page.dart';

class PennywiseApp extends StatelessWidget {
  const PennywiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pennywise',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      home: const AuthWrapper(), // decides login or home
      routes: {
        '/home': (context) => const HomePage(),
      },
    );
  }
}
