/// 로그인한 사용자 정보를 앱이 켜져 있는 동안만 기억합니다.
/// (Step 5에서 실제 로그인 API가 연결되면 이 값을 서버 정보로 교체)
class SessionStore {
  static String? email;

  static String get displayName {
    final e = email;
    if (e == null || e.isEmpty) return '사용자';
    final i = e.indexOf('@');
    return i > 0 ? e.substring(0, i) : e;
  }

  static void clear() {
    email = null;
  }
}