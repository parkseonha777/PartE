import 'package:flutter/material.dart';
import '../../services/allergy_store.dart';
import '../../services/scan_history_store.dart';
import '../../services/session_store.dart';
import '../auth/login_screen.dart';
import '../profile/allergy_profile_screen.dart';
import 'guide_info_screen.dart';
import 'home_theme.dart';
import 'notice_screen.dart';

class MyInfoScreen extends StatefulWidget {
  const MyInfoScreen({super.key});

  @override
  State<MyInfoScreen> createState() => _MyInfoScreenState();
}

class _MyInfoScreenState extends State<MyInfoScreen> {
  @override
  void initState() {
    super.initState();
    AllergyStore.instance.load();
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AllergyProfileScreen()),
    );
  }

  Future<void> _confirmClearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기록을 모두 지울까요?'),
        content: const Text('저장된 최근 스캔 기록이 모두 삭제되며 되돌릴 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제',
                style: TextStyle(color: HomeColors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ScanHistoryStore.instance.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('최근 스캔 기록을 삭제했어요')),
    );
  }

  void _logout() {
    SessionStore.clear();
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = SessionStore.displayName;
    final email = SessionStore.email ?? '';
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            const Text('내 정보',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: HomeColors.text)),
            const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: HomeColors.green,
                  child: Text(initial,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$name님',
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: HomeColors.text)),
                      if (email.isNotEmpty)
                        Text(email,
                            style: const TextStyle(
                                fontSize: 12, color: HomeColors.gray)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _allergyCard(),
            const SizedBox(height: 16),
            _MenuRow(
              title: '공지사항',
              sub: '새 소식 · 전체보기',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NoticeScreen()),
              ),
            ),
            _MenuRow(
              title: '이용 안내',
              sub: '결과 보는 법 · 데이터 출처',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const GuideInfoScreen()),
              ),
            ),
            _MenuRow(
              title: '최근 스캔 기록 삭제',
              sub: '저장된 기록을 모두 지웁니다',
              onTap: _confirmClearHistory,
            ),
            _MenuRow(
              title: '로그아웃',
              titleColor: HomeColors.red,
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _allergyCard() {
    return ValueListenableBuilder<List<String>>(
      valueListenable: AllergyStore.instance.selected,
      builder: (context, names, _) {
        return InkWell(
          onTap: _openProfile,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HomeColors.greenLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: HomeColors.greenBorder, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('내 알레르기',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: HomeColors.greenDark)),
                    ),
                    const Text('수정',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: HomeColors.greenDark)),
                    const Icon(Icons.chevron_right,
                        size: 20, color: HomeColors.greenDark),
                  ],
                ),
                const SizedBox(height: 10),
                if (names.isEmpty)
                  const Text('선택한 알레르기가 없어요',
                      style: TextStyle(fontSize: 13, color: HomeColors.sub))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: names
                        .map(
                          (n) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 13, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(n,
                                style: const TextStyle(
                                    fontSize: 13, color: HomeColors.text)),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MenuRow extends StatelessWidget {
  final String title;
  final String? sub;
  final Color titleColor;
  final VoidCallback onTap;

  const _MenuRow({
    required this.title,
    this.sub,
    this.titleColor = HomeColors.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E4E0), width: 1.2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: titleColor)),
                    if (sub != null) ...[
                      const SizedBox(height: 4),
                      Text(sub!,
                          style: const TextStyle(
                              fontSize: 11, color: HomeColors.gray)),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: HomeColors.gray),
            ],
          ),
        ),
      ),
    );
  }
}