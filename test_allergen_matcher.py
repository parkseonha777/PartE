"""
allergen_matcher 규칙 판정 테스트 (DB 없이 실행 — 기본 알레르겐 사전 사용)

실행: python -m pytest test_allergen_matcher.py -v
"""

import os

os.environ["DATABASE_URL"] = ""  # DB 연결 시도 없이 기본 사전으로

from allergen_matcher import find_allergens_in_raw  # noqa: E402

# 오!감자 감자그라탕맛 성분표 (OCR 줄 단위)
OGAMJA = [
    "원재료명 감자플레이크(폴란드산, 미국산), 식물성유지(팜올레인유 말레이시아산,",
    "그라탕시즈닝[아스파탐(감미료/페닐알라닌 함유)], 밀가루, 식염, 효소제",
    "밀, 우유, 대두, 쇠고기, 오징어, 새우 함유",
    "포장재질 내포장재질:폴리프로필렌/지퍼:폴리에틸렌",
    "•달걀, 땅콩, 호두, 복숭아, 토마토, 돼지고기, 닭고기,",
    "게, 고등어, 조개류(굴, 홍합 포함) 혼입가능•제품의 신",
    "선도 보존을 위해 질소충전 하였습니다.",
]


def test_ogamja_contamination_is_caution():
    r = find_allergens_in_raw(OGAMJA, ["대두", "밀", "호두", "우유", "달걀", "고등어", "토마토"])
    assert set(r["위험"]) == {"대두", "밀", "우유"}
    assert set(r["주의"]) == {"호두", "달걀", "고등어", "토마토"}


def test_contains_line_without_delimiter_stays_danger():
    """구분 기호를 OCR이 놓쳐도 '함유' 앞의 성분은 위험으로 남아야 한다"""
    lines = ["밀 우유 대두 함유 달걀 땅콩 호두 혼입가능"]
    r = find_allergens_in_raw(lines, ["우유", "호두"])
    assert r["위험"] == ["우유"] and r["주의"] == ["호두"]


def test_same_facility_phrase_is_caution():
    """육개장 사례: '...를 사용한 제품과 같은 시설에서 제조'"""
    lines = [
        "알레르기 유발물질: 밀, 대두, 우유, 계란, 돼지고기, 쇠고기, 닭고기 함유",
        "메밀, 땅콩, 고등어, 게, 새우, 토마토, 호두, 오징어, 조개류(굴, 전복, 홍합 포함), 잣을 사용한 제품과 같은 시설에서 제조",
    ]
    r = find_allergens_in_raw(lines, ["난류", "새우", "호두", "대두"])
    assert set(r["위험"]) == {"난류", "대두"}
    assert set(r["주의"]) == {"새우", "호두"}


def test_ocr_typo_marker_hunil():
    """EasyOCR이 '혼입'을 '훈일'로 읽은 경우"""
    r = find_allergens_in_raw(["조개류(국 통합 포함) 훈일가능"], ["조개류"])
    assert r["주의"] == ["조개류"]


def test_legacy_start_marker_still_works():
    lines = ["유유 대도 밀 새유", "이제품은계런 땅콩 게를 사용한 제품과 같은 제조 시설에서 제조"]
    r = find_allergens_in_raw(lines, ["난류", "우유", "새우", "고등어"])
    assert r == {"위험": ["우유", "새우"], "주의": ["난류"], "안전": ["고등어"]}


def test_long_text_without_delimiter_limits_warning_span():
    """구분 기호가 전혀 없을 때 원재료 전체가 주의로 넘어가지 않게 한다"""
    ingredients = "우유 " + "감자플레이크 식물성유지 변성전분 " * 6
    r = find_allergens_in_raw([ingredients + "땅콩 혼입가능"], ["우유", "땅콩"])
    assert r["위험"] == ["우유"] and r["주의"] == ["땅콩"]


# ---- 영어(수입식품) 성분표 ----

BIG_TRAIN = [
    "INGREDIENTS: SUGAR, PARTIALLY HYDROGENATED COCONUT OIL, CORN SYRUP SOLIDS,",
    "HEATH® TOFFEE (SUGAR, BUTTER, PARTIALLY HYDROGENATED SOYBEAN OIL, ALMONDS, SALT,",
    "COCOA BUTTER, SOY LECITHIN), MALTODEXTRIN, COCOA POWDER.",
    "CONTAINS: MILK, SOY, ALMONDS.",
    "MANUFACTURED IN A FACILITY THAT ALSO PROCESSES WHEAT, EGGS, PEANUTS AND WALNUTS.",
]


def test_english_label_contains_and_facility():
    r = find_allergens_in_raw(BIG_TRAIN, ["대두", "우유", "밀", "난류", "땅콩", "호두", "새우"])
    assert set(r["위험"]) == {"대두", "우유"}
    assert set(r["주의"]) == {"밀", "난류", "땅콩", "호두"}
    assert r["안전"] == ["새우"]


def test_english_may_contain():
    r = find_allergens_in_raw(["Ingredients: rice flour, salt. May contain peanuts."], ["땅콩", "밀"])
    assert r["주의"] == ["땅콩"]
    assert r["안전"] == ["밀"]  # rice flour(쌀가루)는 밀이 아님


def test_english_word_start_only():
    """graham 속 ham, buckwheat 속 wheat 는 매칭하지 않는다"""
    r = find_allergens_in_raw(["Ingredients: graham crackers, buckwheat"], ["돼지고기", "밀", "메밀"])
    assert r["위험"] == ["메밀"]
    assert set(r["안전"]) == {"돼지고기", "밀"}


def test_english_case_insensitive_and_plural():
    r = find_allergens_in_raw(["Contains Eggs and Shrimps"], ["난류", "새우"])
    assert set(r["위험"]) == {"난류", "새우"}


def test_english_look_alikes_excluded():
    """cocoa butter는 유제품이 아니고, enriched flour는 밀이다"""
    r = find_allergens_in_raw(["Ingredients: cocoa butter, enriched flour, soy milk"], ["우유", "밀", "대두"])
    assert set(r["위험"]) == {"밀", "대두"}
    assert r["안전"] == ["우유"]


def test_glutinous_rice_is_not_wheat():
    """찹쌀(GLUTINOUS RICE)이 gluten과 유사도 0.83으로 밀에 걸리던 오탐"""
    lines = ["RICE, PALM OIL(FAT), SUGAR, GLUTINOUS RICE POWDER, 간장분말, POTATO STARCH"]
    r = find_allergens_in_raw(lines, ["밀", "대두"])
    assert r["위험"] == ["대두"] and r["안전"] == ["밀"]