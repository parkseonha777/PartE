from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import easyocr
import shutil
import os

from allergen_matcher import find_allergens_in_text

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

    # 1-1. 파일 확장자 확인
    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"지원하지 않는 파일 형식입니다 ({ext}). jpg, jpeg, png, webp 파일만 업로드해주세요."
        )

    # 1-2. 알레르기 항목이 비어있는지 확인
    user_allergens = [a.strip() for a in allergens.split(",") if a.strip()]
    if not user_allergens:
        raise HTTPException(
            status_code=400,
            detail="알레르기 항목이 비어있습니다. 최소 1개 이상 입력해주세요."
        )

    # ---- 2. 파일 저장 ----
    temp_path = f"temp_{file.filename}"
    try:
        with open(temp_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # 파일이 실제로 비어있지 않은지 확인
        if os.path.getsize(temp_path) == 0:
            raise HTTPException(status_code=400, detail="업로드된 파일이 비어있습니다.")

        # ---- 3. OCR 실행 ----
        try:
            result = reader.readtext(temp_path)
        except Exception as e:
            raise HTTPException(
                status_code=422,
                detail=f"이미지를 읽는 중 문제가 발생했습니다. 손상되었거나 지원하지 않는 이미지일 수 있습니다."
            )

        ocr_text_list = [text for (bbox, text, confidence) in result]

        # 3-1. OCR이 텍스트를 아예 못 찾은 경우
        if not ocr_text_list:
            raise HTTPException(
                status_code=422,
                detail="이미지에서 텍스트를 인식하지 못했습니다. 성분표가 잘 보이도록 다시 촬영해주세요."
            )

        # ---- 4. 알레르기 매칭 ----
        match_result = find_allergens_in_text(ocr_text_list, user_allergens)

        return match_result

    except HTTPException:
        # 이미 처리된 HTTPException은 그대로 다시 던짐
        raise
    except Exception as e:
        # 예상 못한 에러는 500으로 처리하되, 서버가 죽지 않고 메시지 반환
        raise HTTPException(
            status_code=500,
            detail=f"서버 내부 오류가 발생했습니다: {str(e)}"
        )
    finally:
        # 임시 파일은 성공하든 실패하든 반드시 삭제
        if os.path.exists(temp_path):
            os.remove(temp_path)