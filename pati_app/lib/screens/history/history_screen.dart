import 'package:flutter/material.dart';
import 'dart:math' as math;

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final records = _mockRecords();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFE53935),
        elevation: 0,
        title: const Text(
          '알아챈 기록',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
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
      ),
    );
  }

  // 임시 Mock 데이터 (Step 5에서 실제 API로 교체)
  List<_ScanRecord> _mockRecords() {
    return [
      _ScanRecord(
        title: '새우깡',
        date: '2026.08.06 14:32',
        ingredientsText:
            '소맥분(밀), 전분, 미강유, 새우 6.4%, 정제소금, 설탕, 효모추출물, 새우조미분말, 대두단백',
        dangerFindings: const [
          _Allergen('밀', WheatPainter()),
          _Allergen('새우', ShrimpPainter()),
        ],
        cautionFindings: const [
          _Allergen('대두', SoyPainter()),
        ],
        overallLevel: RiskLevel.danger,
      ),
      _ScanRecord(
        title: '포카칩',
        date: '2026.08.05 11:15',
        ingredientsText:
            '감자, 식물성유지(해바라기유, 팜유), 미강유, 정제소금, 유당(우유), 유화제, 허브추출물',
        dangerFindings: const [],
        cautionFindings: const [
          _Allergen('우유', MilkPainter()),
        ],
        overallLevel: RiskLevel.caution,
      ),
      _ScanRecord(
        title: '허니버터칩',
        date: '2026.08.04 09:00',
        ingredientsText:
            '감자, 식물성유지(해바라기유, 팜유), 설탕, 꿀 0.01%, 버터 0.03%(우유), 정제소금, 합성향료(허니버터향)',
        dangerFindings: const [],
        cautionFindings: const [],
        overallLevel: RiskLevel.safe,
      ),
    ];
  }
}

enum RiskLevel { danger, caution, safe }

class _Allergen {
  final String label;
  final CustomPainter painter;
  const _Allergen(this.label, this.painter);
}

class _ScanRecord {
  final String title;
  final String date;
  final String ingredientsText;
  final List<_Allergen> dangerFindings;
  final List<_Allergen> cautionFindings;
  final RiskLevel overallLevel;

  const _ScanRecord({
    required this.title,
    required this.date,
    required this.ingredientsText,
    required this.dangerFindings,
    required this.cautionFindings,
    required this.overallLevel,
  });
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
  final _ScanRecord record;
  const _HistoryCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final color = _riskColor(record.overallLevel);

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
                const SizedBox(height: 6),
                Text(
                  record.date,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
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
                  label: '위험 성분 ${record.dangerFindings.length}개',
                  color: const Color(0xFFD32F2F),
                  findings: record.dangerFindings,
                ),
                _AllergenGroup(
                  label: '주의 성분 ${record.cautionFindings.length}개',
                  color: const Color(0xFFF57C00),
                  findings: record.cautionFindings,
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
                _riskLabel(record.overallLevel),
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
  final List<_Allergen> findings;

  const _AllergenGroup({
    required this.label,
    required this.color,
    required this.findings,
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
        if (findings.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: findings
                .map(
                  (f) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(9),
                          child: CustomPaint(painter: f.painter),
                        ),
                        const SizedBox(height: 6),
                        Text(f.label, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                )
                .toList(),
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

// ==================== 알레르기 성분 아이콘 (CustomPainter) ====================

class WheatPainter extends CustomPainter {
  const WheatPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final stem = Paint()
      ..color = Colors.white
      ..strokeWidth = size.width * 0.05
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;

    canvas.drawLine(
      Offset(cx, size.height * 0.20),
      Offset(cx, size.height * 0.95),
      stem,
    );

    const n = 6;
    for (int i = 0; i < n; i++) {
      final t = i / (n - 1);
      final y = size.height * 0.24 + t * size.height * 0.58;
      final spread = size.width * 0.03 + t * size.width * 0.10;
      final kw = size.width * 0.15;
      final kh = size.height * 0.20;
      canvas.drawOval(Rect.fromLTWH(cx - spread - kw, y, kw, kh), fill);
      canvas.drawOval(Rect.fromLTWH(cx + spread, y, kw, kh), fill);
    }

    final awn = Paint()
      ..color = Colors.white
      ..strokeWidth = size.width * 0.035
      ..strokeCap = StrokeCap.round;
    for (final angDeg in [-22.0, 0.0, 22.0]) {
      final rad = angDeg * math.pi / 180;
      final x1 = cx + size.width * 0.015 * math.sin(rad);
      final y1 = size.height * 0.18;
      final x2 = cx + size.width * 0.20 * math.sin(rad);
      final y2 = size.height * 0.18 - size.height * 0.20 * math.cos(rad);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), awn);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ShrimpPainter extends CustomPainter {
  const ShrimpPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    // 몸통 색과 대비되는 눈동자용 컬러(원 배경색과 맞춰주세요 - 위험:D32F2F / 주의:F57C00)
    final eyePaint = Paint()..color = const Color(0xFFD32F2F);

    final arcCx = size.width * 0.52;
    final arcCy = size.height * 0.56;
    final pathR = size.width * 0.30;
    const startAngDeg = 200.0;
    const endAngDeg = 375.0;
    const steps = 16;

    Offset headPos = Offset.zero;
    double headR = 0;
    Offset tailPos = Offset.zero;
    double tailAngRad = 0;

    // 머리→꼬리로 갈수록 작아지는 원을 곡선을 따라 겹쳐 그려 몸통을 표현
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final rad = (startAngDeg + t * (endAngDeg - startAngDeg)) * math.pi / 180;
      final cx0 = arcCx + pathR * math.cos(rad);
      final cy0 = arcCy + pathR * math.sin(rad);
      final r = size.width * 0.155 * (1 - t) + size.width * 0.035 * t;
      canvas.drawCircle(Offset(cx0, cy0), r, fill);
      if (i == 0) {
        headPos = Offset(cx0, cy0);
        headR = r;
      }
      if (i == steps) {
        tailPos = Offset(cx0, cy0);
        tailAngRad = rad;
      }
    }

    // 머리 (조금 더 통통하게)
    canvas.drawCircle(headPos, headR * 1.15, fill);

    // 눈
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(headPos.dx, headPos.dy - headR * 0.5),
        width: headR * 0.7,
        height: headR * 0.7,
      ),
      eyePaint,
    );

    // 더듬이
    final antStart = Offset(headPos.dx + headR * 0.5, headPos.dy - headR * 0.9);
    final antEnd = Offset(antStart.dx + size.width * 0.22, antStart.dy - size.height * 0.20);
    canvas.drawLine(
      antStart,
      antEnd,
      Paint()
        ..color = Colors.white
        ..strokeWidth = size.width * 0.02
        ..strokeCap = StrokeCap.round,
    );

    // 꼬리 지느러미 (부채꼴 3장)
    final fanCenterDeg = tailAngRad * 180 / math.pi;
    for (final offset in [-28.0, 0.0, 28.0]) {
      final rad = (fanCenterDeg + offset) * math.pi / 180;
      final len = size.width * 0.15;
      final ex = tailPos.dx + len * math.cos(rad);
      final ey = tailPos.dy + len * math.sin(rad);
      final perp = rad + math.pi / 2;
      final w = size.width * 0.026;
      final path = Path()
        ..moveTo(tailPos.dx - w * math.cos(perp), tailPos.dy - w * math.sin(perp))
        ..lineTo(tailPos.dx + w * math.cos(perp), tailPos.dy + w * math.sin(perp))
        ..lineTo(ex, ey)
        ..close();
      canvas.drawPath(path, fill);
    }

    // 배 쪽 다리 3개
    final legPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = size.width * 0.02
      ..strokeCap = StrokeCap.round;
    for (final t in [0.30, 0.45, 0.60]) {
      final rad = (startAngDeg + t * (endAngDeg - startAngDeg)) * math.pi / 180;
      final innerR = pathR - size.width * 0.10;
      final lx = arcCx + innerR * math.cos(rad);
      final ly = arcCy + innerR * math.sin(rad);
      canvas.drawLine(
        Offset(lx, ly),
        Offset(lx + size.width * 0.05, ly + size.height * 0.09),
        legPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SoyPainter extends CustomPainter {
  const SoyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.075;
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final podRect = Rect.fromLTWH(
      size.width * 0.20,
      size.height * 0.08,
      size.width * 0.60,
      size.height * 0.84,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(podRect, Radius.circular(size.width * 0.30)),
      strokePaint,
    );

    final beanR = size.width * 0.135;
    for (final ty in [0.30, 0.50, 0.70]) {
      canvas.drawCircle(
        Offset(size.width * 0.5, size.height * ty),
        beanR,
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MilkPainter extends CustomPainter {
  const MilkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.38,
          size.height * 0.02,
          size.width * 0.24,
          size.height * 0.10,
        ),
        Radius.circular(size.width * 0.025),
      ),
      fillPaint,
    );

    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.41,
        size.height * 0.12,
        size.width * 0.18,
        size.height * 0.12,
      ),
      fillPaint,
    );

    final body = Path()
      ..moveTo(size.width * 0.41, size.height * 0.24)
      ..lineTo(size.width * 0.59, size.height * 0.24)
      ..quadraticBezierTo(
        size.width * 0.76,
        size.height * 0.30,
        size.width * 0.76,
        size.height * 0.46,
      )
      ..lineTo(size.width * 0.76, size.height * 0.86)
      ..quadraticBezierTo(
        size.width * 0.76,
        size.height * 0.94,
        size.width * 0.66,
        size.height * 0.94,
      )
      ..lineTo(size.width * 0.34, size.height * 0.94)
      ..quadraticBezierTo(
        size.width * 0.24,
        size.height * 0.94,
        size.width * 0.24,
        size.height * 0.86,
      )
      ..lineTo(size.width * 0.24, size.height * 0.46)
      ..quadraticBezierTo(
        size.width * 0.24,
        size.height * 0.30,
        size.width * 0.41,
        size.height * 0.24,
      )
      ..close();
    canvas.drawPath(body, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}