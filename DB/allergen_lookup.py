"""
Supabase(PostgreSQL)에 저장된 알레르겐/동의어/식품 데이터를 조회하는 모듈.

담당: 백엔드 A (데이터/DB)
용도:
  - get_allergen_db(): OCR 매칭 로직(allergen_matcher.py)이 쓰는 ALLERGEN_DB 딕셔너리 형태로 반환
  - find_food_by_name(): 제품명으로 이미 DB에 있는 식품인지 검색
  - get_alternatives(): 특정 알레르겐이 없는 식품을 추천 (대체 식품 화면용)
"""

import os
import psycopg2
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")


def get_allergen_db() -> dict:
    """
    Supabase에서 allergens + allergen_synonyms를 읽어와서
    allergen_matcher.py의 ALLERGEN_DB와 동일한 형태로 반환.
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
    """알레르겐 이름 목록만 필요할 때"""
    return list(get_allergen_db().keys())


def find_food_by_name(food_name: str, limit: int = 5) -> list[dict]:
    """제품명으로 DB에 있는 식품 검색."""
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


def get_alternatives(allergen_name: str, limit: int = 5) -> list[str]:
    """
    지정한 알레르겐이 포함되지 않은 식품명을 무작위로 추천.
    (현재는 카테고리 구분 없이 전체 DB에서 검색 — 추후 식품 유형(prdkind) 필드를
    추가하면 같은 카테고리 내에서만 추천하도록 개선 가능)
    """
    if not DATABASE_URL:
        raise RuntimeError("DATABASE_URL이 .env에 설정되어 있지 않습니다.")

    conn = psycopg2.connect(DATABASE_URL)
    cur = conn.cursor()

    cur.execute(
        """
        SELECT food_name FROM foods
        WHERE food_id NOT IN (
            SELECT fam.food_id FROM food_allergen_map fam
            JOIN allergens a ON fam.allergen_id = a.allergen_id
            WHERE a.name = %s
        )
        ORDER BY RANDOM()
        LIMIT %s
        """,
        (allergen_name, limit),
    )
    rows = cur.fetchall()
    cur.close()
    conn.close()

    return [r[0] for r in rows]


if __name__ == "__main__":
    db = get_allergen_db()
    print(f"알레르겐 {len(db)}개 로드됨\n")
    for name, synonyms in db.items():
        print(f"{name}: {synonyms}")