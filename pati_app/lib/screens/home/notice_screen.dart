import 'package:flutter/material.dart';
import '../../models/notice.dart';
import 'home_theme.dart';

/// 공지 한 줄 (홈 카드와 공지 목록에서 함께 사용)
class NoticeTile extends StatelessWidget {
  final Notice notice;
  const NoticeTile({super.key, required this.notice});

  @override
  Widget build(BuildContext context) {
    Color fg;
    Color bg;
    switch (notice.tag) {
      case '중요':
        fg = HomeColors.red;
        bg = const Color(0xFFFDE8E8);
        break;
      case '업데이트':
        fg = HomeColors.green;
        bg = HomeColors.greenLight;
        break;
      default:
        fg = HomeColors.gray;
        bg = const Color(0xFFEEEEEE);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  notice.tag,
                  style: TextStyle(
                      color: fg, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  notice.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, color: HomeColors.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            notice.date.isEmpty ? '항상 고정' : notice.date,
            style: const TextStyle(fontSize: 11, color: HomeColors.gray),
          ),
        ],
      ),
    );
  }
}

/// 공지사항 전체보기
class NoticeScreen extends StatelessWidget {
  const NoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('공지사항',
            style: TextStyle(
                color: HomeColors.text, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: HomeColors.text),
      ),
      body: kNotices.isEmpty
          ? const Center(
              child: Text('등록된 공지가 없어요',
                  style: TextStyle(color: HomeColors.gray, fontSize: 16)),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: kNotices
                  .map(
                    (n) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE0E4E0)),
                      ),
                      child: Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding:
                              const EdgeInsets.symmetric(horizontal: 14),
                          childrenPadding:
                              const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          title: NoticeTile(notice: n),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                n.body.isEmpty ? n.title : n.body,
                                style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: HomeColors.text),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}