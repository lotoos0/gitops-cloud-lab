import os

SERVICE = "demo-api"
VERSION = os.getenv("APP_VERSION", "dev")
ENVIRONMENT = os.getenv("APP_ENV", "dev")
COMMIT = os.getenv("GIT_COMMIT", "unknown")
