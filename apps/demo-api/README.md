# demo-api

A tiny Python FastAPI app with exactly 3 endpoints. Its only job is to be deployable — health checks for Kubernetes, and `/version` to prove which image is actually running.

## Endpoints

| Endpoint | Response |
|----------|----------|
| `GET /health` | `{"status": "ok"}` |
| `GET /ready` | `{"status": "ready"}` |
| `GET /version` | `{"service", "version", "environment", "commit"}` |

No `/metrics` — that's v0.5 territory.

## Run locally

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

## Run tests

```bash
python -m pytest tests/ -v
```

## Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `APP_VERSION` | `dev` | image tag injected by CI (e.g. `sha-abc1234`) |
| `APP_ENV` | `dev` | environment name |
| `GIT_COMMIT` | `unknown` | full commit SHA |
