import re


def clean_ocr_text(text: str) -> str:
    """
    OCR로 추출한 원재료명 텍스트에서 불필요한 요소를 제거하고 정제한다.
    - 퍼센트, 숫자+단위 제거
    - '함유', '포함' 등 불필요 서술어 제거
    - 특수문자 정리
    """
    # 1. 퍼센트 숫자 제거 (예: "50%" -> "")
    text = re.sub(r'\d+(\.\d+)?\s?%', '', text)

    # 2. 숫자 + 단위 제거 (예: "610mg", "5 g" -> "")
    text = re.sub(r'\d+(\.\d+)?\s?(mg|g|kg|ml|l|kcal)', '', text, flags=re.IGNORECASE)

    # 3. 불필요한 서술어/조사 제거 (원재료명 뒤에 자주 붙는 표현들)
    noise_words = ['함유', '포함', '미만', '이상', '첨가', '사용']
    for word in noise_words:
        text = text.replace(word, '')

    # 4. 특수문자 제거 (한글, 영문, 숫자, 공백만 남김)
    text = re.sub(r'[^\w\sㄱ-힣]', ' ', text)

    # 5. 중복 공백 정리
    text = re.sub(r'\s+', ' ', text)

    return text.strip()


def clean_ocr_text_list(ocr_text_list: list[str]) -> list[str]:
    """OCR 텍스트 리스트 전체를 정제. 정제 후 빈 문자열은 제거."""
    cleaned = [clean_ocr_text(t) for t in ocr_text_list]
    return [t for t in cleaned if t]


if __name__ == "__main__":
    sample = [
        "새우(국산 50%, 미국산 50%)",
        "나트륨 610mg 31%",
        "우유 대두 밀 닭고기 쇠고기 새우 조개류(굴 포함) 오징어 함유",
        "트랜스지방 0.5g미만",
    ]

    print("=== 정제 전 ===")
    for t in sample:
        print(t)

    print("\n=== 정제 후 ===")
    for t in clean_ocr_text_list(sample):
        print(t)