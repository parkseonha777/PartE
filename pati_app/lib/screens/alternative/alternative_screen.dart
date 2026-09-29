import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../camera/camera_screen.dart' show kServerBaseUrl;

class AlternativeScreen extends StatefulWidget {
  final String dangerIngredient;

  const AlternativeScreen({
    super.key,
    required this.dangerIngredient,
  });

  @override
  State<AlternativeScreen> createState() => _AlternativeScreenState();
}

class _AlternativeScreenState extends State<AlternativeScreen> {
  bool _isLoading = true;
  String? _error;
  List<String> _alternatives = [];

  @override
  void initState() {
    super.initState();
    _fetchAlternatives();
  }

  Future<void> _fetchAlternatives() async {
    try {
      final uri = Uri.parse(
        "$kServerBaseUrl/alternatives?allergen=${Uri.encodeComponent(widget.dangerIngredient)}&limit=5",
      );
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('서버 오류 (${response.statusCode})');
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (mounted) {
        setState(() {
          _alternatives = List<String>.from(data['alternatives'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '대체 식품을 불러오지 못했습니다.\n($e)';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                Expanded(
                  child: Text(
                    '"${widget.dangerIngredient}"이(가) 없는 식품이에요',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // 대체 식품 리스트
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFE53935)))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    : _alternatives.isEmpty
                        ? const Center(
                            child: Text('추천할 대체 식품을 찾지 못했습니다.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _alternatives.length,
                            itemBuilder: (context, index) {
                              final name = _alternatives[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(
                                      color: Colors.green, width: 1.5),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Colors.green[50],
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.restaurant,
                                            color: Colors.green, size: 28),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(name,
                                                style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            const SizedBox(height: 4),
                                            Text(
                                              '"${widget.dangerIngredient}" 미포함',
                                              style: const TextStyle(
                                                  color: Colors.green,
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.bold),
                                            ),
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