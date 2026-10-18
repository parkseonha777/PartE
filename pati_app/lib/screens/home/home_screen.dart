import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/notice.dart';
import '../../services/allergy_store.dart';
import '../../services/session_store.dart';
import '../profile/allergy_profile_screen.dart';
import '../scan_guide/scan_guide_screen.dart';
import '../scan_result/scan_result_screen.dart';
import 'home_theme.dart';
import 'notice_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  void _openScanGuide() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScanGuideScreen()),
    );
  }

  Future<void> _pickFromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScanResultScreen(imagePath: picked.path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            _header(),
            const SizedBox(height: 20),
            _allergyCard(),
            const SizedBox(height: 20),
            _scanButton(),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_outlined,
                    color: HomeColors.text, size: 20),
                label: const Text('갤러리에서 불러오기',
                    style: TextStyle(color: HomeColors.text, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 8),
            const _NoticeCard(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: HomeColors.green,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Text('팥',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '안녕하세요, ${SessionStore.displayName}님',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: HomeColors.text),
              ),
              const Text('오늘도 안전하게 드세요',
                  style: TextStyle(fontSize: 12, color: HomeColors.sub)),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_none, color: HomeColors.text),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('새 알림이 없어요')),
            );
          },
        ),
      ],
    );
  }

  Widget _allergyCard() {
    return ValueListenableBuilder<List<String>>(
      valueListenable: AllergyStore.instance.selected,
      builder: (context, names, _) {
        final empty = names.isEmpty;
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
                    Expanded(
                      child: Text(
                        empty
                            ? '알레르기를 먼저 선택해 주세요'
                            : '내 알레르기 ${names.length}개 감시 중',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: HomeColors.greenDark),
                      ),
                    ),
                    Text(
                      empty ? '선택' : '편집',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: HomeColors.greenDark),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 20, color: HomeColors.greenDark),
                  ],
                ),
                if (!empty) ...[
                  const SizedBox(height: 10),
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
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _scanButton() {
    return Material(
      color: HomeColors.green,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: _openScanGuide,
        borderRadius: BorderRadius.circular(24),
        child: const SizedBox(
          height: 130,
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.center_focus_strong, color: Colors.white, size: 38),
              SizedBox(height: 8),
              Text('성분표 스캔하기',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('카메라로 원재료명을 찍어주세요',
                  style: TextStyle(color: Color(0xFFA9D8B8), fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 공지사항 카드: 고정 공지 + 최신 공지 2건. 공지가 없으면 보이지 않습니다.
class _NoticeCard extends StatelessWidget {
  const _NoticeCard();

  @override
  Widget build(BuildContext context) {
    if (kNotices.isEmpty) return const SizedBox.shrink();

    final pinned = kNotices.where((n) => n.pinned).toList();
    final others = kNotices.where((n) => !n.pinned).take(2).toList();
    final shown = [...pinned, ...others];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE0DC), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('공지사항',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: HomeColors.text)),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const NoticeScreen()),
                  );
                },
                child: const Row(
                  children: [
                    Text('전체보기',
                        style:
                            TextStyle(fontSize: 12, color: HomeColors.sub)),
                    Icon(Icons.chevron_right,
                        size: 18, color: HomeColors.sub),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFECEEEC)),
            NoticeTile(notice: shown[i]),
          ],
        ],
      ),
    );
  }
}