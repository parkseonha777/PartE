from difflib import SequenceMatcher
from DB.allergen_lookup import get_allergen_db

# DB 연결이 안 될 때(.env 미설정, 네트워크 오류 등) 쓰는 기본 알레르겐 사전.
# 실제 서비스에서는 Supabase DB 값이 우선이다.
DEFAULT_ALLERGEN_DB = {
    "난류": ["난류", "계란", "달걀", "전란", "난백", "난황", "계런"],
    "우유": ["우유", "유청", "탈지분유", "전지분유", "유당", "카제인", "버터", "치즈", "유유"],
    "땅콩": ["땅콩", "피넛"],
    "대두": ["대두", "콩", "대두유", "간장", "된장", "두부", "대도"],
    "밀": ["밀", "소맥분", "밀가루", "글루텐"],
    "새우": ["새우", "새유"],
    "게": ["게", "꽃게", "대게"],
    "돼지고기": ["돼지고기", "돈육", "돼지"],
    "쇠고기": ["쇠고기", "소고기", "우육"],
    "닭고기": ["닭고기", "계육", "닭"],
    "고등어": ["고등어"],
    "조개류": ["조개류", "조개", "굴", "전복", "홍합", "바지락", "조게류"],
    "오징어": ["오징어"],
    "토마토": ["토마토"],
}

# 하드코딩된 딕셔너리 대신 Supabase DB에서 최신 데이터를 가져옴
try:
    ALLERGEN_DB = get_allergen_db()
except Exception as e:
    print(f"[경고] 알레르겐 DB 연결 실패 → 기본 알레르겐 사전으로 실행합니다. ({type(e).__name__}: {e})")
    ALLERGEN_DB = DEFAULT_ALLERGEN_DB

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