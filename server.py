from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import easyocr
import shutil
import os
from PIL import Image, ImageOps

from allergen_matcher import find_allergens_in_text
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


@app.post("/scan")
async def scan_label(file: UploadFile = File(...), allergens: str = Form(...)):
    """
    file: 사용자가 촬영한 성분표 이미지
    allergens: 쉼표로 구분된 알레르기 항목 문자열 (예: "난류,우유,새우")
    """

    # ---- 1. 입력값 검증 ----

    ext = os.path.splitext(file.filename)[1].lower()
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

    # ---- 2. 파일 저장 ----
    # 원본 파일명을 그대로 쓰면 한글 등 비ASCII 문자가 섞여 있을 때
    # 인코딩이 깨져서 파일을 못 여는 문제가 생길 수 있음.
    # 확장자만 유지하고, 이름 자체는 안전한 UUID로 교체.
    import uuid
    safe_ext = ext if ext else ".jpg"
    temp_path = f"temp_{uuid.uuid4().hex}{safe_ext}"
    normalized_path = f"temp_normalized_{uuid.uuid4().hex}.jpg"

    try:
        with open(temp_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        if os.path.getsize(temp_path) == 0:
            raise HTTPException(status_code=400, detail="업로드된 파일이 비어있습니다.")

        # ---- 2-1. 이미지 재인코딩 (기종별 JPEG 호환성 + EXIF 방향 문제 해결) ----
        try:
            with Image.open(temp_path) as img:
                # 카메라로 찍은 사진의 EXIF 방향 정보를 반영해 픽셀을 바로잡음.
                # 이걸 안 하면 사진이 옆으로 돌아간 채로 저장되어 OCR이 텍스트를
                # 전혀 인식하지 못하는 문제가 생김.
                img = ImageOps.exif_transpose(img)

                if img.mode != "RGB":
                    img = img.convert("RGB")
                img.save(normalized_path, "JPEG", quality=95)
        except Exception:
            raise HTTPException(
                status_code=422,
                detail="이미지 파일을 열 수 없습니다. 손상되었거나 지원하지 않는 이미지 형식일 수 있습니다."
            )

        # ---- 3. OCR 실행 (재인코딩된 이미지 사용) ----
        try:
            result = reader.readtext(normalized_path)
        except Exception:
            raise HTTPException(
                status_code=422,
                detail="이미지를 읽는 중 문제가 발생했습니다. 손상되었거나 지원하지 않는 이미지일 수 있습니다."
            )

        ocr_text_list = [text for (bbox, text, confidence) in result]
        ocr_text_list = clean_ocr_text_list(ocr_text_list)

        if not ocr_text_list:
            raise HTTPException(
                status_code=422,
                detail="이미지에서 텍스트를 인식하지 못했습니다. 성분표가 잘 보이도록 다시 촬영해주세요."
            )

        # ---- 4. 알레르기 매칭 ----
        match_result = find_allergens_in_text(ocr_text_list, user_allergens)

        return match_result

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"서버 내부 오류가 발생했습니다: {str(e)}"
        )
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)
        if os.path.exists(normalized_path):
            os.remove(normalized_path)


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