import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 성분표 번역 언어 설정을 기기에 저장하고 불러오는 저장소.
/// 서버 /scan/verify 의 target_lang 값으로 그대로 전송된다.
class TranslationLangStore {
  TranslationLangStore._();
  static final TranslationLangStore instance = TranslationLangStore._();

  static const _key = 'translation_lang_v1';
  static const defaultLang = 'en';

  /// 서버(llm_verifier.LANGUAGE_NAMES)가 지원하는 언어 코드 → 화면 표시 이름
  static const Map<String, String> languages = {
    'en': 'English',
    'ja': '日本語',
    'zh': '简体中文',
    'zh-TW': '繁體中文',
    'vi': 'Tiếng Việt',
    'th': 'ภาษาไทย',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
    'ru': 'Русский',
    'id': 'Bahasa Indonesia',
    'ko': '한국어',
  };

  final ValueNotifier<String> selected = ValueNotifier<String>(defaultLang);

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved != null && languages.containsKey(saved)) {
        selected.value = saved;
      }
    } finally {
      _loaded = true;
    }
  }

  Future<void> save(String lang) async {
    if (!languages.containsKey(lang)) return;
    _loaded = true;
    selected.value = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, lang);
  }
}
