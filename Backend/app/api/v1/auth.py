from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.dependencies.db import get_db

from app.schemas.auth import (
    RefreshTokenRequest,
    RegisterRequest,
    LoginRequest,
)

from app.services.auth_service import AuthService

router = APIRouter(
    prefix="/auth",
    tags=["Authentication"],
)

@router.post(
    "/register",
    status_code=status.HTTP_201_CREATED,
)
def register(
    data: RegisterRequest,
    db: Session = Depends(get_db),
):
    try:
        user = AuthService.register_user(
            db,
            data,
        )

        return {
            "message": "User registered successfully",
            "user_id": user.id,
        }

    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )

@router.post("/login")
def login(
    request: Request,
    data: LoginRequest,
    db: Session = Depends(get_db),
):
    try:

        tokens = AuthService.login_user(
            db=db,
            data=data,
            device_info=request.headers.get("User-Agent"),
        )

        return tokens

    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
        )
@router.post("/refresh")
def refresh(
    data: RefreshTokenRequest,
    db: Session = Depends(get_db),
):
    try:
        return AuthService.refresh_access_token(
            db=db,
            refresh_token=data.refresh_token,
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
        )
@router.post("/logout")
def logout(
    data: RefreshTokenRequest,
    db: Session = Depends(get_db),
):
    try:
        AuthService.logout_user(
            db=db,
            refresh_token=data.refresh_token,
        )

        return {
            "message": "Logged out successfully"
        }

    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
        )