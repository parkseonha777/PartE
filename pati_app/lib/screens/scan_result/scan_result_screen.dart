import 'package:flutter/material.dart';
import '../alternative/alternative_screen.dart';

class ScanResultScreen extends StatelessWidget {
  final String imagePath;
  const ScanResultScreen({super.key, required this.imagePath});

  // 임시 Mock 데이터 (Step 5에서 실제 API로 교체)
  final List<Map<String, dynamic>> _mockIngredients = const [
    {'name': '계란', 'level': 'danger'},
    {'name': '우유', 'level': 'danger'},
    {'name': '밀', 'level': 'caution'},
    {'name': '설탕', 'level': 'safe'},
    {'name': '소금', 'level': 'safe'},
  ];

  Color _getRiskColor(String level) {
    switch (level) {
      case 'danger':
        return Colors.red;
      case 'caution':
        return Colors.amber;
      case 'safe':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getRiskLabel(String level) {
    switch (level) {
      case 'danger':
        return '위험';
      case 'caution':
        return '주의';
      case 'safe':
        return '안전';
      default:
        return '알 수 없음';
    }
  }

  IconData _getRiskIcon(String level) {
    switch (level) {
      case 'danger':
        return Icons.dangerous;
      case 'caution':
        return Icons.warning_amber;
      case 'safe':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dangerList =
        _mockIngredients.where((e) => e['level'] == 'danger').toList();
    final cautionList =
        _mockIngredients.where((e) => e['level'] == 'caution').toList();
    final safeList =
        _mockIngredients.where((e) => e['level'] == 'safe').toList();
    final sortedList = [...dangerList, ...cautionList, ...safeList];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('분석 결과',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 요약 배너
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: dangerList.isNotEmpty
                ? Colors.red[50]
                : Colors.green[50],
            child: Row(
              children: [
                Icon(
                  dangerList.isNotEmpty
                      ? Icons.warning_rounded
                      : Icons.check_circle,
                  color: dangerList.isNotEmpty ? Colors.red : Colors.green,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  dangerList.isNotEmpty
                      ? '⚠️ 위험 성분 ${dangerList.length}개 발견!'
                      : '✅ 안전한 식품입니다!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color:
                        dangerList.isNotEmpty ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
          ),

          // 성분 리스트
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedList.length,
              itemBuilder: (context, index) {
                final item = sortedList[index];
                final color = _getRiskColor(item['level']);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: color, width: 1.5),
                  ),
                  child: ListTile(
                    leading: Icon(_getRiskIcon(item['level']),
                        color: color, size: 32),
                    title: Text(item['name'],
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getRiskLabel(item['level']),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 대체 식품 보기 버튼
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
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
                      builder: (context) => const AlternativeScreen(
                        dangerIngredient: '계란',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.swap_horiz),
                label: const Text('대체 식품 보기',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}