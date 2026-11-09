import os

import httpx

BASE_URL = os.environ.get("BASE_URL", "http://hello")
MESSAGE = os.environ.get("MESSAGE", "hello")


def test_healthz() -> None:
    response = httpx.get(f"{BASE_URL}/healthz", timeout=5)
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_root() -> None:
    response = httpx.get(f"{BASE_URL}/", timeout=5)
    assert response.status_code == 200
    body = response.json()
    assert body["message"] == MESSAGE
    assert body["pod"]
