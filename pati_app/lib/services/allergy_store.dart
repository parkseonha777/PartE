import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 사용자가 고른 알레르기 성분을 기기에 저장하고 불러오는 저장소
class AllergyStore {
  AllergyStore._();
  static final AllergyStore instance = AllergyStore._();

  static const _key = 'my_allergies_v1';

  /// 화면은 이 값을 구독해서 선택이 바뀌면 자동으로 다시 그려집니다.
  final ValueNotifier<List<String>> selected =
      ValueNotifier<List<String>>(const []);

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      selected.value = prefs.getStringList(_key) ?? const [];
    } finally {
      _loaded = true;
    }
  }

  Future<void> save(List<String> names) async {
    _loaded = true;
    selected.value = List<String>.unmodifiable(names);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, names);
  }
}