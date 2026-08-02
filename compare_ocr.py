import easyocr
from image_preprocessing import preprocess_image

print("EasyOCR 로딩 중...")
reader = easyocr.Reader(['ko', 'en'])
print("로딩 완료.\n")

image_path = "images/sample2.jpg"  # 새우깡 원재료명 사진

# ===== 1) 원본 이미지로 OCR =====
print("=" * 50)
print("[원본 이미지] OCR 결과")
print("=" * 50)
result_original = reader.readtext(image_path)
for (bbox, text, confidence) in result_original:
    print(f"{text}  (신뢰도: {confidence:.2f})")

print(f"\n총 인식된 텍스트 조각 수: {len(result_original)}")
avg_conf_original = sum(c for (_, _, c) in result_original) / len(result_original)
print(f"평균 신뢰도: {avg_conf_original:.3f}")

# ===== 2) 전처리 이미지로 OCR =====
print("\n" + "=" * 50)
print("[전처리 이미지] OCR 결과")
print("=" * 50)
preprocessed_path = preprocess_image(image_path)
result_preprocessed = reader.readtext(preprocessed_path)
for (bbox, text, confidence) in result_preprocessed:
    print(f"{text}  (신뢰도: {confidence:.2f})")

print(f"\n총 인식된 텍스트 조각 수: {len(result_preprocessed)}")
if result_preprocessed:
    avg_conf_preprocessed = sum(c for (_, _, c) in result_preprocessed) / len(result_preprocessed)
    print(f"평균 신뢰도: {avg_conf_preprocessed:.3f}")
else:
    print("텍스트를 하나도 인식하지 못함")

# ===== 3) 비교 요약 =====
print("\n" + "=" * 50)
print("[비교 요약]")
print("=" * 50)
print(f"원본:   텍스트 {len(result_original)}개, 평균 신뢰도 {avg_conf_original:.3f}")
if result_preprocessed:
    print(f"전처리: 텍스트 {len(result_preprocessed)}개, 평균 신뢰도 {avg_conf_preprocessed:.3f}")