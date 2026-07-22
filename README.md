#Claude & git ID
- patibackroom@gamail.com

## API 명세 (백엔드 B - OCR 서버)

## 서버 실행 방법
\`\`\`bash
uvicorn server:app --reload
\`\`\`
기본 주소: http://127.0.0.1:8000

## POST /scan
성분표 이미지를 분석해서 알레르기 위험도를 반환합니다.

## Request (multipart/form-data)
| 필드 | 타입 | 설명 |
|---|---|---|
| file | File | 성분표 촬영 이미지 |
| allergens | String | 쉼표로 구분된 알레르기 항목 (예: "난류,우유,새우") |

## Response (JSON)
\`\`\`json
{
  "위험": ["우유", "새우", "대두"],
  "주의": ["난류"],
  "안전": ["고등어"]
}
\`\`\`

## GET 
서버 상태 확인용
\`\`\`json
{"message": "팥이 OCR 서버가 실행 중입니다"}
\`\`\`

## 사용 가능한 알레르기 항목 목록
난류, 우유, 땅콩, 대두, 밀, 새우, 게, 돼지고기, 쇠고기, 닭고기, 고등어, 조개류, 오징어, 토마토
