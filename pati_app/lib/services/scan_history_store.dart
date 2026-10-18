import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_record.dart';

/// 스캔 기록을 기기에 저장하고 불러오는 저장소 (앱을 껐다 켜도 유지됨)
class ScanHistoryStore {
  ScanHistoryStore._();
  static final ScanHistoryStore instance = ScanHistoryStore._();

  static const _key = 'scan_history_v1';

  /// 화면은 이 값을 구독해서 기록이 바뀌면 자동으로 다시 그려집니다.
  final ValueNotifier<List<ScanRecord>> records =
      ValueNotifier<List<ScanRecord>>(const []);

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? const [];
      final list = <ScanRecord>[];
      for (final s in raw) {
        try {
          list.add(ScanRecord.fromJson(jsonDecode(s) as Map<String, dynamic>));
        } catch (_) {
          // 손상된 항목은 건너뜀
        }
      }
      list.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
      records.value = list;
    } finally {
      _loaded = true;
    }
  }

  Future<void> add(ScanRecord record) async {
    await load();
    final list = [record, ...records.value]
      ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    records.value = list;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      list.map((r) => jsonEncode(r.toJson())).toList(),
    );
  }

  /// 저장된 기록을 모두 지웁니다.
  Future<void> clear() async {
    await load();
    records.value = const [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}