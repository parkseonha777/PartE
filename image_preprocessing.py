import cv2

def preprocess_image(image_path: str, output_path: str = "preprocessed.jpg"):
    img = cv2.imread(image_path)
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)          # 흑백 변환
    denoised = cv2.fastNlMeansDenoising(gray, h=10)        # 노이즈 제거
    _, thresh = cv2.threshold(denoised, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)  # 대비 극대화
    cv2.imwrite(output_path, thresh)
    return output_path