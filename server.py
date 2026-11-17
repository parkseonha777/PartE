from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.concurrency import run_in_threadpool
from fastapi.middleware.cors import CORSMiddleware
import easyocr
import shutil
import os
import uuid
from PIL import Image, ImageOps

from allergen_matcher import find_allergens_in_raw, ALLERGEN_DB
from llm_verifier import verify_and_translate, LANGUAGE_NAMES
from text_cleaner import clean_ocr_text_list
from DB.allergen_lookup import get_alternatives

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

print("EasyOCR 모델 로딩 중... (서버 시작 시 1회만 실행)")
reader = easyocr.Reader(['ko', 'en'])
print("로딩 완료. 서버 준비됨.")

# 업로드 허용할 이미지 확장자
ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


@app.get("/")
async def root():
    return {"message": "팥이 OCR 서버가 실행 중입니다"}


def _validate_inputs(file: UploadFile, allergens: str) -> tuple[str, list[str]]:
    ext = os.path.splitext(file.filename or "")[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"지원하지 않는 파일 형식입니다 ({ext}). jpg, jpeg, png, webp 파일만 업로드해주세요."
        )

    user_allergens = [a.strip() for a in allergens.split(",") if a.strip()]
    if not user_allergens:
        raise HTTPException(
            status_code=400,
            detail="알레르기 항목이 비어있습니다. 최소 1개 이상 입력해주세요."
        )
    return ext, user_allergens


def _save_and_normalize(file: UploadFile, ext: str, temp_path: str, normalized_path: str) -> None:
    # 원본 파일명을 그대로 쓰면 한글 등 비ASCII 문자가 섞여 있을 때
    # 인코딩이 깨져서 파일을 못 여는 문제가 생길 수 있어 UUID 이름으로 저장한다.
    with open(temp_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    if os.path.getsize(temp_path) == 0:
        raise HTTPException(status_code=400, detail="업로드된 파일이 비어있습니다.")

    # 이미지 재인코딩 (기종별 JPEG 호환성 + EXIF 방향 문제 해결)
    try:
        with Image.open(temp_path) as img:
            # EXIF 방향을 반영하지 않으면 사진이 옆으로 돌아간 채로 OCR에 들어가
            # 텍스트를 전혀 인식하지 못하는 문제가 생긴다.
            img = ImageOps.exif_transpose(img)
            if img.mode != "RGB":
                img = img.convert("RGB")
            img.save(normalized_path, "JPEG", quality=95)
    except Exception:
        raise HTTPException(
            status_code=422,
            detail="이미지 파일을 열 수 없습니다. 손상되었거나 지원하지 않는 이미지 형식일 수 있습니다."
        )


def _run_ocr(normalized_path: str) -> list[dict]:
    """EasyOCR 원문을 신뢰도와 함께 반환 (정제 전)."""
    try:
        result = reader.readtext(normalized_path)
    except Exception:
        raise HTTPException(
            status_code=422,
            detail="이미지를 읽는 중 문제가 발생했습니다. 손상되었거나 지원하지 않는 이미지일 수 있습니다."
        )
    return [{"text": text, "confidence": float(conf)} for (bbox, text, conf) in result]


def _rule_based_match(ocr_lines: list[dict], user_allergens: list[str]) -> dict:
    cleaned = clean_ocr_text_list([l["text"] for l in ocr_lines])
    if not cleaned:
        raise HTTPException(
            status_code=422,
            detail="이미지에서 텍스트를 인식하지 못했습니다. 성분표가 잘 보이도록 다시 촬영해주세요."
        )
    return find_allergens_in_raw([l["text"] for l in ocr_lines], user_allergens)


def _cleanup(*paths: str) -> None:
    for p in paths:
        if os.path.exists(p):
            os.remove(p)


@app.post("/scan")
async def scan_label(file: UploadFile = File(...), allergens: str = Form(...)):
    """
    file: 사용자가 촬영한 성분표 이미지
    allergens: 쉼표로 구분된 알레르기 항목 문자열 (예: "난류,우유,새우")
    """
    ext, user_allergens = _validate_inputs(file, allergens)
    temp_path = f"temp_{uuid.uuid4().hex}{ext}"
    normalized_path = f"temp_normalized_{uuid.uuid4().hex}.jpg"

    try:
        _save_and_normalize(file, ext, temp_path, normalized_path)
        ocr_lines = _run_ocr(normalized_path)
        return _rule_based_match(ocr_lines, user_allergens)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"서버 내부 오류가 발생했습니다: {str(e)}")
    finally:
        _cleanup(temp_path, normalized_path)


@app.post("/scan/verify")
async def scan_label_verified(
    file: UploadFile = File(...),
    allergens: str = Form(...),
    target_lang: str = Form("auto"),
):
    """
    OCR → 규칙 기반 판정 → LLM이 원본 이미지와 대조해 교차 확인 → 번역.

    file: 성분표 이미지
    allergens: 쉼표로 구분된 알레르기 항목 (예: "난류,우유,새우")
    target_lang: 번역 언어 코드 (기본 "auto": 외국어 성분표→한국어, 한국어 성분표→영어 / en, ko, ja, zh, vi 등 지정 가능)

    응답의 "위험"/"주의"/"안전"은 /scan과 같은 형식이며,
    규칙 기반과 LLM 판정 중 더 위험한 쪽을 최종 판정으로 사용한다.
    """
    ext, user_allergens = _validate_inputs(file, allergens)
    if target_lang not in LANGUAGE_NAMES:
        raise HTTPException(
            status_code=400,
            detail=f"지원하지 않는 번역 언어입니다 ({target_lang}). 사용 가능: {', '.join(LANGUAGE_NAMES)}"
        )

    temp_path = f"temp_{uuid.uuid4().hex}{ext}"
    normalized_path = f"temp_normalized_{uuid.uuid4().hex}.jpg"

    try:
        _save_and_normalize(file, ext, temp_path, normalized_path)
        ocr_lines = _run_ocr(normalized_path)
        rule_result = _rule_based_match(ocr_lines, user_allergens)

        synonyms = {a: ALLERGEN_DB.get(a, [a]) for a in user_allergens}
        return await run_in_threadpool(
            verify_and_translate,
            normalized_path, ocr_lines, user_allergens, synonyms, rule_result, target_lang,
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"서버 내부 오류가 발생했습니다: {str(e)}")
    finally:
        _cleanup(temp_path, normalized_path)


@app.get("/alternatives")
async def alternatives(allergen: str, limit: int = 5):
    """
    allergen: 위험으로 판정된 알레르겐 이름 (예: "우유")
    limit: 추천받을 최대 개수 (기본 5개)

    해당 알레르겐이 포함되지 않은 식품을 DB에서 조회해 반환.
    """
    try:
        items = get_alternatives(allergen, limit)
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"대체 식품 조회 중 오류가 발생했습니다: {str(e)}"
        )

    return {"allergen": allergen, "alternatives": items}