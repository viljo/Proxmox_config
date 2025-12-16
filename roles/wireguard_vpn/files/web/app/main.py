"""WireGuard VPN Management Web UI."""

import os
import subprocess
import secrets
from datetime import datetime
from pathlib import Path

from fastapi import FastAPI, Request, HTTPException, Depends
from fastapi.responses import HTMLResponse, RedirectResponse, PlainTextResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from starlette.middleware.sessions import SessionMiddleware
import httpx

app = FastAPI(title="WireGuard VPN Manager")

# Configuration
GITLAB_URL = os.getenv("GITLAB_URL", "https://gitlab.com")
GITLAB_CLIENT_ID = os.getenv("GITLAB_CLIENT_ID", "")
GITLAB_CLIENT_SECRET = os.getenv("GITLAB_CLIENT_SECRET", "")
GITLAB_REDIRECT_URI = os.getenv("GITLAB_REDIRECT_URI", "https://vpn.viljo.se/auth/callback")
SECRET_KEY = os.getenv("SECRET_KEY", secrets.token_hex(32))
ALLOWED_USERS = os.getenv("ALLOWED_USERS", "Viljosson").split(",")
WG_CONFIG_PATH = os.getenv("WG_CONFIG_PATH", "/etc/wireguard")
SERVER_PUBLIC_KEY_PATH = os.getenv("SERVER_PUBLIC_KEY_PATH", "/etc/wireguard/server_public.key")
WG_ENDPOINT = os.getenv("WG_ENDPOINT", "vpn.viljo.se:51820")
WG_ALLOWED_IPS = os.getenv("WG_ALLOWED_IPS", "192.168.1.0/24, 172.31.31.0/24, 10.10.10.0/24")
WG_DNS = os.getenv("WG_DNS", "1.1.1.1")

app.add_middleware(SessionMiddleware, secret_key=SECRET_KEY)

# Templates
templates_dir = Path(__file__).parent / "templates"
templates = Jinja2Templates(directory=str(templates_dir))


def get_current_user(request: Request) -> dict | None:
    """Get current user from session."""
    return request.session.get("user")


def require_auth(request: Request) -> dict:
    """Require authentication."""
    user = get_current_user(request)
    if not user:
        raise HTTPException(status_code=401, detail="Not authenticated")
    if user["username"] not in ALLOWED_USERS:
        raise HTTPException(status_code=403, detail="Access denied")
    return user


def get_server_public_key() -> str:
    """Read server public key."""
    try:
        return Path(SERVER_PUBLIC_KEY_PATH).read_text().strip()
    except Exception:
        return "SERVER_KEY_NOT_FOUND"


def get_next_peer_ip() -> str:
    """Get next available peer IP."""
    try:
        result = subprocess.run(
            ["wg", "show", "wg0", "allowed-ips"],
            capture_output=True, text=True
        )
        lines = result.stdout.strip().split("\n") if result.stdout.strip() else []
        # Start from 10.10.10.2 (10.10.10.1 is server)
        next_num = len(lines) + 2
        return f"10.10.10.{next_num}"
    except Exception:
        return "10.10.10.2"


def get_peers() -> list:
    """Get list of existing peers."""
    peers = []
    try:
        result = subprocess.run(
            ["wg", "show", "wg0", "dump"],
            capture_output=True, text=True
        )
        lines = result.stdout.strip().split("\n")
        # Skip first line (interface info)
        for line in lines[1:]:
            parts = line.split("\t")
            if len(parts) >= 4:
                peers.append({
                    "public_key": parts[0][:16] + "...",
                    "allowed_ips": parts[3],
                    "last_handshake": parts[4] if len(parts) > 4 and parts[4] != "0" else "Never",
                    "transfer": f"rx: {int(parts[5])//1024}KB, tx: {int(parts[6])//1024}KB" if len(parts) > 6 else "N/A"
                })
    except Exception as e:
        pass
    return peers


def generate_peer_keys(peer_name: str) -> tuple:
    """Generate keys for a new peer."""
    private_key = subprocess.run(
        ["wg", "genkey"], capture_output=True, text=True
    ).stdout.strip()

    public_key = subprocess.run(
        ["wg", "pubkey"], input=private_key, capture_output=True, text=True
    ).stdout.strip()

    preshared_key = subprocess.run(
        ["wg", "genpsk"], capture_output=True, text=True
    ).stdout.strip()

    return private_key, public_key, preshared_key


def add_peer_to_config(peer_name: str, public_key: str, preshared_key: str, peer_ip: str):
    """Add peer to WireGuard config."""
    peer_config = f"""
# {peer_name} - added {datetime.now().strftime('%Y-%m-%d %H:%M')}
[Peer]
PublicKey = {public_key}
PresharedKey = {preshared_key}
AllowedIPs = {peer_ip}/32
"""
    config_path = Path(WG_CONFIG_PATH) / "wg0.conf"
    with open(config_path, "a") as f:
        f.write(peer_config)

    # Reload WireGuard
    subprocess.run(["systemctl", "restart", "wg-quick@wg0"])


def generate_client_config(peer_name: str, private_key: str, preshared_key: str, peer_ip: str) -> str:
    """Generate client config file content."""
    server_public_key = get_server_public_key()
    return f"""[Interface]
PrivateKey = {private_key}
Address = {peer_ip}/32
DNS = {WG_DNS}

[Peer]
PublicKey = {server_public_key}
PresharedKey = {preshared_key}
Endpoint = {WG_ENDPOINT}
AllowedIPs = {WG_ALLOWED_IPS}
PersistentKeepalive = 25
"""


@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    """Main page."""
    user = get_current_user(request)
    if not user:
        return templates.TemplateResponse("login.html", {"request": request})

    if user["username"] not in ALLOWED_USERS:
        return templates.TemplateResponse("denied.html", {"request": request, "user": user})

    peers = get_peers()
    return templates.TemplateResponse("index.html", {
        "request": request,
        "user": user,
        "peers": peers,
        "server_public_key": get_server_public_key()[:20] + "..."
    })


@app.get("/auth/login")
async def login():
    """Redirect to GitLab OAuth."""
    params = {
        "client_id": GITLAB_CLIENT_ID,
        "redirect_uri": GITLAB_REDIRECT_URI,
        "response_type": "code",
        "scope": "read_user"
    }
    query = "&".join(f"{k}={v}" for k, v in params.items())
    return RedirectResponse(f"{GITLAB_URL}/oauth/authorize?{query}")


@app.get("/auth/callback")
async def callback(request: Request, code: str = None, error: str = None):
    """OAuth callback."""
    if error:
        raise HTTPException(status_code=400, detail=error)

    if not code:
        raise HTTPException(status_code=400, detail="No code provided")

    # Exchange code for token
    async with httpx.AsyncClient() as client:
        token_response = await client.post(
            f"{GITLAB_URL}/oauth/token",
            data={
                "client_id": GITLAB_CLIENT_ID,
                "client_secret": GITLAB_CLIENT_SECRET,
                "code": code,
                "grant_type": "authorization_code",
                "redirect_uri": GITLAB_REDIRECT_URI
            }
        )

        if token_response.status_code != 200:
            raise HTTPException(status_code=400, detail="Failed to get token")

        token_data = token_response.json()
        access_token = token_data["access_token"]

        # Get user info
        user_response = await client.get(
            f"{GITLAB_URL}/api/v4/user",
            headers={"Authorization": f"Bearer {access_token}"}
        )

        if user_response.status_code != 200:
            raise HTTPException(status_code=400, detail="Failed to get user info")

        user_data = user_response.json()
        request.session["user"] = {
            "id": user_data["id"],
            "username": user_data["username"],
            "name": user_data.get("name", user_data["username"]),
            "avatar_url": user_data.get("avatar_url", "")
        }

    return RedirectResponse("/")


@app.get("/auth/logout")
async def logout(request: Request):
    """Logout."""
    request.session.clear()
    return RedirectResponse("/")


@app.post("/peers/add")
async def add_peer(request: Request, user: dict = Depends(require_auth)):
    """Add a new peer."""
    form = await request.form()
    peer_name = form.get("peer_name", "").strip()

    if not peer_name:
        raise HTTPException(status_code=400, detail="Peer name required")

    # Sanitize peer name
    peer_name = "".join(c for c in peer_name if c.isalnum() or c in "-_")

    # Generate keys and IP
    private_key, public_key, preshared_key = generate_peer_keys(peer_name)
    peer_ip = get_next_peer_ip()

    # Add to server config
    add_peer_to_config(peer_name, public_key, preshared_key, peer_ip)

    # Generate client config
    client_config = generate_client_config(peer_name, private_key, preshared_key, peer_ip)

    # Store in session for download
    request.session["last_config"] = {
        "name": peer_name,
        "config": client_config,
        "ip": peer_ip
    }

    return RedirectResponse("/peers/download", status_code=303)


@app.get("/peers/download")
async def download_config(request: Request, user: dict = Depends(require_auth)):
    """Download the last generated config."""
    config_data = request.session.get("last_config")
    if not config_data:
        return RedirectResponse("/")

    return templates.TemplateResponse("download.html", {
        "request": request,
        "user": user,
        "peer_name": config_data["name"],
        "peer_ip": config_data["ip"],
        "config": config_data["config"]
    })


@app.get("/peers/download/{peer_name}.conf")
async def download_config_file(request: Request, peer_name: str, user: dict = Depends(require_auth)):
    """Download config as file."""
    config_data = request.session.get("last_config")
    if not config_data or config_data["name"] != peer_name:
        raise HTTPException(status_code=404, detail="Config not found")

    return PlainTextResponse(
        config_data["config"],
        media_type="application/octet-stream",
        headers={"Content-Disposition": f"attachment; filename={peer_name}.conf"}
    )


@app.get("/health")
async def health():
    """Health check."""
    return {"status": "ok"}
