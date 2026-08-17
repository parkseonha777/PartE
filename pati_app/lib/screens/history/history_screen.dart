import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  // 임시 Mock 데이터 (Step 5에서 실제 API로 교체)
  final List<Map<String, dynamic>> _mockHistory = const [
    {
      'productName': '오레오 쿠키',
      'date': '2026.08.06',
      'time': '14:32',
      'dangerCount': 2,
      'cautionCount': 1,
      'result': 'danger',
    },
    {
      'productName': '포카칩',
      'date': '2026.08.05',
      'time': '11:15',
      'dangerCount': 0,
      'cautionCount': 1,
      'result': 'caution',
    },
    {
      'productName': '허니버터칩',
      'date': '2026.08.04',
      'time': '09:00',
      'dangerCount': 0,
      'cautionCount': 0,
      'result': 'safe',
    },
  ];

  Color _getResultColor(String result) {
    switch (result) {
      case 'danger': return Colors.red;
      case 'caution': return Colors.amber;
      case 'safe': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _getResultLabel(String result) {
    switch (result) {
      case 'danger': return '위험';
      case 'caution': return '주의';
      case 'safe': return '안전';
      default: return '알 수 없음';
    }
  }

  IconData _getResultIcon(String result) {
    switch (result) {
      case 'danger': return Icons.dangerous;
      case 'caution': return Icons.warning_amber;
      case 'safe': return Icons.check_circle;
      default: return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('스캔 이력',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
      ),
      body: _mockHistory.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('스캔 이력이 없어요',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _mockHistory.length,
              itemBuilder: (context, index) {
                final item = _mockHistory[index];
                final color = _getResultColor(item['result']);
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: color, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // 결과 아이콘
                        Icon(_getResultIcon(item['result']),
                            color: color, size: 36),
                        const SizedBox(width: 16),

                        // 내용
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['productName'],
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                '${item['date']} ${item['time']}',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '위험 ${item['dangerCount']}개 · 주의 ${item['cautionCount']}개',
                                style: TextStyle(
                                    color: color,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),

                        // 결과 뱃지
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getResultLabel(item['result']),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}