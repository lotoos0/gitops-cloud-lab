import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_ready():
    response = client.get("/ready")
    assert response.status_code == 200
    assert response.json() == {"status": "ready"}


def test_version_fields():
    response = client.get("/version")
    assert response.status_code == 200
    body = response.json()
    assert "service" in body
    assert "version" in body
    assert "environment" in body
    assert "commit" in body
    assert body["service"] == "demo-api"


def test_no_metrics_endpoint():
    response = client.get("/metrics")
    assert response.status_code == 404
