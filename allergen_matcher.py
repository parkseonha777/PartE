from difflib import SequenceMatcher
from DB.allergen_lookup import get_allergen_db

# 하드코딩된 딕셔너리 대신 Supabase DB에서 최신 데이터를 가져옴
ALLERGEN_DB = get_allergen_db()

WARNING_START_MARKERS = ["이 제품은", "이제품은", "본 제품은", "본제품은", "이 제품에는"]


def similarity(a: str, b: str) -> float:
    return SequenceMatcher(None, a, b).ratio()


def contains_allergen(text: str, allergen: str, threshold: float = 0.8) -> bool:
    synonyms = ALLERGEN_DB.get(allergen, [allergen])

    for synonym in synonyms:
        if synonym in text:
            return True

        L = len(synonym)
        if L < 4:
            continue

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