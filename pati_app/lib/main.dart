import 'package:flutter/material.dart';
import 'screens/scan_guide/scan_guide_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';

void main() {
  runApp(const PatiApp());
}

class PatiApp extends StatelessWidget {
  const PatiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '팥이',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE53935)),
        useMaterial3: true,
      ),
      home: const OnboardingScreen(),
    );
  }
}