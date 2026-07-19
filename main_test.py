import easyocr
from allergen_matcher import find_allergens_in_text

print("EasyOCR 로딩 중...")
reader = easyocr.Reader(['ko', 'en'])
print("로딩 완료. 이미지 분석 시작...\n")

image_path = "images/sample2.jpg"  # 본인 파일명 확인
result = reader.readtext(image_path)

ocr_text_list = [text for (bbox, text, confidence) in result if confidence > 0.02]

print("=== OCR로 추출한 텍스트 ===")
for t in ocr_text_list:
    print(t)

my_allergens = ["난류", "우유", "새우", "고등어", "대두"]

match_result = find_allergens_in_text(ocr_text_list, my_allergens)

print("\n=== 알레르기 분석 결과 ===")
print(f"🔴 위험: {match_result['위험']}")
print(f"🟡 주의: {match_result['주의']}")
print(f"🟢 안전: {match_result['안전']}")