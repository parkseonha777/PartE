"""
식약처(식품안전나라) I2520 서비스 데이터를 가져와서
PostgreSQL foods / food_allergen_map 테이블에 적재하는 스크립트.

담당: 백엔드 A (데이터/DB)

실행: python db/sync_foodsafety.py
"""

import os
import requests
import psycopg2
from datetime import datetime
from dotenv import load_dotenv

load_dotenv()

API_KEY = os.getenv("FOODSAFETY_API_KEY")
DATABASE_URL = os.getenv("DATABASE_URL")
SERVICE_ID = "I2520"
BASE_URL = "http://openapi.foodsafetykorea.go.kr/api"

PAGE_SIZE = 1000  # 식약처 API는 한 번에 최대 1000건 정도 권장


def fetch_page(start: int, end: int) -> dict:
    """지정한 범위(start~end)의 데이터를 한 페이지 가져온다."""
    url = f"{BASE_URL}/{API_KEY}/{SERVICE_ID}/json/{start}/{end}"
    resp = requests.get(url, timeout=30)
    resp.raise_for_status()
    return resp.json()


def fetch_all_rows() -> list[dict]:
    """전체 데이터를 페이지네이션하며 모두 가져온다."""
    all_rows = []
    start = 1
    while True:
        end = start + PAGE_SIZE - 1
        data = fetch_page(start, end)

        service_data = data.get(SERVICE_ID)
        if not service_data:
            print("[경고] 응답에 서비스 데이터가 없습니다:", data)
            break

        result_code = service_data.get("RESULT", {}).get("CODE")
        if result_code and result_code != "INFO-000":
            # INFO-200: 더 이상 데이터 없음(정상 종료), 그 외는 에러
            if result_code == "INFO-200":
                print("[안내] 더 이상 가져올 데이터가 없습니다. 종료.")
            else:
                print(f"[에러] API 응답 코드: {result_code} - {service_data.get('RESULT', {}).get('MESSAGE')}")
            break

        rows = service_data.get("row", [])
        if not rows:
            break

        all_rows.extend(rows)
        print(f"[진행] {start}~{end} 구간 {len(rows)}건 수집 (누적 {len(all_rows)}건)")

        if len(rows) < PAGE_SIZE:
            # 마지막 페이지
            break

        start += PAGE_SIZE

    return all_rows


def insert_rows(conn, rows: list[dict]) -> int:
    """
    가져온 원본 데이터를 foods 테이블에 적재.
    실제 응답 필드명(FOOD_NM, MTRAL_NM 등)은 서비스 문서/실제 응답을 보고
    아래 컬럼 매핑을 맞춰야 합니다. 우선 흔히 쓰이는 필드명으로 초안을 잡아둡니다.
    """
    cur = conn.cursor()
    inserted = 0

    for row in rows:
        # TODO: 실제 응답 JSON의 키 이름으로 교체 필요 (예: row.get("FOOD_NM"))
        food_name = row.get("FOOD_NM") or row.get("PRDLST_NM") or "이름없음"
        raw_material = row.get("MTRAL_NM") or row.get("RAWMTRL_NM") or ""
        manufacturer = row.get("BSSH_NM") or row.get("MANUFACTURER") or None
        source_id = row.get("SEQ") or row.get("NUM") or None

        cur.execute(
            """
            INSERT INTO foods (source_id, food_name, raw_material, manufacturer, synced_at)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (source_id, food_name, raw_material, manufacturer, datetime.now()),
        )
        inserted += 1

    conn.commit()
    cur.close()
    return inserted


def map_allergens(conn) -> int:
    """
    foods.raw_material 텍스트를 allergen_synonyms와 대조해서
    food_allergen_map에 위험(원재료 직접 포함) 매핑을 채운다.
    """
    cur = conn.cursor()

    cur.execute("SELECT allergen_id, synonym FROM allergen_synonyms")
    synonym_rows = cur.fetchall()  # [(allergen_id, synonym), ...]

    cur.execute("SELECT food_id, raw_material FROM foods WHERE raw_material IS NOT NULL")
    food_rows = cur.fetchall()

    mapped = 0
    for food_id, raw_material in food_rows:
        if not raw_material:
            continue
        matched_allergen_ids = set()
        for allergen_id, synonym in synonym_rows:
            if synonym in raw_material:
                matched_allergen_ids.add(allergen_id)

        for allergen_id in matched_allergen_ids:
            cur.execute(
                """
                INSERT INTO food_allergen_map (food_id, allergen_id, risk_level)
                VALUES (%s, %s, '위험')
                ON CONFLICT (food_id, allergen_id) DO NOTHING
                """,
                (food_id, allergen_id),
            )
            mapped += 1

    conn.commit()
    cur.close()
    return mapped


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
        print("[시작] 식약처 API에서 데이터 수집 중...")
        rows = fetch_all_rows()
        print(f"[완료] 총 {len(rows)}건 수집")

        inserted = insert_rows(conn, rows)
        print(f"[완료] {inserted}건 foods 테이블에 적재")

        mapped = map_allergens(conn)
        print(f"[완료] {mapped}건 알레르겐 매핑 생성")

        cur = conn.cursor()
        cur.execute(
            "UPDATE sync_log SET finished_at=%s, status='SUCCESS', total_rows=%s WHERE sync_id=%s",
            (datetime.now(), inserted, sync_id),
        )
        conn.commit()
        cur.close()

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
