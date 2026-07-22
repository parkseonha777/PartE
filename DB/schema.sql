-- =========================================
-- 팥이 (Pati) - 알레르겐 매칭 DB 스키마
-- 담당: 백엔드 A (데이터/DB)
-- =========================================

-- 1. 알레르기 항목 마스터 테이블
-- allergen_matcher.py의 ALLERGEN_DB 키(난류, 우유, 땅콩...)를 그대로 옮김
CREATE TABLE allergens (
    allergen_id     SERIAL PRIMARY KEY,
    name            VARCHAR(50) NOT NULL UNIQUE,   -- 예: '난류', '우유', '땅콩'
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

-- 2. 알레르겐 동의어 / OCR 오타 패턴 테이블
-- allergen_matcher.py의 리스트(['난류','계란','전란',...])를 행 단위로 분리
CREATE TABLE allergen_synonyms (
    synonym_id      SERIAL PRIMARY KEY,
    allergen_id     INT NOT NULL REFERENCES allergens(allergen_id) ON DELETE CASCADE,
    synonym         VARCHAR(50) NOT NULL,           -- 예: '계란', '게란', '계런'
    is_ocr_typo     BOOLEAN NOT NULL DEFAULT FALSE, -- OCR 오타 패턴이면 TRUE
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (allergen_id, synonym)
);

-- 3. 식약처(식품안전나라) 원본 데이터 테이블
-- I2520 서비스(식품원재료 정보) 응답을 그대로 적재
CREATE TABLE foods (
    food_id         SERIAL PRIMARY KEY,
    source_id       VARCHAR(100),                   -- 식약처 원본 고유 ID (있으면)
    food_name       VARCHAR(200) NOT NULL,           -- 식품명
    raw_material    TEXT,                            -- 원재료명 원문 (OCR 전 참고용)
    manufacturer    VARCHAR(200),                    -- 제조사 (있으면)
    synced_at       TIMESTAMP NOT NULL DEFAULT NOW(),
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

-- 4. 식품 - 알레르겐 매핑 테이블
-- 원재료 텍스트를 파싱해서 어떤 식품이 어떤 알레르겐을 포함하는지 저장
CREATE TABLE food_allergen_map (
    map_id          SERIAL PRIMARY KEY,
    food_id         INT NOT NULL REFERENCES foods(food_id) ON DELETE CASCADE,
    allergen_id     INT NOT NULL REFERENCES allergens(allergen_id) ON DELETE CASCADE,
    risk_level      VARCHAR(10) NOT NULL DEFAULT '위험'
                    CHECK (risk_level IN ('위험', '주의')), -- 원재료=위험, 교차오염 경고문구=주의
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (food_id, allergen_id)
);

-- 5. 동기화 로그 테이블
-- 정기 동기화(주기적 API 재호출) 이력 추적
CREATE TABLE sync_log (
    sync_id         SERIAL PRIMARY KEY,
    started_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    finished_at     TIMESTAMP,
    status          VARCHAR(20) NOT NULL DEFAULT 'RUNNING'
                    CHECK (status IN ('RUNNING', 'SUCCESS', 'FAILED')),
    total_rows      INT DEFAULT 0,
    error_message   TEXT
);

-- 검색 성능을 위한 인덱스
CREATE INDEX idx_allergen_synonyms_synonym ON allergen_synonyms(synonym);
CREATE INDEX idx_foods_food_name ON foods(food_name);
CREATE INDEX idx_food_allergen_map_food_id ON food_allergen_map(food_id);

-- =========================================
-- 초기 데이터: allergen_matcher.py의 ALLERGEN_DB를 그대로 이관
-- =========================================
INSERT INTO allergens (name) VALUES
    ('난류'), ('우유'), ('땅콩'), ('대두'), ('밀'), ('새우'), ('게'),
    ('돼지고기'), ('쇠고기'), ('닭고기'), ('고등어'), ('조개류'), ('오징어'), ('토마토');

INSERT INTO allergen_synonyms (allergen_id, synonym, is_ocr_typo) VALUES
    ((SELECT allergen_id FROM allergens WHERE name='난류'), '난류', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='난류'), '계란', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='난류'), '전란', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='난류'), '전란액', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='난류'), '난백', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='난류'), '난황', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='난류'), '계런', TRUE),
    ((SELECT allergen_id FROM allergens WHERE name='난류'), '게란', TRUE),
    ((SELECT allergen_id FROM allergens WHERE name='난류'), '게런', TRUE),

    ((SELECT allergen_id FROM allergens WHERE name='우유'), '우유', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='우유'), '분유', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='우유'), '유청', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='우유'), '카제인', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='우유'), '버터', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='우유'), '치즈', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='우유'), '유당', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='우유'), '유유', TRUE),

    ((SELECT allergen_id FROM allergens WHERE name='땅콩'), '땅콩', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='땅콩'), '피넛', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='땅콩'), '땅콩분말', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='땅콩'), '땅콩버터', FALSE),

    ((SELECT allergen_id FROM allergens WHERE name='대두'), '대두', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='대두'), '콩', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='대두'), '두유', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='대두'), '대두유', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='대두'), '간장', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='대두'), '대도', TRUE),

    ((SELECT allergen_id FROM allergens WHERE name='밀'), '밀', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='밀'), '밀가루', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='밀'), '소맥', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='밀'), '소맥분', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='밀'), '글루텐', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='밀'), '말', TRUE),

    ((SELECT allergen_id FROM allergens WHERE name='새우'), '새우', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='새우'), '갑각류', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='새우'), '쉬림프', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='새우'), '새우분말', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='새우'), '새우추출물', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='새우'), '새유', TRUE),

    ((SELECT allergen_id FROM allergens WHERE name='게'), '게', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='게'), '크랩', FALSE),

    ((SELECT allergen_id FROM allergens WHERE name='돼지고기'), '돼지고기', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='돼지고기'), '돈육', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='돼지고기'), '포크', FALSE),

    ((SELECT allergen_id FROM allergens WHERE name='쇠고기'), '쇠고기', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='쇠고기'), '소고기', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='쇠고기'), '우육', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='쇠고기'), '비프', FALSE),

    ((SELECT allergen_id FROM allergens WHERE name='닭고기'), '닭고기', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='닭고기'), '계육', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='닭고기'), '치킨', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='닭고기'), '닮고기', TRUE),

    ((SELECT allergen_id FROM allergens WHERE name='고등어'), '고등어', FALSE),

    ((SELECT allergen_id FROM allergens WHERE name='조개류'), '조개류', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='조개류'), '굴', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='조개류'), '전복', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='조개류'), '홍합', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='조개류'), '바지락', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='조개류'), '조게류', TRUE),
    ((SELECT allergen_id FROM allergens WHERE name='조개류'), '조료국', TRUE),

    ((SELECT allergen_id FROM allergens WHERE name='오징어'), '오징어', FALSE),
    ((SELECT allergen_id FROM allergens WHERE name='토마토'), '토마토', FALSE);
