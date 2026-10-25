# Backend

Backend scaffold for Sentinel-AI.

## Required environment variables

Create a `.env` file in this directory before starting the API:

```env
APP_NAME=Sentinel AI API
APP_ENV=development
DEBUG=true
DATABASE_URL=postgresql+psycopg://user:password@localhost:5432/sentinel
SECRET_KEY=replace-with-a-long-random-secret
GROQ_API_KEY=replace-with-your-groq-key
GROQ_MODEL=llama-3.1-8b-instant
```

Install dependencies before running the server:

```powershell
python -m pip install -r requirements.txt
```

## Run locally

From `E:\Virtual_Assistant\Backend`, run:

```powershell
e:/Virtual_Assistant/.venv/Scripts/python.exe -m uvicorn app.main:app --reload
```

Use `python -m uvicorn` instead of the `uvicorn` launcher if your virtualenv was moved or recreated, because the launcher can keep an old absolute path.
