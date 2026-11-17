"""
llm_verifier / /scan/verify 테스트 (API 키·DB·EasyOCR 없이 실행 가능)

실행: python -m pytest test_llm_verifier.py -v
"""

import io
import sys
import types
from types import SimpleNamespace

from PIL import Image

import llm_verifier
from llm_verifier import merge_results, verify_and_translate


def _make_image(path):
    Image.new("RGB", (3000, 2000), "white").save(path, "JPEG")


class FakeClient:
    """anthropic.Anthropic 대체. 고정된 도구 응답을 돌려주고 요청 내용을 기록한다."""

    def __init__(self, tool_input=None, error=None):
        self.tool_input = tool_input
        self.error = error
        self.last_request = None
        self.messages = self

    def create(self, **kwargs):
        self.last_request = kwargs
        if self.error:
            raise self.error
        block = SimpleNamespace(type="tool_use", name="report_verification", input=self.tool_input)
        return SimpleNamespace(content=[block])


LLM_OUTPUT = {
    "legibility": "good",
    "product_name": "새우깡",
    "corrected_ingredient_text": "소맥분(밀:미국산), 새우(국산), 대두유, 우유",
    "corrected_warning_text": "이 제품은 난류, 땅콩을 사용한 제품과 같은 제조 시설에서 제조하고 있습니다.",
    "ocr_corrections": [{"ocr": "유유", "corrected": "우유"}, {"ocr": "계런", "corrected": "계란"}],
    "allergen_judgements": [
        {"allergen": "우유", "level": "위험", "evidence": "우유"},
        {"allergen": "난류", "level": "주의", "evidence": "난류 (같은 제조 시설)"},
        {"allergen": "대두", "level": "위험", "evidence": "대두유"},
        {"allergen": "고등어", "level": "안전", "evidence": ""},
    ],
    "translation": {
        "ingredients": "Wheat flour (wheat: USA), shrimp (Korea), soybean oil, milk",
        "warning": "Manufactured in the same facility that processes eggs and peanuts.",
        "allergen_names": {"우유": "Milk", "난류": "Eggs", "대두": "Soybean", "고등어": "Mackerel"},
        "summary": "Contains milk and soybean. May contain eggs.",
    },
    "notes": "",
}

ALLERGENS = ["우유", "난류", "대두", "고등어"]


def test_merge_takes_more_severe_level():
    rule = {"위험": ["우유"], "주의": ["대두"], "안전": ["난류", "고등어"]}
    final, details = merge_results(rule, LLM_OUTPUT, ALLERGENS)
    assert final == {"위험": ["우유", "대두"], "주의": ["난류"], "안전": ["고등어"]}
    assert {d["allergen"] for d in details if not d["agreed"]} == {"대두", "난류"}


def test_llm_cannot_downgrade_rule_result():
    rule = {"위험": ["고등어"], "주의": [], "안전": []}
    final, _ = merge_results(rule, LLM_OUTPUT, ["고등어"])  # LLM은 안전이라 판정
    assert final["위험"] == ["고등어"]


def test_missing_llm_judgement_keeps_rule_level():
    rule = {"위험": [], "주의": ["땅콩"], "안전": []}
    final, details = merge_results(rule, LLM_OUTPUT, ["땅콩"])
    assert final["주의"] == ["땅콩"] and details[0]["llm"] is None


def test_verify_and_translate_response_shape(tmp_path):
    img = tmp_path / "label.jpg"
    _make_image(img)
    client = FakeClient(LLM_OUTPUT)
    rule = {"위험": ["우유", "대두"], "주의": ["난류"], "안전": ["고등어"]}

    res = verify_and_translate(
        str(img), [{"text": "유유 대두", "confidence": 0.41}], ALLERGENS,
        {"우유": ["우유", "유유"]}, rule, "en", client=client,
    )

    assert res["위험"] == ["우유", "대두"]
    assert res["verification"]["status"] == "verified"
    assert res["verification"]["needs_recheck"] is False
    assert res["translation"]["language"] == "en"
    assert res["translation"]["allergen_names"]["우유"] == "Milk"

    # 요청 검증: 이미지 + 텍스트, 강제 도구 호출, 이미지 축소
    req = client.last_request
    assert req["tool_choice"] == {"type": "tool", "name": "report_verification"}
    content = req["messages"][0]["content"]
    assert content[0]["type"] == "image" and "English" in content[1]["text"]
    import base64
    sent = Image.open(io.BytesIO(base64.b64decode(content[0]["source"]["data"])))
    assert max(sent.size) <= llm_verifier.MAX_IMAGE_EDGE


def test_falls_back_when_llm_fails(tmp_path):
    img = tmp_path / "label.jpg"
    _make_image(img)
    rule = {"위험": ["우유"], "주의": [], "안전": ["난류"]}
    res = verify_and_translate(
        str(img), [], ["우유", "난류"], {}, rule, "en", client=FakeClient(error=TimeoutError("timeout")),
    )
    assert res["위험"] == ["우유"] and res["안전"] == ["난류"]
    assert res["verification"]["status"] == "unavailable"
    assert res["translation"] is None


def test_no_api_key_falls_back(tmp_path, monkeypatch):
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    img = tmp_path / "label.jpg"
    _make_image(img)
    res = verify_and_translate(str(img), [], ["우유"], {}, {"위험": [], "주의": [], "안전": ["우유"]})
    assert res["verification"]["status"] == "unavailable"


def test_verify_endpoint(tmp_path, monkeypatch):
    """EasyOCR·Supabase를 가짜로 바꿔 /scan/verify 전체 흐름을 확인한다."""
    monkeypatch.chdir(tmp_path)

    fake_reader = SimpleNamespace(readtext=lambda p: [
        (None, "유유 대두 밀 새유", 0.4),
        (None, "이제품은계런 땅콩을 사용한 제품과 같은 제조 시설에서 제조", 0.3),
    ])
    sys.modules["easyocr"] = types.SimpleNamespace(Reader=lambda langs: fake_reader)
    db = types.ModuleType("DB.allergen_lookup")
    db.get_allergen_db = lambda: {
        "우유": ["우유", "유유"], "난류": ["난류", "계란", "계런"],
        "대두": ["대두"], "고등어": ["고등어"],
    }
    db.get_alternatives = lambda a, n: []
    sys.modules["DB.allergen_lookup"] = db
    for m in ("server", "allergen_matcher"):
        sys.modules.pop(m, None)

    import server
    from fastapi.testclient import TestClient

    fake = FakeClient(LLM_OUTPUT)
    real = llm_verifier.verify_and_translate
    monkeypatch.setattr(server, "verify_and_translate", lambda *a: real(*a, client=fake))

    buf = io.BytesIO()
    Image.new("RGB", (800, 600), "white").save(buf, "PNG")
    files = {"file": ("성분표.png", buf.getvalue(), "image/png")}
    data = {"allergens": ",".join(ALLERGENS), "target_lang": "en"}

    api = TestClient(server.app)
    r = api.post("/scan/verify", files=files, data=data)
    assert r.status_code == 200, r.text
    body = r.json()
    assert set(body["위험"]) == {"우유", "대두"}
    assert body["주의"] == ["난류"]
    assert body["translation"]["summary"]

    # 기존 /scan은 형식 그대로
    r2 = api.post("/scan", files=files, data={"allergens": "우유,난류"})
    assert r2.json() == {"위험": ["우유"], "주의": ["난류"], "안전": []}

    # 지원하지 않는 언어
    r3 = api.post("/scan/verify", files=files, data={**data, "target_lang": "xx"})
    assert r3.status_code == 400
