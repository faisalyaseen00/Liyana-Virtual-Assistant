# Production image for the Liyana backend (used by Railway: with the
# service Root Directory set to "Backend", Railway builds this file).
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Install dependencies first so code changes don't reinstall them.
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

# Run as a non-root user.
RUN useradd --create-home appuser && chown -R appuser /app
USER appuser

# Runs migrations, then starts uvicorn on $PORT (read in Python, so no
# shell is needed). See app/serve.py.
CMD ["python", "-m", "app.serve"]
