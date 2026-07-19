from difflib import SequenceMatcher

# 각 알레르기 항목마다: 정식 명칭 + 일반 동의어 + OCR이 실제로 자주 틀리는 오타 패턴까지 등록
ALLERGEN_DB = {
    "난류": ["난류", "계란", "전란", "전란액", "난백", "난황",
             "계런", "게란", "게런"],  # OCR 오타 패턴
    "우유": ["우유", "분유", "유청", "카제인", "버터", "치즈", "유당",
             "유유"],  # OCR 오타 패턴
    "땅콩": ["땅콩", "피넛", "땅콩분말", "땅콩버터"],
    "대두": ["대두", "콩", "두유", "대두유", "간장",
             "대도"],  # OCR 오타 패턴
    "밀": ["밀", "밀가루", "소맥", "소맥분", "글루텐",
           "말"],  # OCR 오타 패턴 (주의: '말'은 다른 단어와 겹칠 수 있어 위험 요소지만 우선 등록)
    "새우": ["새우", "갑각류", "쉬림프", "새우분말", "새우추출물",
             "새유"],  # OCR 오타 패턴
    "게": ["게", "크랩"],
    "돼지고기": ["돼지고기", "돈육", "포크"],
    "쇠고기": ["쇠고기", "소고기", "우육", "비프"],
    "닭고기": ["닭고기", "계육", "치킨",
               "닮고기"],  # OCR 오타 패턴
    "고등어": ["고등어"],
    "조개류": ["조개류", "굴", "전복", "홍합", "바지락",
               "조게류", "조료국"],  # OCR 오타 패턴
    "오징어": ["오징어"],
    "토마토": ["토마토"],
}

WARNING_START_MARKERS = ["이 제품은", "이제품은", "본 제품은", "본제품은", "이 제품에는"]


def similarity(a: str, b: str) -> float:
    return SequenceMatcher(None, a, b).ratio()


def contains_allergen(text: str, allergen: str, threshold: float = 0.8) -> bool:
    """
    1) 등록된 모든 동의어(오타 패턴 포함)로 정확 일치 검사
    2) 4글자 이상인 단어에 한해서만 보조적으로 유사도 비교 (짧은 단어는 오탐 위험 커서 제외)
    """
    synonyms = ALLERGEN_DB.get(allergen, [allergen])

    for synonym in synonyms:
        if synonym in text:
            return True

        L = len(synonym)
        if L < 4:
            continue  # 짧은 단어는 정확 일치만 인정

        if len(text) < L:
            continue

        for i in range(len(text) - L + 1):
            window = text[i:i + L]
            if similarity(synonym, window) >= threshold:
                return True

    return False


def split_ingredient_and_warning(ocr_text_list: list[str]):
    ingredient_parts = []
    warning_parts = []
    warning_started = False

    for text in ocr_text_list:
        if not warning_started and any(marker in text for marker in WARNING_START_MARKERS):
            warning_started = True
            for marker in WARNING_START_MARKERS:
                if marker in text:
                    text = text.replace(marker, marker + " ")
                    break

        if warning_started:
            warning_parts.append(text)
        else:
            ingredient_parts.append(text)

    return " ".join(ingredient_parts), " ".join(warning_parts)


def find_allergens_in_text(ocr_text_list: list[str], user_allergens: list[str], threshold: float = 0.8) -> dict:
    ingredient_text, warning_text = split_ingredient_and_warning(ocr_text_list)

    print(f"\n[디버그] 원재료 목록 텍스트: {ingredient_text}")
    print(f"[디버그] 경고 문구 텍스트: {warning_text}\n")

    result = {"위험": [], "주의": [], "안전": []}

    for allergen in user_allergens:
        if contains_allergen(ingredient_text, allergen, threshold):
            result["위험"].append(allergen)
        elif contains_allergen(warning_text, allergen, threshold):
            result["주의"].append(allergen)
        else:
            result["안전"].append(allergen)

    return result


if __name__ == "__main__":
    sample_ocr_result = [
        "유유 대도 밀 닭고기 쇠고기 새유 조게류포함 오징어@",
        "이제품은계런 땅콩 게 돼지고기 토마토 조게류전복 홍합 포함를 사용한 제품과 같은 제조 시설에서 제조"
    ]
    my_allergens = ["난류", "우유", "새우", "고등어", "대두"]

    result = find_allergens_in_text(sample_ocr_result, my_allergens)
    print(f"위험: {result['위험']}")
    print(f"주의: {result['주의']}")
    print(f"안전: {result['안전']}")