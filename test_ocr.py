import easyocr

print("EasyOCR 로딩 중...")
reader = easyocr.Reader(['ko', 'en'])
print("로딩 완료. 이미지 분석 시작...\n")

# 이미지 경로 (본인 파일명에 맞게 수정)
image_path = "images/sample2.jpg"

result = reader.readtext(image_path)

print("=== 인식된 텍스트 ===")
for (bbox, text, confidence) in result:
    print(f"텍스트: {text}  (신뢰도: {confidence:.2f})")