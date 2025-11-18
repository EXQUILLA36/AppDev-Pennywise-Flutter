import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'page/auth_wrapper.dart';
import 'utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'page/home_page.dart';

Future<void> main() async {

  await Firebase.initializeApp();

  runApp(const PennywiseApp());
}

class PennywiseApp extends StatelessWidget {
  const PennywiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.dark(
        background: AppColors.background,
        surface: AppColors.surface,
        primary: AppColors.accent,
        secondary: AppColors.cta,
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0),
    );

    return MaterialApp(
      title: 'Pennywise',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: const AuthWrapper(),
      routes: {
        '/home': (context) => const HomePage(),
      },
    );
  }
}
