#!/bin/sh
set -e
python manage.py migrate --noinput
exec gunicorn project4.wsgi:application \
  --bind 0.0.0.0:${PORT:-8000} \
  --workers 3 \
  --access-logfile -