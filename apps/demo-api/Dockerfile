FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ ./app/

ARG GIT_COMMIT=unknown
ARG APP_VERSION=dev
ARG APP_ENV=dev

ENV GIT_COMMIT=${GIT_COMMIT}
ENV APP_VERSION=${APP_VERSION}
ENV APP_ENV=${APP_ENV}

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
