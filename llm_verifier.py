"""
OCR 결과를 LLM(Claude)이 원본 이미지와 대조해 교차 확인하고, 결과를 번역하는 모듈.

흐름:
  1. 원본 이미지 + EasyOCR 원문(신뢰도 포함) + 규칙 기반 판정 결과를 LLM에 전달
  2. LLM이 이미지를 직접 읽어 OCR 오타를 교정하고, 알레르겐별 위험도를 다시 판정
  3. 교정된 원재료/주의 문구를 사용자가 요청한 언어로 번역
  4. 규칙 기반 판정과 LLM 판정을 "더 위험한 쪽" 기준으로 병합 (안전 우선 원칙)

LLM 호출이 실패하거나 API 키가 없으면 규칙 기반 결과만 반환한다.
알레르기 앱 특성상 LLM이 규칙 기반 판정을 '낮추는' 일은 허용하지 않는다.
"""

import base64
import io
import json
import os

from dotenv import load_dotenv
from PIL import Image

load_dotenv()

LLM_MODEL = os.getenv("LLM_MODEL", "claude-sonnet-5-5")
LLM_TIMEOUT_SEC = float(os.getenv("LLM_TIMEOUT_SEC", "40"))

# Claude 비전 입력 권장 크기. 이보다 크면 서버에서 축소되므로 미리 줄여 전송량을 아낀다.
MAX_IMAGE_EDGE = 1568

LEVELS = ["안전", "주의", "위험"]
SEVERITY = {level: i for i, level in enumerate(LEVELS)}

LANGUAGE_NAMES = {
    # auto: 외국어 성분표 → 한국어, 한국어 성분표 → 영어
    "auto": "auto",
    "en": "English",
    "ko": "Korean",
    "ja": "Japanese",
    "zh": "Simplified Chinese",
    "zh-TW": "Traditional Chinese",
    "vi": "Vietnamese",
    "th": "Thai",
    "es": "Spanish",
    "fr": "French",
    "de": "German",
    "ru": "Russian",
    "id": "Indonesian",
}

SYSTEM_PROMPT = """당신은 식품 성분표(한국어 또는 영어 등 외국어)를 검증하는 식품 알레르기 안전 보조자입니다.
사용자는 알레르기 환자이며, 당신의 판단 오류는 건강 위험으로 이어질 수 있습니다.

규칙:
- 반드시 이미지에 실제로 보이는 글자를 근거로 판단합니다. OCR 원문은 참고용이며 오타가 많습니다.
- 이미지에서 읽을 수 없는 부분을 추측해서 채우지 않습니다. 읽을 수 없으면 legibility와 notes에 밝힙니다.
- '원재료명' 목록에 알레르겐(또는 그 동의어·파생 원료)이 있으면 "위험"입니다.
  예: 난류 ← 계란, 전란액, 난백, 난황 / 우유 ← 탈지분유, 유청, 카제인, 버터 / 대두 ← 대두유, 간장, 된장 / 밀 ← 소맥분, 밀가루
- "이 제품은 ○○를 사용한 제품과 같은 제조 시설에서 제조" 같은 혼입 가능 문구에만 있으면 "주의"입니다.
- 영어 성분표: INGREDIENTS 목록이나 "CONTAINS:" 문구에 있으면 "위험",
  "MAY CONTAIN", "manufactured in a facility that also processes ..." 같은 문구에만 있으면 "주의"입니다.
  예: 대두 ← soy, soybean oil, soy lecithin / 밀 ← wheat, flour / 우유 ← milk, butter, whey, casein / 난류 ← egg
- 원재료명이 잘리거나 가려져 확인할 수 없는 부분이 있으면 "안전"으로 확정하지 말고 "주의"로 판정하고,
  evidence에 확인할 수 없는 이유를 적습니다.
- 어느 쪽에도 없을 때만 "안전"입니다. 확신이 없으면 더 높은 위험도를 고릅니다.
- 번역은 식품 표시 용어로 정확하게 하고, 원재료 순서를 바꾸지 않습니다.
- 결과는 반드시 report_verification 도구로만 제출합니다."""

VERIFY_TOOL = {
    "name": "report_verification",
    "description": "성분표 교차 확인 및 번역 결과를 제출한다.",
    "input_schema": {
        "type": "object",
        "properties": {
            "label_language": {
                "type": "string",
                "description": "성분표 원문의 주 언어 코드 (예: ko, en, ja, zh)",
            },
            "legibility": {
                "type": "string",
                "enum": ["good", "partial", "poor"],
                "description": "이미지에서 원재료명/주의 문구를 얼마나 읽을 수 있는지",
            },
            "product_name": {
                "type": ["string", "null"],
                "description": "이미지에 제품명이 보이면 그 이름, 없으면 null",
            },
            "corrected_ingredient_text": {
                "type": "string",
                "description": "이미지 기준으로 교정한 원재료명 전체 (한국어 원문)",
            },
            "corrected_warning_text": {
                "type": "string",
                "description": "교정한 알레르기 유발물질 표시/혼입 가능 문구 (한국어 원문, 없으면 빈 문자열)",
            },
            "ocr_corrections": {
                "type": "array",
                "description": "OCR이 잘못 읽은 주요 단어와 교정 결과",
                "items": {
                    "type": "object",
                    "properties": {
                        "ocr": {"type": "string"},
                        "corrected": {"type": "string"},
                    },
                    "required": ["ocr", "corrected"],
                },
            },
            "allergen_judgements": {
                "type": "array",
                "description": "사용자 알레르기 항목 각각에 대한 판정 (모든 항목 포함)",
                "items": {
                    "type": "object",
                    "properties": {
                        "allergen": {"type": "string"},
                        "level": {"type": "string", "enum": LEVELS},
                        "evidence": {
                            "type": "string",
                            "description": "판정 근거가 된 성분표 속 실제 표기 (안전이면 빈 문자열)",
                        },
                    },
                    "required": ["allergen", "level", "evidence"],
                },
            },
            "translation": {
                "type": "object",
                "properties": {
                    "language": {"type": "string", "description": "실제로 번역한 언어 코드"},
                    "ingredients": {"type": "string", "description": "원재료명 번역"},
                    "warning": {"type": "string", "description": "주의 문구 번역"},
                    "allergen_names": {
                        "type": "object",
                        "description": "사용자 알레르기 항목명 → 번역어",
                        "additionalProperties": {"type": "string"},
                    },
                    "summary": {
                        "type": "string",
                        "description": "사용자에게 보여줄 1~2문장 판정 요약 (번역 언어로)",
                    },
                },
                "required": ["language", "ingredients", "warning", "allergen_names", "summary"],
            },
            "notes": {
                "type": "string",
                "description": "재촬영이 필요한 이유 등 참고 사항 (없으면 빈 문자열)",
            },
        },
        "required": [
            "label_language",
            "legibility",
            "product_name",
            "corrected_ingredient_text",
            "corrected_warning_text",
            "ocr_corrections",
            "allergen_judgements",
            "translation",
            "notes",
        ],
    },
}


class LLMUnavailable(Exception):
    """API 키 없음, 네트워크 오류, 응답 형식 오류 등으로 LLM 검증을 못 한 경우"""


def _encode_image(image_path: str) -> tuple[str, str]:
    """이미지를 LLM 권장 크기로 줄여 base64 JPEG으로 인코딩한다."""
    with Image.open(image_path) as img:
        img = img.convert("RGB")
        img.thumbnail((MAX_IMAGE_EDGE, MAX_IMAGE_EDGE))
        buf = io.BytesIO()
        img.save(buf, "JPEG", quality=90)
    return "image/jpeg", base64.standard_b64encode(buf.getvalue()).decode("ascii")


def _build_user_prompt(
    ocr_lines: list[dict],
    user_allergens: list[str],
    synonyms: dict[str, list[str]],
    rule_result: dict,
    target_lang: str,
) -> str:
    if target_lang == "auto":
        translate_rule = (
            "성분표 원문 언어를 먼저 판단하세요. 원문이 한국어가 아니면 한국어(ko)로, "
            "원문이 한국어면 영어(en)로 번역하세요."
        )
    else:
        lang_name = LANGUAGE_NAMES.get(target_lang, target_lang)
        translate_rule = f"{lang_name}({target_lang})로 번역하세요."
    ocr_block = "\n".join(f"- {l['text']} (신뢰도 {l['confidence']:.2f})" for l in ocr_lines)
    synonym_block = "\n".join(
        f"- {a}: {', '.join(synonyms.get(a, [])) or '(등록된 동의어 없음)'}" for a in user_allergens
    )
    return f"""첨부한 이미지는 사용자가 촬영한 식품 성분표입니다.

[사용자 알레르기 항목]
{', '.join(user_allergens)}

[DB에 등록된 동의어]
{synonym_block}

[EasyOCR 원문 (오타 포함 가능)]
{ocr_block or '(인식된 텍스트 없음)'}

[규칙 기반 1차 판정]
{json.dumps(rule_result, ensure_ascii=False)}

할 일:
1. 이미지를 직접 읽어 원재료명과 혼입 가능 문구를 교정하세요.
2. 사용자 알레르기 항목 하나하나에 대해 위험/주의/안전을 판정하고 근거 표기를 적으세요.
3. 교정한 원재료명, 주의 문구, 알레르기 항목명, 판정 요약을 번역하세요. {translate_rule}
   translation.language에는 실제로 번역한 언어 코드를 적으세요.
   corrected_ingredient_text와 corrected_warning_text는 번역하지 말고 성분표 원문 언어 그대로 적으세요."""


def call_llm(
    image_path: str,
    ocr_lines: list[dict],
    user_allergens: list[str],
    synonyms: dict[str, list[str]],
    rule_result: dict,
    target_lang: str = "auto",
    client=None,
) -> dict:
    """Claude에 교차 확인을 요청하고 report_verification 도구 입력(dict)을 반환한다."""
    if client is None:
        if not os.getenv("ANTHROPIC_API_KEY"):
            raise LLMUnavailable("ANTHROPIC_API_KEY가 .env에 설정되어 있지 않습니다.")
        import anthropic

        client = anthropic.Anthropic(timeout=LLM_TIMEOUT_SEC, max_retries=1)

    media_type, image_b64 = _encode_image(image_path)
    prompt = _build_user_prompt(ocr_lines, user_allergens, synonyms, rule_result, target_lang)

    try:
        response = client.messages.create(
            model=LLM_MODEL,
            max_tokens=8192,
            system=SYSTEM_PROMPT,
            tools=[VERIFY_TOOL],
            # 일부 모델은 도구 강제 호출(tool_choice: tool/any)을 지원하지 않아 auto를 쓴다.
            # 시스템 프롬프트에서 report_verification 도구로만 제출하도록 지시한다.
            tool_choice={"type": "auto"},
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image",
                            "source": {"type": "base64", "media_type": media_type, "data": image_b64},
                        },
                        {"type": "text", "text": prompt},
                    ],
                }
            ],
        )
    except Exception as e:  # 네트워크, 인증, 요청 한도 오류 등
        raise LLMUnavailable(f"LLM 호출 실패: {type(e).__name__}: {e}") from e

    for block in response.content:
        if getattr(block, "type", None) == "tool_use" and block.name == "report_verification":
            return block.input

    # 도구를 쓰지 않고 본문에 JSON으로 답한 경우 대비
    text = "".join(getattr(b, "text", "") for b in response.content if getattr(b, "type", None) == "text")
    start, end = text.find("{"), text.rfind("}")
    if start != -1 and end > start:
        try:
            data = json.loads(text[start:end + 1])
            if isinstance(data, dict) and "allergen_judgements" in data:
                return data
        except json.JSONDecodeError:
            pass
    raise LLMUnavailable("LLM 응답에 검증 결과가 없습니다.")


def merge_results(rule_result: dict, llm_output: dict, user_allergens: list[str]) -> tuple[dict, list[dict]]:
    """
    규칙 기반 판정과 LLM 판정을 항목별로 합친다.

    기본은 더 위험한 쪽을 최종 판정으로 삼는다 (안전 우선).
    예외는 하나뿐이다: 규칙이 "위험", LLM이 "주의"이고, LLM이 사진을 선명하게 읽었으며
    (legibility == "good") 근거 문구를 제시한 경우에는 LLM의 "주의"를 따른다.
    OCR 규칙은 혼입 가능 문구의 범위를 잘못 잡아 주의 성분을 위험으로 올리는 일이 잦기 때문이다.
    어떤 경우에도 LLM이 "위험"이나 "주의"를 "안전"으로 낮출 수는 없다.

    반환: (최종 {"위험","주의","안전"}, 항목별 비교 목록)
    """
    legible = llm_output.get("legibility") == "good"
    rule_level = {a: lvl for lvl in LEVELS for a in rule_result.get(lvl, [])}
    llm_level, llm_evidence = {}, {}
    for j in llm_output.get("allergen_judgements", []):
        if j.get("level") in SEVERITY:
            llm_level[j["allergen"]] = j["level"]
            llm_evidence[j["allergen"]] = j.get("evidence", "")

    final = {lvl: [] for lvl in ("위험", "주의", "안전")}
    details = []
    for allergen in user_allergens:
        r = rule_level.get(allergen, "안전")
        l = llm_level.get(allergen)  # LLM이 항목을 빠뜨렸으면 None
        evidence = llm_evidence.get(allergen, "")

        if l is None:
            f, decided_by = r, "rule"
        elif r == "위험" and l == "주의" and legible and evidence.strip():
            f, decided_by = "주의", "llm"
        else:
            f = max(r, l, key=SEVERITY.get)
            decided_by = "agreed" if l == r else ("llm" if f == l else "rule")

        final[f].append(allergen)
        details.append(
            {
                "allergen": allergen,
                "rule": r,
                "llm": l,
                "final": f,
                "agreed": l == r,
                "decided_by": decided_by,
                "evidence": evidence,
            }
        )
    return final, details


def _translation_block(llm_output: dict, target_lang: str) -> dict:
    t = dict(llm_output.get("translation", {}))
    lang = t.get("language")
    if not lang:  # LLM이 언어를 안 적은 경우: auto면 원문 언어로 추정
        if target_lang != "auto":
            lang = target_lang
        else:
            lang = "en" if llm_output.get("label_language", "ko") == "ko" else "ko"
    t["language"] = lang
    return t


def _coerce(value, kind):
    """LLM이 객체/배열을 JSON 문자열로 돌려준 경우 풀어 주고, 형식이 다르면 빈 값으로 바꾼다."""
    if isinstance(value, str):
        try:
            value = json.loads(value)
        except json.JSONDecodeError:
            return kind()
    return value if isinstance(value, kind) else kind()


def _normalize_llm_output(out: dict) -> dict:
    """앱이 Map/List로 읽는 필드의 형식을 보장한다."""
    out = dict(out)
    translation = dict(_coerce(out.get("translation"), dict))
    translation["allergen_names"] = _coerce(translation.get("allergen_names"), dict)
    out["translation"] = translation
    out["allergen_judgements"] = _coerce(out.get("allergen_judgements"), list)
    out["ocr_corrections"] = _coerce(out.get("ocr_corrections"), list)
    return out


def verify_and_translate(
    image_path: str,
    ocr_lines: list[dict],
    user_allergens: list[str],
    synonyms: dict[str, list[str]],
    rule_result: dict,
    target_lang: str = "auto",
    client=None,
) -> dict:
    """
    /scan/verify 응답 본문을 만든다.
    최상위 "위험"/"주의"/"안전" 키는 기존 /scan과 같은 형식이라 앱 화면을 그대로 쓸 수 있다.
    """
    try:
        llm_output = call_llm(
            image_path, ocr_lines, user_allergens, synonyms, rule_result, target_lang, client
        )
    except LLMUnavailable as e:
        print(f"[LLM] 교차 확인 생략: {e}")
        return {
            **rule_result,
            "verification": {
                "status": "unavailable",
                "message": "LLM 교차 확인을 하지 못해 OCR 규칙 기반 결과만 제공합니다.",
                "needs_recheck": True,
            },
            "translation": None,
        }

    llm_output = _normalize_llm_output(llm_output)
    final, details = merge_results(rule_result, llm_output, user_allergens)
    disagreements = [d for d in details if not d["agreed"]]
    legibility = llm_output.get("legibility", "partial")

    return {
        **final,
        "verification": {
            "status": "verified",
            "model": LLM_MODEL,
            "legibility": legibility,
            "label_language": llm_output.get("label_language"),
            "needs_recheck": legibility == "poor" or bool(disagreements),
            "product_name": llm_output.get("product_name"),
            "corrected_ingredient_text": llm_output.get("corrected_ingredient_text", ""),
            "corrected_warning_text": llm_output.get("corrected_warning_text", ""),
            "ocr_corrections": llm_output.get("ocr_corrections", []),
            "details": details,
            "notes": llm_output.get("notes", ""),
        },
        "translation": _translation_block(llm_output, target_lang),
    }