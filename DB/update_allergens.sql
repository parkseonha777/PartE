-- =========================================
-- 팥이 (Pati) - 알레르겐 마스터 데이터 보완
-- 담당: 백엔드 A (데이터/DB)
--
-- 배경: find_missing_allergens.py 실행 결과, 식약처 공식
-- "알레르기 유발물질 표시대상 22종" 기준으로 5개 항목이
-- 기존 14개 알레르겐 목록에서 빠져있는 걸 확인함.
-- 나머지 353개는 대부분 기존 알레르겐의 표기 변형(동의어)이라
-- 새 알레르겐이 아니라 synonym으로 등록함.
--
-- 실행 방법: Supabase SQL Editor에 전체 복사 붙여넣기 후 Run
-- =========================================

-- -----------------------------------------
-- 1. 새 알레르겐 5개 추가 (식약처 22종 기준 누락분)
-- -----------------------------------------
INSERT INTO allergens (name) VALUES
    ('메밀'), ('복숭아'), ('아황산류'), ('호두'), ('잣')
ON CONFLICT (name) DO NOTHING;

-- 새 알레르겐 동의어
INSERT INTO allergen_synonyms (allergen_id, synonym, is_ocr_typo) VALUES
    ((SELECT allergen_id FROM allergens WHERE name='메밀'), '메밀', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='메밀'), '메밀가루', FALSE),

    ((SELECT allergen_id FROM allergens WHERE name='복숭아'), '복숭아', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='복숭아'), '복숭아농축액', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='복숭아'), '복홍아', TRUE),
    ((SELECT allergen_id FROM allergens WHERE name='복숭아'), '복훙아', TRUE),

    ((SELECT allergen_id FROM allergens WHERE name='아황산류'), '아황산류', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='아황산류'), '이산화황', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='아황산류'), '아산화황', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='아황산류'), '이황산류', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='아황산류'), '아황산나트륨', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='아황산류'), '산성아황산나트륨', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='아황산류'), '무수아황산', FALSE),

    ((SELECT allergen_id FROM allergens WHERE name='호두'), '호두', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='호두'), '호도', TRUE),

    ((SELECT allergen_id FROM allergens WHERE name='잣'), '잣', FALSE)
ON CONFLICT (allergen_id, synonym) DO NOTHING;


-- -----------------------------------------
-- 2. 기존 알레르겐에 자주 나온 변형 표기 추가 (동의어 보강)
-- -----------------------------------------

-- 난류 (계란, 알류, 난백, 난황, 메추리알 등)
INSERT INTO allergen_synonyms (allergen_id, synonym, is_ocr_typo) VALUES
    ((SELECT allergen_id FROM allergens WHERE name='난류'), '계란', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='난류'), '알류', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='난류'), '난백', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='난류'), '난황', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='난류'), '난황분말', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='난류'), '난각칼슘', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='난류'), '메추리알', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='난류'), '달걀', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='난류'), '날류', TRUE)
ON CONFLICT (allergen_id, synonym) DO NOTHING;

-- 쇠고기 (소고기, 사골, 우골, 우사골 등)
INSERT INTO allergen_synonyms (allergen_id, synonym, is_ocr_typo) VALUES
    ((SELECT allergen_id FROM allergens WHERE name='쇠고기'), '소고기', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='쇠고기'), '사골', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='쇠고기'), '우골', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='쇠고기'), '우사골', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='쇠고기'), '소뼈', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='쇠고기'), '쇠구기', TRUE)
ON CONFLICT (allergen_id, synonym) DO NOTHING;

-- 조개류 (굴, 전복, 홍합, 바지락, 모시조개, 꼬막, 대합, 가리비, 소라 등 하위 품목)
INSERT INTO allergen_synonyms (allergen_id, synonym, is_ocr_typo) VALUES
    ((SELECT allergen_id FROM allergens WHERE name='조개류'), '굴', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='조개류'), '전복', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='조개류'), '홍합', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='조개류'), '바지락', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='조개류'), '모시조개', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='조개류'), '꼬막', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='조개류'), '대합', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='조개류'), '가리비', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='조개류'), '소라', FALSE)
ON CONFLICT (allergen_id, synonym) DO NOTHING;

-- 대두 (콩, 두부, 유부, 춘장, 간장 등)
INSERT INTO allergen_synonyms (allergen_id, synonym, is_ocr_typo) VALUES
    ((SELECT allergen_id FROM allergens WHERE name='대두'), '탈지대두', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='대두'), '두부', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='대두'), '유부', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='대두'), '춘장', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='대두'), '분리대두단백', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='대두'), '레시틴', FALSE)
ON CONFLICT (allergen_id, synonym) DO NOTHING;

-- 밀 (밀가루, 소맥, 소맥분 등 이미 있을 수 있으니 중복은 자동 무시됨)
INSERT INTO allergen_synonyms (allergen_id, synonym, is_ocr_typo) VALUES
    ((SELECT allergen_id FROM allergens WHERE name='밀'), '밀가루', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='밀'), '소맥', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='밀'), '소맥분', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='밀'), '알파소맥', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='밀'), '밀쌀', FALSE)
ON CONFLICT (allergen_id, synonym) DO NOTHING;

-- 우유 (분유, 유청, 카제인, 버터, 유당 등)
INSERT INTO allergen_synonyms (allergen_id, synonym, is_ocr_typo) VALUES
    ((SELECT allergen_id FROM allergens WHERE name='우유'), '분유', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='우유'), '탈지분유', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='우유'), '유청', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='우유'), '유청분말', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='우유'), '카제인', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='우유'), '카제인나트륨', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='우유'), '버터', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='우유'), '유당', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='우유'), '유우', TRUE)
ON CONFLICT (allergen_id, synonym) DO NOTHING;

-- 돼지고기 (돈육, 돈지, 돈골 등)
INSERT INTO allergen_synonyms (allergen_id, synonym, is_ocr_typo) VALUES
    ((SELECT allergen_id FROM allergens WHERE name='돼지고기'), '돈육', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='돼지고기'), '돈지', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='돼지고기'), '돈골', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='돼지고기'), '괘지고기', TRUE)
ON CONFLICT (allergen_id, synonym) DO NOTHING;

-- 새우 (새우분말, 새우엑기스 등)
INSERT INTO allergen_synonyms (allergen_id, synonym, is_ocr_typo) VALUES
    ((SELECT allergen_id FROM allergens WHERE name='새우'), '새우분말', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='새우'), '새우엑기스', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='새우'), '볶음새우', FALSE)
ON CONFLICT (allergen_id, synonym) DO NOTHING;

-- 게 (게농축액, 게추출물 등)
INSERT INTO allergen_synonyms (allergen_id, synonym, is_ocr_typo) VALUES
    ((SELECT allergen_id FROM allergens WHERE name='게'), '게농축액', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='게'), '게추출물', FALSE)
ON CONFLICT (allergen_id, synonym) DO NOTHING;
