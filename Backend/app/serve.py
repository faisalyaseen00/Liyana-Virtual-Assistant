"""Production entry point: `python -m app.serve`.

Reads the port from the PORT environment variable itself, so the start
command contains no `$PORT` (Railway runs start commands without a shell,
which leaves `$PORT` unexpanded and crashes uvicorn). Runs database
migrations first unless RUN_MIGRATIONS=false.
"""

import os
from pathlib import Path

import uvicorn
from alembic import command
from alembic.config import Config

BACKEND_DIR = Path(__file__).resolve().parent.parent


def _flag(name: str, default: bool) -> bool:
    value = os.environ.get(name)
    if value is None:
        return default
    return value.strip().lower() not in ("0", "false", "no", "off")


def run_migrations() -> None:
    config = Config(str(BACKEND_DIR / "alembic.ini"))
    config.set_main_option("script_location", str(BACKEND_DIR / "alembic"))
    command.upgrade(config, "head")


def main() -> None:
    if _flag("RUN_MIGRATIONS", True):
        print("Running database migrations…", flush=True)
        run_migrations()

    port = int(os.environ.get("PORT") or 8000)
    print(f"Starting Liyana API on port {port}", flush=True)

    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=port,
        # Railway terminates HTTPS in front of the app.
        proxy_headers=True,
        forwarded_allow_ips="*",
    )


if __name__ == "__main__":
    main()
