# ---------- build stage ----------
FROM python:3.12-slim AS builder
ENV PIP_NO_CACHE_DIR=1
WORKDIR /build
COPY requirements.txt .
RUN pip install --prefix=/install -r requirements.txt

# ---------- runtime stage ----------
FROM python:3.12-slim
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8000

RUN groupadd -r app && useradd -r -g app app
WORKDIR /app

COPY --from=builder /install /usr/local
COPY . .

# collect static at build time (needs STATIC_ROOT in settings.py)
RUN chmod +x entrypoint.sh \
 && DJANGO_SECRET_KEY=build-only python manage.py collectstatic --noinput \
 ; chown -R app:app /app

USER app
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s \
  CMD python -c "import urllib.request,os; urllib.request.urlopen('http://127.0.0.1:%s/' % os.environ.get('PORT','8000'))" || exit 1

ENTRYPOINT ["./entrypoint.sh"]