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
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE53935)))
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