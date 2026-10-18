import 'package:flutter/material.dart';
import '../../models/scan_record.dart';
import '../../services/scan_history_store.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    ScanHistoryStore.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
       appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFE5E5E5), width: 1),
        ),
        title: const Text(
          '알아챈 기록',
          style: TextStyle(
              color: Color(0xFF1F2A24),
              fontSize: 20,
              fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1F2A24)),
      ),
      body: ValueListenableBuilder<List<ScanRecord>>(
        valueListenable: ScanHistoryStore.instance.records,
        builder: (context, records, _) {
          if (records.isEmpty) {
            return const _EmptyState();
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ...records.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _HistoryCard(record: r),
                ),
              ),
              const SizedBox(height: 8),
              const _DisclaimerCard(),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 72, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            '아직 스캔한 제품이 없어요',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black54),
          ),
          SizedBox(height: 8),
          Text(
            '성분표를 스캔하면 여기에 기록돼요',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// 성분 이름 → 아이콘 이미지 (assets/allergens/ 폴더)
const Map<String, String> _iconAssets = {
  '난류': 'egg',
  '계란': 'egg',
  '달걀': 'egg',
  '우유': 'milk',
  '메밀': 'buckwheat',
  '땅콩': 'peanut',
  '대두': 'soy',
  '대두(콩)': 'soy',
  '밀': 'wheat',
  '호두': 'walnut',
  '게': 'crab',
  '새우': 'shrimp',
  '오징어': 'squid',
  '고등어': 'mackerel',
  '조개류': 'clam',
  '복숭아': 'peach',
  '토마토': 'tomato',
  '닭고기': 'chicken',
  '돼지고기': 'pork',
  '쇠고기': 'beef',
  '소고기': 'beef',
  '아황산류': 'wine',
};

String? _assetFor(String name) {
  final key = _iconAssets[name];
  return key == null ? null : 'assets/allergens/$key.png';
}

Color _riskColor(RiskLevel level) {
  switch (level) {
    case RiskLevel.danger:
      return const Color(0xFFD32F2F);
    case RiskLevel.caution:
      return const Color(0xFFF57C00);
    case RiskLevel.safe:
      return const Color(0xFF43A047);
  }
}

String _riskLabel(RiskLevel level) {
  switch (level) {
    case RiskLevel.danger:
      return '위험';
    case RiskLevel.caution:
      return '주의';
    case RiskLevel.safe:
      return '안전';
  }
}

class _HistoryCard extends StatelessWidget {
  final ScanRecord record;
  const _HistoryCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final level = record.level;
    final color = _riskColor(level);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1.4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '성분에 포함된 실제 성분',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  record.ingredientsText,
                  style: const TextStyle(
                      fontSize: 14, height: 1.5, color: Colors.black87),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AllergenGroup(
                  label: '위험 성분 ${record.dangerNames.length}개',
                  color: const Color(0xFFD32F2F),
                  names: record.dangerNames,
                ),
                _AllergenGroup(
                  label: '주의 성분 ${record.cautionNames.length}개',
                  color: const Color(0xFFF57C00),
                  names: record.cautionNames,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _riskLabel(level),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllergenGroup extends StatelessWidget {
  final String label;
  final Color color;
  final List<String> names;

  const _AllergenGroup({
    required this.label,
    required this.color,
    required this.names,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 10),
        if (names.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: names.map((name) {
              final asset = _assetFor(name);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  children: [
                    // 위험(빨강)·주의(주황) 구분은 테두리 색으로 표시
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 3),
                        color: const Color(0xFFFFF8E6),
                      ),
                      child: ClipOval(
                        child: asset != null
                            ? Image.asset(
                                asset,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.medium,
                              )
                            : Icon(Icons.restaurant, color: color, size: 26),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(name, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.grey, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '위 정보는 제품 포장지 성분표를 기반으로 제공되며, 제조사 사정에 따라 변경될 수 있습니다.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                SizedBox(height: 4),
                Text(
                  '개인 알레르기 반응은 다를 수 있으니 섭취 전 반드시 확인하세요.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}