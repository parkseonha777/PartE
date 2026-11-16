import 'package:flutter/material.dart';
import 'home_theme.dart';

/// 이용 안내: 결과 보는 법과 데이터 출처
class GuideInfoScreen extends StatelessWidget {
  const GuideInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('이용 안내',
            style: TextStyle(
                color: HomeColors.text, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: HomeColors.text),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _SectionTitle('결과는 이렇게 알려드려요'),
          _LevelRow(
            color: Color(0xFFD32F2F),
            label: '위험',
            text: '내가 선택한 알레르기 성분이 원재료에 포함되어 있어요',
          ),
          _LevelRow(
            color: Color(0xFFF57C00),
            label: '주의',
            text: '원재료로는 확인되지 않지만 성분표에 혼입 가능성 문구가 있어요',
          ),
          _LevelRow(
            color: Color(0xFF43A047),
            label: '안전',
            text: '내가 선택한 성분이 확인되지 않았어요',
          ),
          SizedBox(height: 24),
          _SectionTitle('데이터 출처'),
          _BodyText('알레르기 표시 기준: 식품 등의 표시·광고에 관한 법률 시행규칙 [별표 2]'),
          SizedBox(height: 24),
          _SectionTitle('꼭 확인해 주세요'),
          _BodyText('위 정보는 제품 포장지 성분표를 기반으로 제공되며, 제조사 사정에 따라 변경될 수 있습니다.'),
          _BodyText('개인 알레르기 반응은 다를 수 있으니 섭취 전 반드시 확인하세요.'),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text,
          style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: HomeColors.text)),
    );
  }
}

class _BodyText extends StatelessWidget {
  final String text;
  const _BodyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 14, height: 1.5, color: HomeColors.sub)),
    );
  }
}

class _LevelRow extends StatelessWidget {
  final Color color;
  final String label;
  final String text;
  const _LevelRow(
      {required this.color, required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 14, height: 1.5, color: HomeColors.text)),
          ),
        ],
      ),
    );
  }
}