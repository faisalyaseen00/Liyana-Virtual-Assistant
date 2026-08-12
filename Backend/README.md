# Backend

Backend scaffold for Sentinel-AI.

## Run locally

From `E:\Virtual_Assistant\Backend`, run:

```powershell
e:/Virtual_Assistant/.venv/Scripts/python.exe -m uvicorn app.main:app --reload
```

Use `python -m uvicorn` instead of the `uvicorn` launcher if your virtualenv was moved or recreated, because the launcher can keep an old absolute path.
