class Notice {
  final String tag; // 중요 / 업데이트 / 안내
  final String title;
  final String body;
  final String date; // 비워두면 날짜 대신 '항상 고정'으로 표시
  final bool pinned; // true면 홈 맨 위에 고정

  const Notice({
    required this.tag,
    required this.title,
    this.body = '',
    this.date = '',
    this.pinned = false,
  });
}

/// 공지 목록. 비워 두면 홈의 공지사항 카드가 보이지 않습니다.
/// 아래 '업데이트'·'안내' 공지는 예시이니 실제 내용으로 바꿔 쓰세요.
/// (나중에 서버에서 가져오도록 바꿀 수 있습니다)
const List<Notice> kNotices = [
  Notice(
    tag: '중요',
    title: '결과는 참고용이에요. 포장지 표시도 꼭 확인하세요',
    body: '위 정보는 제품 포장지 성분표를 기반으로 제공되며, 제조사 사정에 따라 변경될 수 있습니다. '
        '개인 알레르기 반응은 다를 수 있으니 섭취 전 반드시 확인하세요.',
    pinned: true,
  ),
  Notice(
    tag: '업데이트',
    title: '제품 데이터가 새로 업데이트되었어요',
    body: '예시 공지입니다. 실제 내용으로 바꿔 주세요.',
    date: '2026.10.12',
  ),
  Notice(
    tag: '안내',
    title: '성분표 스캔 이용 방법을 알려드려요',
    body: '예시 공지입니다. 실제 내용으로 바꿔 주세요.',
    date: '2026.10.05',
  ),
];