"""
Supabase(PostgreSQL)에 저장된 알레르겐/동의어 데이터를,
allergen_matcher.py가 쓰던 것과 같은 형태(ALLERGEN_DB 딕셔너리)로
가져오는 모듈.

담당: 백엔드 A (데이터/DB)
용도: 백엔드 B(OCR 담당)가 원래 하드코딩해서 쓰던 ALLERGEN_DB 대신,
      이 모듈의 get_allergen_db()를 호출해서 항상 최신 DB 데이터를 쓸 수 있게 함.

사용 예시 (백엔드 B 쪽 코드):

    from db.allergen_lookup import get_allergen_db

    ALLERGEN_DB = get_allergen_db()   # 기존 하드코딩 딕셔너리 대신 이거 사용
    # 이후 allergen_matcher.py의 contains_allergen(), find_allergens_in_text() 등은
    # 그대로 사용 가능 (ALLERGEN_DB 형태가 동일하므로)
"""

import os
import psycopg2
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")


def get_allergen_db() -> dict:
    """
    Supabase에서 allergens + allergen_synonyms를 읽어와서
    기존 allergen_matcher.py의 ALLERGEN_DB와 동일한 형태로 반환.

    반환 형태 예시:
    {
        "난류": ["난류", "계란", "전란", "난백", "난황", ...],
        "우유": ["우유", "분유", "유청", ...],
        ...
    }
    """
    if not DATABASE_URL:
        raise RuntimeError("DATABASE_URL이 .env에 설정되어 있지 않습니다.")

    conn = psycopg2.connect(DATABASE_URL)
    cur = conn.cursor()

    cur.execute("SELECT allergen_id, name FROM allergens")
    id_to_name = {allergen_id: name for allergen_id, name in cur.fetchall()}

    cur.execute("SELECT allergen_id, synonym FROM allergen_synonyms ORDER BY synonym_id")
    synonym_rows = cur.fetchall()

    cur.close()
    conn.close()

    allergen_db = {name: [] for name in id_to_name.values()}
    for allergen_id, synonym in synonym_rows:
        name = id_to_name.get(allergen_id)
        if name:
            allergen_db[name].append(synonym)

    return allergen_db


def get_allergen_names() -> list[str]:
    """알레르겐 이름 목록만 필요할 때 (예: 사용자 알레르기 선택 UI 드롭다운용)"""
    return list(get_allergen_db().keys())


def find_food_by_name(food_name: str, limit: int = 5) -> list[dict]:
    """
    제품명으로 이미 DB에 있는 식품인지 검색.
    OCR 없이 제품명만으로 원재료/알레르겐 정보를 바로 찾을 수 있으면
    OCR 단계를 건너뛰어 속도를 높일 수 있음 (선택적 최적화).

    반환: [{"food_id": 1, "food_name": "...", "raw_material": "...", "allergens": ["난류", "우유"]}, ...]
    """
    if not DATABASE_URL:
        raise RuntimeError("DATABASE_URL이 .env에 설정되어 있지 않습니다.")

    conn = psycopg2.connect(DATABASE_URL)
    cur = conn.cursor()

    cur.execute(
        """
        SELECT f.food_id, f.food_name, f.raw_material,
               COALESCE(array_agg(a.name) FILTER (WHERE a.name IS NOT NULL), '{}')
        FROM foods f
        LEFT JOIN food_allergen_map m ON f.food_id = m.food_id
        LEFT JOIN allergens a ON m.allergen_id = a.allergen_id
        WHERE f.food_name ILIKE %s
        GROUP BY f.food_id, f.food_name, f.raw_material
        LIMIT %s
        """,
        (f"%{food_name}%", limit),
    )
    rows = cur.fetchall()
    cur.close()
    conn.close()

    return [
        {
            "food_id": food_id,
            "food_name": name,
            "raw_material": raw_material,
            "allergens": allergens,
        }
        for food_id, name, raw_material, allergens in rows
    ]


if __name__ == "__main__":
    # 간단한 동작 테스트용 (python db/allergen_lookup.py 로 직접 실행 가능)
    db = get_allergen_db()
    print(f"알레르겐 {len(db)}개 로드됨\n")
    for name, synonyms in db.items():
        print(f"{name}: {synonyms}")
