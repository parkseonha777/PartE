"""
공공데이터포털 - 한국식품안전관리인증원(HACCP) 제품이미지 및 포장지표기정보
(CertImgListServiceV3)를 가져와서 Supabase(PostgreSQL)에 적재하는 스크립트.

담당: 백엔드 A (데이터/DB)

실행: python db/sync_foodsafety.py

v2: 배치(묶음) INSERT로 속도 개선.
    - 기존: 14,672건을 한 건씩 INSERT (왕복 14,672번 이상) -> 매우 느림
    - 개선: execute_values로 한 번에 수백~수천 건씩 묶어서 INSERT -> 왕복 수십 번 수준
"""

import os
import time
import requests
import psycopg2
from psycopg2.extras import execute_values
import xml.etree.ElementTree as ET
from datetime import datetime
from dotenv import load_dotenv

load_dotenv()

API_KEY = os.getenv("FOODSAFETY_API_KEY")
DATABASE_URL = os.getenv("DATABASE_URL")

BASE_URL = "https://apis.data.go.kr/B553748/CertImgListServiceV3/getCertImgListServiceV3"
NUM_OF_ROWS = 100
MAX_PAGES = None
REQUEST_DELAY_SEC = 0.3
BATCH_SIZE = 1000  # 한 번에 DB에 넣을 묶음 크기


def fetch_page(page_no: int) -> ET.Element:
    params = {
        "ServiceKey": API_KEY,
        "pageNo": page_no,
        "numOfRows": NUM_OF_ROWS,
        "returnType": "xml",
    }
    resp = requests.get(BASE_URL, params=params, timeout=30)
    resp.raise_for_status()
    return ET.fromstring(resp.text)


def parse_items(root: ET.Element):
    header = root.find("header")
    result_code = header.findtext("resultCode") if header is not None else None
    if result_code and result_code != "OK":
        message = header.findtext("resultMessage")
        raise RuntimeError(f"API 에러: {result_code} - {message}")

    body = root.find("body")
    total_count = int(body.findtext("totalCount", default="0"))
    items = []
    items_el = body.find("items")
    if items_el is not None:
        for item in items_el.findall("item"):
            items.append({
                "prdlstReportNo": item.findtext("prdlstReportNo"),
                "prdlstNm": item.findtext("prdlstNm"),
                "rawmtrl": item.findtext("rawmtrl"),
                "allergy": item.findtext("allergy"),
                "prdkind": item.findtext("prdkind"),
                "manufacture": item.findtext("manufacture"),
            })
    return items, total_count


def fetch_all_rows() -> list[dict]:
    all_rows = []
    page_no = 1

    while True:
        root = fetch_page(page_no)
        items, total_count = parse_items(root)

        if not items:
            print(f"[안내] {page_no}페이지에 더 이상 데이터가 없습니다. 종료.")
            break

        all_rows.extend(items)
        print(f"[수집] {page_no}페이지 {len(items)}건 (누적 {len(all_rows)}/{total_count}건)")

        if len(all_rows) >= total_count:
            break
        if MAX_PAGES and page_no >= MAX_PAGES:
            print(f"[안내] 테스트 제한({MAX_PAGES}페이지)에 도달하여 종료합니다.")
            break

        page_no += 1
        time.sleep(REQUEST_DELAY_SEC)

    return all_rows


def load_allergen_lookup(conn):
    """allergens, allergen_synonyms 테이블을 한 번만 읽어서 파이썬 dict로 캐싱."""
    cur = conn.cursor()
    cur.execute("SELECT allergen_id, name FROM allergens")
    name_to_id = {name: allergen_id for allergen_id, name in cur.fetchall()}

    cur.execute("SELECT allergen_id, synonym FROM allergen_synonyms")
    synonym_to_id = list(cur.fetchall())  # [(allergen_id, synonym), ...]
    cur.close()
    return name_to_id, synonym_to_id


def build_food_records(rows: list[dict], name_to_id: dict, synonym_to_id: list):
    """
    수집한 rows를 (foods insert용 값, 매핑 계산용 allergen_id set) 리스트로 변환.
    DB 왕복 없이 파이썬 메모리에서 전부 계산.
    """
    food_values = []
    allergen_id_sets = []  # food_values와 같은 순서로 대응

    for row in rows:
        food_name = row.get("prdlstNm") or "이름없음"
        raw_material = row.get("rawmtrl") or ""
        manufacturer = row.get("manufacture")
        source_id = row.get("prdlstReportNo")

        food_values.append((source_id, food_name, raw_material, manufacturer, datetime.now()))

        matched_ids = set()

        # 1) allergy 필드 직접 매칭 (가장 신뢰도 높음)
        allergy_text = row.get("allergy") or ""
        if allergy_text.strip() not in ("없음", "해당없음", ""):
            for name in [a.strip() for a in allergy_text.replace("함유", "").split(",") if a.strip()]:
                if name in name_to_id:
                    matched_ids.add(name_to_id[name])

        # 2) 원재료 텍스트 보조 매칭 (동의어/오타 패턴 포함)
        if raw_material:
            for allergen_id, synonym in synonym_to_id:
                if synonym in raw_material:
                    matched_ids.add(allergen_id)

        allergen_id_sets.append(matched_ids)

    return food_values, allergen_id_sets


def insert_foods_batch(conn, food_values: list[tuple]) -> list[int]:
    """foods 테이블에 배치 INSERT 후, 생성된 food_id 리스트를 입력 순서 그대로 반환."""
    cur = conn.cursor()
    food_ids = []

    for i in range(0, len(food_values), BATCH_SIZE):
        chunk = food_values[i:i + BATCH_SIZE]
        result = execute_values(
            cur,
            """
            INSERT INTO foods (source_id, food_name, raw_material, manufacturer, synced_at)
            VALUES %s
            RETURNING food_id
            """,
            chunk,
            fetch=True,
        )
        food_ids.extend([r[0] for r in result])
        conn.commit()
        print(f"[적재] foods {min(i + BATCH_SIZE, len(food_values))}/{len(food_values)}건")

    cur.close()
    return food_ids


def insert_allergen_map_batch(conn, food_ids: list[int], allergen_id_sets: list[set]) -> int:
    """food_allergen_map 테이블에 배치 INSERT."""
    map_values = []
    for food_id, allergen_ids in zip(food_ids, allergen_id_sets):
        for allergen_id in allergen_ids:
            map_values.append((food_id, allergen_id, "위험"))

    if not map_values:
        return 0

    cur = conn.cursor()
    total = 0
    for i in range(0, len(map_values), BATCH_SIZE):
        chunk = map_values[i:i + BATCH_SIZE]
        execute_values(
            cur,
            """
            INSERT INTO food_allergen_map (food_id, allergen_id, risk_level)
            VALUES %s
            ON CONFLICT (food_id, allergen_id) DO NOTHING
            """,
            chunk,
        )
        conn.commit()
        total += len(chunk)
        print(f"[적재] food_allergen_map {min(i + BATCH_SIZE, len(map_values))}/{len(map_values)}건")

    cur.close()
    return total


def main():
    if not API_KEY:
        raise RuntimeError("FOODSAFETY_API_KEY가 .env에 설정되어 있지 않습니다.")
    if not DATABASE_URL:
        raise RuntimeError("DATABASE_URL이 .env에 설정되어 있지 않습니다.")

    conn = psycopg2.connect(DATABASE_URL)
    cur = conn.cursor()
    cur.execute("INSERT INTO sync_log (status) VALUES ('RUNNING') RETURNING sync_id")
    sync_id = cur.fetchone()[0]
    conn.commit()
    cur.close()

    try:
        print("[시작] 공공데이터포털 HACCP API에서 데이터 수집 중...")
        rows = fetch_all_rows()
        print(f"[완료] 총 {len(rows)}건 수집\n")

        print("[준비] 알레르겐 테이블 캐싱 중...")
        name_to_id, synonym_to_id = load_allergen_lookup(conn)

        print("[준비] 매칭 계산 중 (DB 왕복 없이 메모리에서 처리)...")
        food_values, allergen_id_sets = build_food_records(rows, name_to_id, synonym_to_id)

        print(f"\n[적재 시작] foods 테이블에 {len(food_values)}건 배치 INSERT...")
        food_ids = insert_foods_batch(conn, food_values)
        print(f"[완료] foods {len(food_ids)}건 적재\n")

        print("[적재 시작] food_allergen_map 배치 INSERT...")
        mapped = insert_allergen_map_batch(conn, food_ids, allergen_id_sets)
        print(f"[완료] food_allergen_map {mapped}건 적재\n")

        cur = conn.cursor()
        cur.execute(
            "UPDATE sync_log SET finished_at=%s, status='SUCCESS', total_rows=%s WHERE sync_id=%s",
            (datetime.now(), len(food_ids), sync_id),
        )
        conn.commit()
        cur.close()

        print("=== 전체 동기화 완료 ===")

    except Exception as e:
        cur = conn.cursor()
        cur.execute(
            "UPDATE sync_log SET finished_at=%s, status='FAILED', error_message=%s WHERE sync_id=%s",
            (datetime.now(), str(e), sync_id),
        )
        conn.commit()
        cur.close()
        raise

    finally:
        conn.close()


if __name__ == "__main__":
    main()