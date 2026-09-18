"""エージェントコンテナの HTTP 契約(PORT-04)。

Hosted Application はコンテナに 0.0.0.0:8080 での listen と、readiness `/ready`・
liveness `/health` を要求する。`/ready` が無いとデプロイが
"timed out before the container was ready to serve requests" で NEEDS_ATTENTION になる
(2026-09 us-chicago-1 実機)。3SDK 共通のサーバー生成でこの2本を固定する。
"""

import sys
from pathlib import Path

from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "agent-containers"))

import server  # noqa: E402


def _client():
    return TestClient(server.create_app("test_sdk", lambda req: None))


def test_ready_and_health_endpoints():
    c = _client()
    for path in ("/ready", "/health"):
        res = c.get(path)
        assert res.status_code == 200, path
        assert res.json() == {"status": "ok", "sdk": "test_sdk"}
