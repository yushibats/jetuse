"""自動作成した project の DP 反映待ち(PORT-04)。

新しい GenerativeAiProject は CP で ACTIVE になっても、推論(DP)側はしばらく
400 "Invalid OpenAI project." を返す(us-chicago-1 実測で ACTIVE から約10〜20秒)。
デプロイ直後の最初のチャットがこれで失敗していたため、作成直後の project に限り
stream_chat が待ってやり直す。古い project や明示指定の project では待たない
(設定の誤りを待ち時間で隠さない)。
"""

from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

import httpx
import openai
import pytest

from jetuse_core import chat as chat_mod
from jetuse_core import genai
from jetuse_core.settings import Settings

COMP = "ocid1.compartment.oc1..testcomp"
PROJECT = "ocid1.generativeaiproject.oc1..auto"


@pytest.fixture(autouse=True)
def reset_project_cache(monkeypatch):
    genai._reset_project_cache()
    monkeypatch.setattr(genai, "_signer", lambda: None)
    yield
    genai._reset_project_cache()


def _settings(**kw):
    kw.setdefault("compartment_ocid", COMP)
    return Settings(_env_file=None, **kw)


class FakeSdk:
    def __init__(self, items):
        self.items = items

    def list_generative_ai_projects(self, compartment_id, **kw):
        return SimpleNamespace(
            data=SimpleNamespace(items=self.items), has_next_page=False, next_page=None,
            status=200, headers={}, request=None,
        )


def _resolve_with(monkeypatch, created: datetime) -> str:
    project = SimpleNamespace(id=PROJECT, lifecycle_state="ACTIVE", time_created=created)
    monkeypatch.setattr(genai, "_sdk_client", lambda s: FakeSdk([project]))
    return genai.resolve_project_ocid(_settings())


# --- genai.project_is_propagating ---


def test_new_project_is_propagating(monkeypatch):
    _resolve_with(monkeypatch, datetime.now(UTC) - timedelta(seconds=20))
    assert genai.project_is_propagating() is True
    assert genai.project_is_propagating(PROJECT) is True


def test_old_project_is_not_propagating(monkeypatch):
    _resolve_with(monkeypatch, datetime.now(UTC) - timedelta(hours=1))
    assert genai.project_is_propagating() is False


def test_other_project_is_not_judged(monkeypatch):
    # エージェント固有の project など、作成時刻を知らないものは対象外
    _resolve_with(monkeypatch, datetime.now(UTC))
    assert genai.project_is_propagating("ocid1.generativeaiproject.oc1..other") is False


def test_explicit_project_ocid_is_not_judged():
    s = _settings(project_ocid="ocid1.generativeaiproject.oc1..env")
    assert genai.resolve_project_ocid(s) == "ocid1.generativeaiproject.oc1..env"
    assert genai.project_is_propagating() is False


# --- chat.stream_chat のやり直し ---


def _not_ready():
    req = httpx.Request("POST", "https://genai.test/openai/v1/responses")
    body = {"error": {"message": "Invalid OpenAI project.", "type": "invalid_request_error"}}
    resp = httpx.Response(400, request=req, json=body)
    return openai.BadRequestError(
        "Error code: 400 - {'error': {'message': 'Invalid OpenAI project.'}}",
        response=resp, body=body,
    )


def _patch_stream(monkeypatch, failures: int, propagating: bool):
    calls = {"n": 0, "slept": 0.0}

    def fake_stream(*a, **kw):
        calls["n"] += 1
        if calls["n"] <= failures:
            raise _not_ready()
        yield {"delta": "ok"}

    monkeypatch.setattr(chat_mod, "make_inference_client", lambda **kw: object())
    monkeypatch.setattr(chat_mod, "_stream_responses", fake_stream)
    monkeypatch.setattr(chat_mod, "project_is_propagating", lambda p=None: propagating)
    monkeypatch.setattr(
        chat_mod.time, "sleep", lambda s: calls.__setitem__("slept", calls["slept"] + s)
    )
    return calls


def test_retries_while_new_project_propagates(monkeypatch):
    calls = _patch_stream(monkeypatch, failures=3, propagating=True)
    events = list(chat_mod.stream_chat("gpt-oss-120b", [{"role": "user", "content": "hi"}]))
    assert events == [{"delta": "ok"}]
    assert calls["n"] == 4
    assert calls["slept"] == 3 * chat_mod.PROJECT_NOT_READY_RETRY_SECONDS


def test_gives_up_after_max_wait(monkeypatch):
    calls = _patch_stream(monkeypatch, failures=10_000, propagating=True)
    events = list(chat_mod.stream_chat("gpt-oss-120b", [{"role": "user", "content": "hi"}]))
    assert "Invalid OpenAI project" in events[-1]["error"]
    assert calls["slept"] == chat_mod.PROJECT_NOT_READY_MAX_WAIT_SECONDS


def test_does_not_wait_for_old_project(monkeypatch):
    # 作成直後でない project のこのエラーは設定の誤り。待たずにそのまま返す
    calls = _patch_stream(monkeypatch, failures=1, propagating=False)
    events = list(chat_mod.stream_chat("gpt-oss-120b", [{"role": "user", "content": "hi"}]))
    assert "Invalid OpenAI project" in events[-1]["error"]
    assert calls["n"] == 1
    assert calls["slept"] == 0
