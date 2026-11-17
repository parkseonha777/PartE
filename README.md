#Claude & git ID
- patibackroom@gamail.com

## API 명세 (백엔드 B - OCR 서버)
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

## POST /scan/verify
OCR 결과를 LLM(Claude)이 **원본 이미지와 대조해 교차 확인**하고, 교정된 성분표를 번역합니다.

처리 흐름: 이미지 → EasyOCR → 규칙 기반 판정(`/scan`과 동일) → LLM 교차 확인(이미지 + OCR 원문 + 1차 판정) → 병합 → 번역

- 최종 판정은 규칙 기반과 LLM 중 **더 위험한 쪽**을 따릅니다. LLM이 위험도를 낮출 수는 없습니다.
- LLM 호출이 실패하거나 `ANTHROPIC_API_KEY`가 없으면 규칙 기반 결과만 반환합니다 (`verification.status = "unavailable"`).
- `.env`에 `ANTHROPIC_API_KEY`가 필요합니다. 모델은 `LLM_MODEL`로 바꿀 수 있습니다.

### Request (multipart/form-data)
| 필드 | 타입 | 설명 |
|---|---|---|
| file | File | 성분표 촬영 이미지 |
| allergens | String | 쉼표로 구분된 알레르기 항목 |
| target_lang | String | 번역 언어 (기본 `en`; `ko, ja, zh, zh-TW, vi, th, es, fr, de, ru, id`) |

### Response (JSON)
최상위 `위험`/`주의`/`안전`은 `/scan`과 같은 형식이라 기존 결과 화면을 그대로 쓸 수 있습니다.
```json
{
  "위험": ["우유", "대두"],
  "주의": ["난류"],
  "안전": ["고등어"],
  "verification": {
    "status": "verified",
    "legibility": "good",
    "needs_recheck": true,
    "product_name": "새우깡",
    "corrected_ingredient_text": "소맥분(밀:미국산), 새우(국산), 대두유, 우유",
    "corrected_warning_text": "이 제품은 난류, 땅콩을 사용한 제품과 같은 제조 시설에서 제조하고 있습니다.",
    "ocr_corrections": [{"ocr": "유유", "corrected": "우유"}],
    "details": [
      {"allergen": "대두", "rule": "주의", "llm": "위험", "final": "위험", "agreed": false, "evidence": "대두유"}
    ],
    "notes": ""
  },
  "translation": {
    "language": "en",
    "ingredients": "Wheat flour (wheat: USA), shrimp (Korea), soybean oil, milk",
    "warning": "Manufactured in the same facility that processes eggs and peanuts.",
    "allergen_names": {"우유": "Milk", "난류": "Eggs"},
    "summary": "Contains milk and soybean. May contain eggs."
  }
}
```
`needs_recheck`가 `true`면 이미지가 흐리거나 두 판정이 엇갈린 경우이므로, 앱에서 재촬영 또는 원문 확인을 안내하는 것을 권장합니다.

테스트 (API 키·DB 없이 실행): `python -m pytest test_llm_verifier.py -v`

## GET 
서버 상태 확인용
\`\`\`json
{"message": "팥이 OCR 서버가 실행 중입니다"}
\`\`\`

## 사용 가능한 알레르기 항목 목록
난류, 우유, 땅콩, 대두, 밀, 새우, 게, 돼지고기, 쇠고기, 닭고기, 고등어, 조개류, 오징어, 토마토

## 이미지 전처리 실험 결과

흑백화 + 노이즈 제거 + 이진화(Otsu threshold) 방식의 전처리를 EasyOCR 앞단에 적용해 비교 실험을 진행함.

| 구분 | 인식된 텍스트 수 | 평균 신뢰도 |
|---|---|---|
| 원본 이미지 | 36개 | 0.431 |
| 전처리 이미지 | 34개 | 0.310 |

**결론**: EasyOCR은 자체적으로 전처리를 수행하기 때문에, 추가로 강한 이진화를 적용하면 오히려 작은 글씨의 획이 손상되어 인식률이 떨어짐. 따라서 현재 서버(`server.py`)에서는 이미지 전처리를 적용하지 않고 원본 이미지를 그대로 OCR에 사용함.

(`image_preprocessing.py`는 실험 기록용으로 보존)
