import 'package:flutter/material.dart';
import '../alternative/alternative_screen.dart';

class ScanResultScreen extends StatelessWidget {
  final String imagePath;

  // 서버 응답 형태
  // - /scan        : {"위험": [...], "주의": [...], "안전": [...]}
  // - /scan/verify : 위 키 + "verification": {...}, "translation": {...}
  // verification/translation 이 없으면(구버전 서버) 기존 화면과 똑같이 동작한다.
  final Map<String, dynamic> scanResult;

  const ScanResultScreen({
    super.key,
    required this.imagePath,
    required this.scanResult,
  });

  Map<String, dynamic>? get _verification =>
      scanResult['verification'] as Map<String, dynamic>?;

  Map<String, dynamic>? get _translation =>
      scanResult['translation'] as Map<String, dynamic>?;

  bool get _isVerified => _verification?['status'] == 'verified';

  bool get _needsRecheck => _verification?['needs_recheck'] == true;

  // 글자를 충분히 읽었는지. 서버가 reliable을 보내지 않으면(구버전 서버) 읽은 것으로 본다.
  // AI가 "사진이 흐려 읽기 어렵다(poor)"고 판단한 경우도 충분하지 않은 것으로 본다.
  bool get _reliable =>
      scanResult['reliable'] != false && _verification?['legibility'] != 'poor';

  /// 알레르겐 이름 → LLM 판정 상세 (근거 표기, 규칙/LLM 일치 여부)
  Map<String, Map<String, dynamic>> get _detailsByAllergen {
    final details = (_verification?['details'] as List?) ?? const [];
    return {
      for (final d in details.cast<Map<String, dynamic>>())
        d['allergen'] as String: d,
    };
  }

  // 서버 응답({"위험":[...], "주의":[...], "안전":[...]})을
  // 기존 UI가 쓰던 형태([{'name':..., 'level':...}, ...])로 변환
  List<Map<String, dynamic>> get _ingredients {
    final List<Map<String, dynamic>> result = [];

    final dangerNames = List<String>.from(scanResult['위험'] ?? []);
    final cautionNames = List<String>.from(scanResult['주의'] ?? []);
    final safeNames = List<String>.from(scanResult['안전'] ?? []);

    for (final name in dangerNames) {
      result.add({'name': name, 'level': 'danger'});
    }
    for (final name in cautionNames) {
      result.add({'name': name, 'level': 'caution'});
    }
    for (final name in safeNames) {
      // 인식이 불충분하면 "안전" 대신 "확인 필요"로 표시
      result.add({'name': name, 'level': _reliable ? 'safe' : 'unverified'});
    }

    return result;
  }

  Color _getRiskColor(String level) {
    switch (level) {
      case 'danger':
        return Colors.red;
      case 'caution':
        return Colors.amber;
      case 'safe':
        return Colors.green;
      case 'unverified':
        return Colors.blueGrey;
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
      case 'unverified':
        return '확인 필요';
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
      case 'unverified':
        return Icons.help_outline;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ingredients = _ingredients;
    final dangerList =
        ingredients.where((e) => e['level'] == 'danger').toList();
    final cautionList =
        ingredients.where((e) => e['level'] == 'caution').toList();
    final safeList =
        ingredients.where((e) => e['level'] == 'safe').toList();
    final unverifiedList =
        ingredients.where((e) => e['level'] == 'unverified').toList();
    final sortedList = [
      ...dangerList,
      ...cautionList,
      ...unverifiedList,
      ...safeList,
    ];

    // 요약 배너: 위험 > 주의 > 확인 필요 > 검출 없음 순으로 표시
    final Color bannerBg;
    final Color bannerFg;
    final IconData bannerIcon;
    final String bannerText;
    if (dangerList.isNotEmpty) {
      bannerBg = Colors.red.shade50;
      bannerFg = Colors.red;
      bannerIcon = Icons.warning_rounded;
      bannerText = '⚠️ 위험 성분 ${dangerList.length}개 발견!';
    } else if (cautionList.isNotEmpty) {
      bannerBg = Colors.amber.shade50;
      bannerFg = Colors.amber.shade800;
      bannerIcon = Icons.warning_amber;
      bannerText = '⚠️ 주의 성분 ${cautionList.length}개 발견';
    } else if (unverifiedList.isNotEmpty) {
      bannerBg = Colors.blueGrey.shade50;
      bannerFg = Colors.blueGrey;
      bannerIcon = Icons.help_outline;
      bannerText = '확인이 필요합니다 (인식이 불충분해요)';
    } else {
      bannerBg = Colors.green.shade50;
      bannerFg = Colors.green;
      bannerIcon = Icons.check_circle;
      bannerText = '✅ 등록한 알레르기 성분이 검출되지 않았습니다';
    }

    final details = _detailsByAllergen;
    final translatedNames = Map<String, dynamic>.from(
        (_translation?['allergen_names'] as Map?) ?? const {});

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('분석 결과',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2F6B54),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 요약 배너
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: bannerBg,
            child: Row(
              children: [
                Icon(bannerIcon, color: bannerFg, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    bannerText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: bannerFg,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // AI 교차 확인 상태 배너
          if (_verification != null) _buildVerificationBanner(),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (sortedList.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        '등록된 알레르기 항목과 일치하는 성분이 없습니다.',
                        style: TextStyle(fontSize: 15, color: Colors.grey),
                      ),
                    ),
                  ),

                // 알레르기 항목별 판정 카드
                for (final item in sortedList)
                  _buildAllergenCard(
                    item,
                    details[item['name']],
                    translatedNames[item['name']]?.toString(),
                  ),

                // 번역 결과 (접었다 펼 수 있음)
                if (_translation != null) ...[
                  const SizedBox(height: 8),
                  _buildTranslationTile(),
                ],

                // AI가 교정한 성분표 원문 (접었다 펼 수 있음)
                if (_isVerified) ...[
                  const SizedBox(height: 8),
                  _buildCorrectedTextTile(),
                ],
              ],
            ),
          ),

          // 항상 표시하는 안내 문구
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              _reliable
                  ? '인식된 글자 기준입니다. 포장지 원재료를 꼭 한 번 더 확인하세요.'
                  : '글자를 충분히 읽지 못했습니다. 성분표에 가까이 다가가 정면에서 다시 촬영해 주세요. 포장지 원재료도 꼭 확인하세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ),

          // 대체 식품 보기 버튼 (위험 성분이 있을 때만 표시)
          if (dangerList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2F6B54),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AlternativeScreen(
                          // 위험·주의로 판정된 성분을 모두 제외한 대체 식품 안내
                          excludeIngredients: [...dangerList, ...cautionList]
                              .map((e) => e['name'].toString())
                              .toList(),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('대체 식품 보기',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVerificationBanner() {
    final IconData icon;
    final Color color;
    final String message;

    if (!_isVerified) {
      icon = Icons.info_outline;
      color = Colors.grey;
      message = 'AI 교차 확인을 하지 못해 OCR 결과만 표시합니다. '
          '포장지의 원재료명을 직접 한 번 더 확인해주세요.';
    } else if (_needsRecheck) {
      icon = Icons.refresh;
      color = Colors.orange;
      final legibility = _verification?['legibility'];
      message = legibility == 'poor'
          ? '사진이 흐려 일부 글자를 읽기 어려웠어요. 성분표를 더 가까이에서 다시 촬영해주세요.'
          : 'OCR과 AI 판정이 다른 항목이 있어요. 항목별 근거를 보고 포장지를 함께 확인해주세요.';
    } else {
      icon = Icons.verified;
      color = Colors.blue;
      message = 'AI가 성분표 사진을 다시 읽어 판정을 교차 확인했어요.';
    }

    final notes = (_verification?['notes'] as String?) ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: color.withValues(alpha: 0.08),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: TextStyle(fontSize: 13, color: color)),
                if (notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(notes,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.black54)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergenCard(
    Map<String, dynamic> item,
    Map<String, dynamic>? detail,
    String? translatedName,
  ) {
    final color = _getRiskColor(item['level']);
    final evidence = (detail?['evidence'] as String?) ?? '';
    final agreed = detail?['agreed'] != false;
    final decidedBy = detail?['decided_by'] as String?;

    final subtitleLines = <String>[
      if (translatedName != null && translatedName.isNotEmpty) translatedName,
      if (evidence.isNotEmpty) '근거: $evidence',
      if (!agreed)
        decidedBy == 'llm'
            ? 'AI가 사진을 확인해 판정을 조정함'
            : 'OCR·AI 판정이 달라 더 위험한 쪽으로 표시',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color, width: 1.5),
      ),
      child: ListTile(
        leading: Icon(_getRiskIcon(item['level']), color: color, size: 32),
        title: Text(item['name'],
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        subtitle: subtitleLines.isEmpty
            ? null
            : Text(subtitleLines.join('\n'),
                style: const TextStyle(fontSize: 12)),
        isThreeLine: subtitleLines.length >= 2,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
  }

  Widget _buildTranslationTile() {
    final t = _translation!;
    final summary = (t['summary'] as String?) ?? '';
    final ingredients = (t['ingredients'] as String?) ?? '';
    final warning = (t['warning'] as String?) ?? '';
    final lang = (t['language'] as String?)?.toUpperCase() ?? '';

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.translate, color: Color(0xFF2F6B54)),
        title: Text('번역 ($lang)',
            style:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (summary.isNotEmpty) ...[
            Text(summary,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
          ],
          if (ingredients.isNotEmpty) ...[
            const Text('원재료명',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 2),
            SelectableText(ingredients, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
          ],
          if (warning.isNotEmpty) ...[
            const Text('알레르기 표시 / 혼입 주의',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 2),
            SelectableText(warning, style: const TextStyle(fontSize: 14)),
          ],
        ],
      ),
    );
  }

  Widget _buildCorrectedTextTile() {
    final v = _verification!;
    final productName = v['product_name'] as String?;
    final ingredientText = (v['corrected_ingredient_text'] as String?) ?? '';
    final warningText = (v['corrected_warning_text'] as String?) ?? '';
    final corrections = ((v['ocr_corrections'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.fact_check_outlined),
        title: const Text('AI가 확인한 성분표 원문',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (productName != null && productName.isNotEmpty) ...[
            const Text('제품명',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            Text(productName, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 10),
          ],
          if (ingredientText.isNotEmpty) ...[
            const Text('원재료명',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            SelectableText(ingredientText, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 10),
          ],
          if (warningText.isNotEmpty) ...[
            const Text('알레르기 표시 / 혼입 주의',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            SelectableText(warningText, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 10),
          ],
          if (corrections.isNotEmpty) ...[
            const Text('OCR 오타 교정',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in corrections)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('${c['ocr']} → ${c['corrected']}',
                        style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}