from pwdlib import PasswordHash
import hashlib
import secrets

password_hash = PasswordHash.recommended()


def hash_password(password: str) -> str:
    """
    Hash a plain-text password.
    """
    return password_hash.hash(password)


def verify_password(password: str, hashed_password: str) -> bool:
    """
    Verify a password against its hash.
    """
    return password_hash.verify(password, hashed_password)




def generate_refresh_token() -> str:
    """
    Generate a cryptographically secure refresh token.
    """
    return secrets.token_urlsafe(64)


def hash_refresh_token(token: str) -> str:
    """
    Hash a refresh token before storing it.
    """
    return hashlib.sha256(token.encode()).hexdigest()