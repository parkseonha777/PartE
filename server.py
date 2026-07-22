from fastapi import FastAPI, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
import easyocr
import shutil
import os

from allergen_matcher import find_allergens_in_text

app = FastAPI()

# 프론트엔드(Flutter 앱 등)에서 요청 보낼 수 있게 CORS 허용
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

print("EasyOCR 모델 로딩 중... (서버 시작 시 1회만 실행)")
reader = easyocr.Reader(['ko', 'en'])
print("로딩 완료. 서버 준비됨.")


@app.get("/")
async def root():
    return {"message": "팥이 OCR 서버가 실행 중입니다"}


@app.post("/scan")
async def scan_label(file: UploadFile = File(...), allergens: str = Form(...)):
    """
    file: 사용자가 촬영한 성분표 이미지
    allergens: 쉼표로 구분된 알레르기 항목 문자열 (예: "난류,우유,새우")
    """
    # 1. 업로드된 이미지 임시 저장
    temp_path = f"temp_{file.filename}"
    with open(temp_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    try:
        # 2. OCR 실행
        result = reader.readtext(temp_path)
        ocr_text_list = [text for (bbox, text, confidence) in result]

        # 3. 알레르기 매칭
        user_allergens = [a.strip() for a in allergens.split(",") if a.strip()]
        match_result = find_allergens_in_text(ocr_text_list, user_allergens)

        return match_result

    finally:
        # 4. 임시 파일 삭제 (에러가 나도 반드시 삭제되도록 finally 사용)
        if os.path.exists(temp_path):
            os.remove(temp_path)