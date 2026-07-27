from fastapi import FastAPI

from app.api.v1.router import api_router

app = FastAPI(
    title="Sentinel AI API",
    version="1.0.0",
)

app.include_router(api_router)


@app.get("/")
def root():
    return {
        "message": "Sentinel AI Backend Running"
    }
@app.get("/crash")
def crash():
    return {
            "message": "Sentinel AI Backend Running"
    }