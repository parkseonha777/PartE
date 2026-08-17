import 'package:flutter/material.dart';
import '../camera/camera_screen.dart';
import '../../screens/history/history_screen.dart';

class ScanGuideScreen extends StatelessWidget {
  const ScanGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('팥이', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
          actions: [
    IconButton(
      icon: const Icon(Icons.history),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const HistoryScreen(),
          ),
        );
      },
    ),
  ],
),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 아이콘
            const Icon(Icons.document_scanner,
                size: 100, color: Color(0xFFE53935)),
            const SizedBox(height: 32),

            // 제목
            const Text(
              '성분표를 카메라로 촬영해주세요',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // 안내 사항
            _guideItem(Icons.light_mode, '밝은 곳에서 촬영해주세요'),
            _guideItem(Icons.crop_free, '성분표 전체가 화면에 들어오게 해주세요'),
            _guideItem(Icons.stay_current_portrait, '카메라를 흔들지 말고 고정해주세요'),
            const SizedBox(height: 40),

            // 스캔 시작 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CameraScreen(),
                    ),
                  );
                },
                child: const Text('스캔 시작',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _guideItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE53935), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}