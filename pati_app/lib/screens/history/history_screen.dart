import 'package:flutter/material.dart';
import '../../main.dart' show supabase;

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _error = '로그인이 필요합니다.';
      });
      return;
    }

    try {
      final data = await supabase
          .from('scan_history')
          .select()
          .eq('user_id', userId)
          .order('scanned_at', ascending: false);

      if (mounted) {
        setState(() {
          _history = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '이력을 불러오지 못했습니다: $e';
          _isLoading = false;
        });
      }
    }
  }

  Color _getResultColor(String result) {
    switch (result) {
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

  String _getResultLabel(String result) {
    switch (result) {
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

  IconData _getResultIcon(String result) {
    switch (result) {
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

  String _formatDateTime(String isoString) {
    final dt = DateTime.parse(isoString).toLocal();
    final date =
        '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('스캔 이력',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2F6B54),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2F6B54)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : _history.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 80, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('스캔 이력이 없어요',
                              style: TextStyle(
                                  fontSize: 18, color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _history.length,
                      itemBuilder: (context, index) {
                        final item = _history[index];
                        final result = item['result'] as String? ?? 'safe';
                        final color = _getResultColor(result);
                        final dangerCount = item['danger_count'] ?? 0;
                        final cautionCount = item['caution_count'] ?? 0;
                        final scannedAt = item['scanned_at'] as String;
                        final productName =
                            item['product_name'] as String? ?? '스캔한 식품';
                        final dangerNames = List<String>.from(
                            (item['danger_names'] as List?) ?? const []);
                        final cautionNames = List<String>.from(
                            (item['caution_names'] as List?) ?? const []);

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
                                Icon(_getResultIcon(result),
                                    color: color, size: 36),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(productName,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDateTime(scannedAt),
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 13),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '위험 $dangerCount개 · 주의 $cautionCount개',
                                        style: TextStyle(
                                            color: color,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      _AllergenIcons(
                                        label: '위험 성분',
                                        color: Colors.red,
                                        names: dangerNames,
                                      ),
                                      _AllergenIcons(
                                        label: '주의 성분',
                                        color: const Color(0xFFF57C00),
                                        names: cautionNames,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _getResultLabel(result),
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
  '굴': 'oyster',
  '전복': 'abalone',
  '홍합': 'mussel',
  '잣': 'pinenut',
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

// 위험(빨강)·주의(주황) 성분을 아이콘 이미지로 보여준다.
// 이름이 없는 예전 이력은 아무것도 그리지 않는다.
class _AllergenIcons extends StatelessWidget {
  final String label;
  final Color color;
  final List<String> names;

  const _AllergenIcons({
    required this.label,
    required this.color,
    required this.names,
  });

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: names.map((name) {
              final asset = _assetFor(name);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
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
                              // 아이콘 파일이 없어도 화면이 깨지지 않도록
                              errorBuilder: (_, __, ___) =>
                                  Icon(Icons.restaurant, color: color, size: 22),
                            )
                          : Icon(Icons.restaurant, color: color, size: 22),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(name, style: const TextStyle(fontSize: 12)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}