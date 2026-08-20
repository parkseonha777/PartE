"""
공공데이터포털 HACCP API의 allergy 필드를 전부 훑어서,
현재 allergens 테이블(14개)에 없는 알레르겐 이름을 찾아내는 분석 스크립트.

담당: 백엔드 A (데이터/DB)

실행: python db/find_missing_allergens.py

이 스크립트는 DB에 아무것도 저장하지 않고, 그냥 "뭐가 빠져있는지" 화면에 보여주기만 함.
"""

import os
import sys
import time
from collections import Counter
import requests
import psycopg2
import xml.etree.ElementTree as ET
from dotenv import load_dotenv

# Windows 콘솔/로그 파일에 한글이 깨지는 문제 방지 (기본 CP949 대신 UTF-8 강제)
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

load_dotenv()

API_KEY = os.getenv("FOODSAFETY_API_KEY")
DATABASE_URL = os.getenv("DATABASE_URL")

BASE_URL = "https://apis.data.go.kr/B553748/CertImgListServiceV3/getCertImgListServiceV3"
NUM_OF_ROWS = 100
REQUEST_DELAY_SEC = 0.3


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


def collect_allergy_terms() -> Counter:
    """전체 페이지를 돌면서 allergy 필드에 등장하는 개별 단어를 전부 센다."""
    counter = Counter()
    page_no = 1

    while True:
        root = fetch_page(page_no)
        body = root.find("body")
        total_count = int(body.findtext("totalCount", default="0"))
        items_el = body.find("items")

        if items_el is None:
            break

        items = items_el.findall("item")
        if not items:
            break

        for item in items:
            allergy_text = item.findtext("allergy") or ""
            allergy_text = allergy_text.strip()
            if allergy_text in ("", "없음", "해당없음"):
                continue
            for term in allergy_text.replace("함유", "").split(","):
                term = term.strip()
                if term:
                    counter[term] += 1

        print(f"[진행] {page_no}페이지 처리 (누적 {min(page_no * NUM_OF_ROWS, total_count)}/{total_count}건)")

        if page_no * NUM_OF_ROWS >= total_count:
            break

        page_no += 1
        time.sleep(REQUEST_DELAY_SEC)

    return counter


def main():
    if not API_KEY:
        raise RuntimeError("FOODSAFETY_API_KEY가 .env에 설정되어 있지 않습니다.")

    print("[시작] allergy 필드 전체 수집 중...\n")
    term_counts = collect_allergy_terms()

    # 현재 DB에 등록된 allergen 이름 가져오기
    known_names = set()
    if DATABASE_URL:
        conn = psycopg2.connect(DATABASE_URL)
        cur = conn.cursor()
        cur.execute("SELECT name FROM allergens")
        known_names = {row[0] for row in cur.fetchall()}
        cur.close()
        conn.close()

    print(f"\n=== 현재 DB에 등록된 알레르겐 ({len(known_names)}개) ===")
    print(", ".join(sorted(known_names)))

    missing = {term: count for term, count in term_counts.items() if term not in known_names}
    missing_sorted = sorted(missing.items(), key=lambda x: -x[1])

    print(f"\n=== DB에 없는 알레르겐 후보 ({len(missing_sorted)}개, 등장 빈도순) ===")
    for term, count in missing_sorted:
        print(f"{term}: {count}건")


if __name__ == "__main__":
    main()
