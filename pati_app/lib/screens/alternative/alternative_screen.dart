import 'package:flutter/material.dart';

class AlternativeScreen extends StatelessWidget {
  final String dangerIngredient;

  const AlternativeScreen({
    super.key,
    required this.dangerIngredient,
  });

  // 임시 Mock 데이터 (Step 5에서 실제 API로 교체)
  List<Map<String, dynamic>> _getAlternatives() {
    return [
      {
        'name': '오트밀크',
        'category': '우유 대체',
        'description': '식물성 음료로 우유 알레르기가 있는 분께 적합해요',
        'safeLevel': 'safe',
      },
      {
        'name': '아몬드밀크',
        'category': '우유 대체',
        'description': '고소한 맛의 식물성 음료예요',
        'safeLevel': 'safe',
      },
      {
        'name': '두유',
        'category': '우유 대체',
        'description': '단백질이 풍부한 식물성 음료예요',
        'safeLevel': 'caution',
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final alternatives = _getAlternatives();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('대체 식품 추천',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 안내 배너
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.red[50],
            child: Row(
              children: [
                const Icon(Icons.swap_horiz,
                    color: Color(0xFFE53935), size: 28),
                const SizedBox(width: 12),
                Text(
                  '"$dangerIngredient" 대신 드실 수 있어요',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // 대체 식품 리스트
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: alternatives.length,
              itemBuilder: (context, index) {
                final item = alternatives[index];
                final isSafe = item['safeLevel'] == 'safe';
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSafe ? Colors.green : Colors.amber,
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // 아이콘
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: isSafe
                                ? Colors.green[50]
                                : Colors.amber[50],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.restaurant,
                            color: isSafe ? Colors.green : Colors.amber,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),

                        // 내용
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(item['name'],
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isSafe
                                          ? Colors.green
                                          : Colors.amber,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      isSafe ? '안전' : '주의',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(item['category'],
                                  style: const TextStyle(
                                      color: Color(0xFFE53935),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(item['description'],
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}