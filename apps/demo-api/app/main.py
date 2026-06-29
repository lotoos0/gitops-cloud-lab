from fastapi import FastAPI
from app.version import SERVICE, VERSION, ENVIRONMENT, COMMIT

app = FastAPI(title=SERVICE)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/ready")
def ready():
    return {"status": "ready"}


@app.get("/version")
def version():
    return {
        "service": SERVICE,
        "version": VERSION,
        "environment": ENVIRONMENT,
        "commit": COMMIT,
    }
