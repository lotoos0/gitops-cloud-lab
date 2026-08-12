# demo-api

`demo-api` is a deliberately tiny FastAPI service. It has **3 endpoints** and
**4 tests** because its real job is not business logic; its job is to make a
container delivery pipeline observable.

> **Why I kept it tiny:** when `/version` reports the wrong SHA, I want to debug
> GitOps, not wonder whether an exciting domain model has joined the incident.

## HTTP contract

| Endpoint | Expected response | Kubernetes job |
| --- | --- | --- |
| `GET /health` | `{"status":"ok"}` | liveness probe |
| `GET /ready` | `{"status":"ready"}` | readiness probe |
| `GET /version` | `service`, `version`, `environment`, `commit` | deployment proof |

`GET /metrics` intentionally returns `404`; monitoring sits outside the final
scope, and one of the **4 tests** protects that boundary.

## Run it locally

From `apps/demo-api/`:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

The server listens on `http://127.0.0.1:8000` by default. Try:

```bash
curl http://127.0.0.1:8000/version
```

With no environment overrides, the response uses `version=dev`,
`environment=dev` and `commit=unknown`. Honest defaults: no fake provenance.

## Run the tests

```bash
python -m pytest tests/ -v
```

The suite checks **2 probe responses**, **5 fields/values** on `/version`, and
**1 intentional 404** for `/metrics` across **4 test functions**.

## Runtime metadata

| Variable | Default | What it tells the reader |
| --- | --- | --- |
| `APP_VERSION` | `dev` | image tag, for example `sha-abc1234` |
| `APP_ENV` | `dev` | deployment environment |
| `GIT_COMMIT` | `unknown` | full source commit SHA |

CI bakes the version and commit into the image. Helm supplies the environment
at runtime, which lets the same artifact run in dev and prod without changing
its coat in the hallway.
