import re
from difflib import SequenceMatcher
from DB.allergen_lookup import get_allergen_db
from text_cleaner import clean_ocr_text

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
    "호두": ["호두"],
    "잣": ["잣"],
    "복숭아": ["복숭아"],
    "메밀": ["메밀"],
}

# 영어(수입식품) 성분표용 동의어. DB 연결 여부와 관계없이 항상 합쳐서 쓴다.
# 영어는 단어 시작 위치에서만 매칭한다 (예: "graham" 속 "ham", "buckwheat" 속 "wheat" 제외).
ENGLISH_SYNONYMS = {
    "난류": ["egg", "albumin", "ovalbumin", "mayonnaise"],
    "우유": ["milk", "buttermilk", "butter", "cream", "cheese", "whey", "casein", "caseinate",
            "lactose", "yogurt", "ghee", "dairy"],
    "땅콩": ["peanut", "groundnut"],
    "대두": ["soy", "soya", "soybean", "lecithin", "tofu", "edamame", "miso"],
    "밀": ["wheat", "flour", "gluten", "semolina", "durum", "spelt", "farina", "bran"],
    "새우": ["shrimp", "prawn"],
    "게": ["crab"],
    "돼지고기": ["pork", "ham", "bacon", "lard", "gelatin"],
    "쇠고기": ["beef", "veal"],
    "닭고기": ["chicken"],
    "고등어": ["mackerel"],
    "조개류": ["shellfish", "clam", "oyster", "mussel", "abalone", "scallop", "mollusc", "mollusk"],
    "오징어": ["squid", "calamari"],
    "토마토": ["tomato"],
    "호두": ["walnut"],
    "잣": ["pine nut"],
    "복숭아": ["peach"],
    "메밀": ["buckwheat"],
}


# 영어 동의어와 겹치지만 해당 알레르겐이 아닌 표현. 매칭 전에 이 표현을 지우고 찾는다.
# 예: cocoa butter(코코아 지방, 유제품 아님), rice flour(쌀가루, 밀 아님)
ENGLISH_NOT_ALLERGEN = {
    "우유": ["cocoa butter", "peanut butter", "shea butter", "almond butter", "apple butter",
            "nut butter", "coconut milk", "almond milk", "oat milk", "rice milk", "soy milk",
            "coconut cream", "cream of tartar"],
    "밀": ["rice flour", "corn flour", "cornflour", "oat flour", "almond flour", "coconut flour",
          "potato flour", "tapioca flour", "chickpea flour", "buckwheat flour", "glutinous"],
    "난류": ["eggplant"],
}


def _with_english(db: dict) -> dict:
    merged = {name: list(syns) for name, syns in db.items()}
    for name, english in ENGLISH_SYNONYMS.items():
        merged.setdefault(name, [name])
        merged[name] += [w for w in english if w not in merged[name]]
    return merged


# 하드코딩된 딕셔너리 대신 Supabase DB에서 최신 데이터를 가져옴
try:
    ALLERGEN_DB = _with_english(get_allergen_db())
except Exception as e:
    print(f"[경고] 알레르겐 DB 연결 실패 → 기본 알레르겐 사전으로 실행합니다. ({type(e).__name__}: {e})")
    ALLERGEN_DB = _with_english(DEFAULT_ALLERGEN_DB)

WARNING_START_MARKERS = ["이 제품은", "이제품은", "본 제품은", "본제품은", "이 제품에는"]

# 문장 끝에 붙는 혼입 가능 표시. 예: "달걀, 땅콩, 호두 혼입가능", "...를 사용한 제품과 같은 시설에서 제조"
# "훈입", "흔입", "훈일"은 EasyOCR이 "혼입"을 자주 잘못 읽는 형태
CONTAMINATION_MARKERS = [
    "혼입", "훈입", "흔입", "훈일",
    "혼임", "혼인", "혼일", "호이", "호인",   # EasyOCR이 "혼입"을 읽을 때 나오는 오타
    "같은 시설", "같은시설", "동일 시설", "동일시설",
    "같은 제조", "같은제조", "제조 시설", "제조시설",
]

# "~ 함유" 표시. 혼입 문구 앞에서 "실제 함유 알레르겐" 목록과 "혼입 가능" 목록을 가르는 경계로 쓴다.
# EasyOCR이 "함유"를 "함을", "함우", "하요" 등으로 잘못 읽어서 오타까지 넓게 잡는다.
# 경계를 넓게 잡으면 혼입 문구로 넘기는 범위가 줄어 더 위험한 쪽(위험 판정)으로 기울므로 안전하다.
CONTAINS_PATTERN = re.compile(r"[함합하][유을우윤위요욜옹]")

# 영어 혼입 표시. 한국어와 달리 알레르겐이 표시 "뒤"에 온다.
# 예: "MAY CONTAIN PEANUTS", "MANUFACTURED IN A FACILITY THAT ALSO PROCESSES TREE NUTS"
# 표시부터 그 문장 끝까지를 주의 문구로 본다. ("CONTAINS: ..." 는 원재료와 같이 위험)
ENGLISH_CONTAMINATION_MARKERS = [
    "may contain", "may also contain", "facility", "same equipment", "shared equipment",
    "also processes", "processed on", "produced on", "made on equipment", "traces of",
]

# 성분표에서 문장을 나누는 기호 (글머리표, 마침표, 줄바꿈, 슬래시)
SENTENCE_DELIMITERS = r"[•·∙ㆍ\.\n/]"

# 혼입 표시 앞쪽에서 주의 문구로 볼 최대 글자 수.
# 구분 기호를 OCR이 놓쳤을 때 원재료명까지 주의 문구로 넘어가 위험 판정이 빠지는 것을 막는다.
MAX_WARNING_SPAN = 100


def similarity(a: str, b: str) -> float:
    return SequenceMatcher(None, a, b).ratio()


def _is_english(word: str) -> bool:
    return word.isascii()


def contains_allergen(text: str, allergen: str, threshold: float = 0.8) -> bool:
    synonyms = ALLERGEN_DB.get(allergen, [allergen])
    lower_text = text.lower()
    for phrase in ENGLISH_NOT_ALLERGEN.get(allergen, []):
        lower_text = lower_text.replace(phrase, " ")

    for synonym in synonyms:
        if _is_english(synonym):
            word = synonym.lower()
            # 단어 시작에서만 매칭 (복수형 eggs, peanuts 등은 허용)
            if re.search(r"(?<![a-z])" + re.escape(word), lower_text):
                return True
            # 짧은 영어 단어는 오탐이 많아 유사도 매칭 제외 (crab↔carb 등)
            if len(word) >= 6 and _fuzzy_contains(lower_text, word, threshold):
                return True
        else:
            if synonym in text:
                return True
            if len(synonym) >= 4 and _fuzzy_contains(text, synonym, threshold):
                return True

    return False


def _fuzzy_contains(text: str, word: str, threshold: float) -> bool:
    """OCR 오타 대응: 같은 길이의 구간 중 하나라도 유사도가 threshold 이상이면 포함으로 본다."""
    L = len(word)
    for i in range(len(text) - L + 1):
        if similarity(word, text[i:i + L]) >= threshold:
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


def split_raw_ingredient_and_warning(raw_lines: list[str]) -> tuple[list[str], list[str]]:
    """
    정제 전 OCR 원문을 원재료 부분과 주의(혼입 가능) 부분으로 나눈다.
    문장 구분 기호가 남아 있는 원문 단계에서 나눠야 혼입 문구의 범위를 잡을 수 있다.

    1. "이 제품은" 등 시작 표지 뒤는 모두 주의 문구 (기존 방식)
    2. 그 앞부분은 문장 단위로 나누고, 혼입 표지가 있는 문장은
       직전 "함유" 또는 최대 MAX_WARNING_SPAN 글자까지만 주의 문구로 본다.
    """
    text = " ".join(raw_lines)

    start_positions = [text.find(m) for m in WARNING_START_MARKERS if m in text]
    if start_positions:
        cut = min(start_positions)
        head, tail = text[:cut], text[cut:]
    else:
        head, tail = text, ""

    ingredient_parts, warning_parts = [], []
    for seg in re.split(SENTENCE_DELIMITERS, head):
        lower = seg.lower()
        en_positions = [lower.find(m) for m in ENGLISH_CONTAMINATION_MARKERS if m in lower]
        if en_positions:
            en_pos = min(en_positions)
            ingredient_parts.append(seg[:en_pos])
            warning_parts.append(seg[en_pos:])
            continue

        positions = [seg.find(m) for m in CONTAMINATION_MARKERS if m in seg]
        if not positions:
            ingredient_parts.append(seg)
            continue

        marker_pos = min(positions)
        before = seg[:marker_pos]
        # 가장 가까운(뒤쪽) "함유" 표지 다음부터를 혼입 문구로 본다
        start = max((m.end() for m in CONTAINS_PATTERN.finditer(before)), default=0)
        start = max(start, marker_pos - MAX_WARNING_SPAN)

        ingredient_parts.append(seg[:start])
        warning_parts.append(seg[start:])

    if tail:
        warning_parts.append(tail)

    clean = lambda parts: [c for c in (clean_ocr_text(p) for p in parts) if c]
    return clean(ingredient_parts), clean(warning_parts)


def classify_allergens(ingredient_text: str, warning_text: str, user_allergens: list[str],
                       threshold: float = 0.8) -> dict:
    result = {"위험": [], "주의": [], "안전": []}
    for allergen in user_allergens:
        if contains_allergen(ingredient_text, allergen, threshold):
            result["위험"].append(allergen)
        elif contains_allergen(warning_text, allergen, threshold):
            result["주의"].append(allergen)
        else:
            result["안전"].append(allergen)
    return result


def find_allergens_in_raw(raw_lines: list[str], user_allergens: list[str], threshold: float = 0.8) -> dict:
    """서버(/scan, /scan/verify)가 쓰는 판정 함수. 정제 전 OCR 원문을 받는다."""
    ingredient_parts, warning_parts = split_raw_ingredient_and_warning(raw_lines)
    ingredient_text = " ".join(ingredient_parts)
    warning_text = " ".join(warning_parts)

    print(f"\n[디버그] 원재료 목록 텍스트: {ingredient_text}")
    print(f"[디버그] 경고 문구 텍스트: {warning_text}\n")

    return classify_allergens(ingredient_text, warning_text, user_allergens, threshold)


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