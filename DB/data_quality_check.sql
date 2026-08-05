-- =========================================
-- 팥이 (Pati) - 데이터 품질 확인 쿼리 모음
-- 담당: 백엔드 A (데이터/DB)
--
-- Supabase SQL Editor에서 하나씩 순서대로 실행하면서 결과 확인.
-- 각 쿼리 위에 "정상 범위" 기준을 적어둠.
-- =========================================


-- -----------------------------------------
-- 1. 전체 개수 확인 (기본 체크)
-- 정상: foods 14672, food_allergen_map 34704 근처, allergens 19, allergen_synonyms 113
-- -----------------------------------------
SELECT
    (SELECT COUNT(*) FROM foods) AS foods_count,
    (SELECT COUNT(*) FROM food_allergen_map) AS mapping_count,
    (SELECT COUNT(*) FROM allergens) AS allergens_count,
    (SELECT COUNT(*) FROM allergen_synonyms) AS synonyms_count;


-- -----------------------------------------
-- 2. 중복 데이터 확인
-- 정상: 0건 (같은 품목보고번호가 여러 번 들어가면 안 됨.
--       재실행할 때 TRUNCATE 안 하고 돌리면 중복 생길 수 있음)
-- -----------------------------------------
SELECT source_id, COUNT(*) AS cnt
FROM foods
WHERE source_id IS NOT NULL
GROUP BY source_id
HAVING COUNT(*) > 1
ORDER BY cnt DESC
LIMIT 20;


-- -----------------------------------------
-- 3. 원재료 정보가 비어있는 식품 비율
-- 참고: API 원본 데이터 자체에 원재료가 비어있는 경우가 있어서 0%는 아닐 수 있음.
--       근데 비율이 너무 높으면(예: 30% 이상) API 파싱을 의심해봐야 함.
-- -----------------------------------------
SELECT
    COUNT(*) FILTER (WHERE raw_material IS NULL OR raw_material = '') AS empty_raw_material,
    COUNT(*) AS total,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE raw_material IS NULL OR raw_material = '') / COUNT(*),
        1
    ) AS empty_percent
FROM foods;


-- -----------------------------------------
-- 4. 알레르겐이 하나도 매핑 안 된 식품 비율
-- 참고: 실제로 알레르겐이 없는 식품(과일, 채소 등)도 많아서 0%는 아님.
--       다만 원재료가 있는데도 매칭이 하나도 안 된 경우는 동의어 부족을 의심.
-- -----------------------------------------
SELECT
    COUNT(*) FILTER (WHERE f.food_id NOT IN (SELECT DISTINCT food_id FROM food_allergen_map)) AS unmapped_foods,
    COUNT(*) AS total_foods,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE f.food_id NOT IN (SELECT DISTINCT food_id FROM food_allergen_map))
        / COUNT(*),
        1
    ) AS unmapped_percent
FROM foods f;


-- -----------------------------------------
-- 5. 원재료가 "있는데" 알레르겐 매칭이 하나도 안 된 식품 샘플 20건
-- 이게 많으면: 동의어 테이블 보강이 더 필요하다는 신호
-- -----------------------------------------
SELECT f.food_id, f.food_name, f.raw_material
FROM foods f
WHERE f.raw_material IS NOT NULL
  AND f.raw_material != ''
  AND f.food_id NOT IN (SELECT DISTINCT food_id FROM food_allergen_map)
LIMIT 20;


-- -----------------------------------------
-- 6. 알레르겐별 매핑된 식품 개수 (분포 확인)
-- 정상: 19개 알레르겐 전부 최소 1건 이상 나와야 함.
--       0건인 알레르겐이 있으면 동의어가 부족하다는 뜻.
-- -----------------------------------------
SELECT a.name, COUNT(m.food_id) AS food_count
FROM allergens a
LEFT JOIN food_allergen_map m ON a.allergen_id = m.allergen_id
GROUP BY a.name
ORDER BY food_count DESC;


-- -----------------------------------------
-- 7. 최근 동기화 이력 확인 (sync_log)
-- 정상: status = 'SUCCESS'인 행이 최신 순으로 있어야 함.
--       'FAILED'가 있으면 error_message 확인 필요.
-- -----------------------------------------
SELECT sync_id, started_at, finished_at, status, total_rows, error_message
FROM sync_log
ORDER BY started_at DESC
LIMIT 10;
