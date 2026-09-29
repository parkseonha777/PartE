import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/scan_guide/scan_guide_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';

Future<void> main() async {
  // Supabase 초기화는 runApp보다 먼저, 비동기로 끝나야 함
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zgbkqsvljfymxybrlzwk.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpnYmtxc3ZsamZ5bXh5YnJsendrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ2OTkzMTYsImV4cCI6MjEwMDI3NTMxNn0.f4JfGMLGPzdqmeUfBAjzRwmiWx4MrTw0GovuQXJo5IE',
  );

  runApp(const PatiApp());
}

// 다른 화면(login_screen.dart 등)에서 이 전역 변수로 Supabase 클라이언트에 접근
final supabase = Supabase.instance.client;

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