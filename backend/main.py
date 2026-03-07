"""Cruise Ride — FastAPI Backend
Complete implementation matching the Flutter client's ApiService endpoints.
Hardened with 8 layers of security protection.
"""

import os, time, hmac, hashlib, math, secrets, logging, collections, re
from datetime import datetime, timedelta, timezone
from contextlib import asynccontextmanager
from typing import Optional, List

import base64
from fastapi import FastAPI, Depends, HTTPException, Header, Request, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, field_validator
from jose import jwt, JWTError
from passlib.context import CryptContext
from sqlalchemy import (
    Column, Integer, String, Float, Boolean, DateTime, ForeignKey, Text, select, func, and_
)
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase, relationship

# ── Config ──────────────────────────────────────────────
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite+aiosqlite:///./cruise.db")
API_KEY = os.getenv("API_KEY", "HWB88VurhLM-1GdVML2PT92iqNSbeJ52TU1VO37MBZS6RYlyWvfIpaTdD54GT_5u")
HMAC_SECRET = os.getenv("HMAC_SECRET", "qUDmTNu1Dxxg_xo7kaUfRba4XiU_5H1ZhkUMDuVrD2dLQ2ImT8JXZ5FgUyXpSJ5h")
JWT_SECRET = os.getenv("JWT_SECRET", "cruise-jwt-super-secret-key-change-in-production")
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_HOURS = 720  # 30 days

engine = create_async_engine(DATABASE_URL, echo=False)
SessionLocal = async_sessionmaker(engine, expire_on_commit=False)
pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")

# ── Models ──────────────────────────────────────────────
class Base(DeclarativeBase):
    pass

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    email = Column(String(255), unique=True, nullable=True, index=True)
    phone = Column(String(30), unique=True, nullable=True, index=True)
    password_hash = Column(String(255), nullable=False)
    photo_url = Column(Text, nullable=True)
    role = Column(String(20), default="rider")  # rider | driver
    is_online = Column(Boolean, default=False)
    lat = Column(Float, nullable=True)
    lng = Column(Float, nullable=True)
    is_verified = Column(Boolean, default=False)
    id_document_type = Column(String(30), nullable=True)  # license, passport, id_card
    verification_status = Column(String(20), default="none")  # none, pending, approved, rejected
    verification_reason = Column(Text, nullable=True)  # rejection reason
    verified_at = Column(DateTime, nullable=True)
    status = Column(String(20), default="active")  # active, blocked, deleted
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

class Trip(Base):
    __tablename__ = "trips"
    id = Column(Integer, primary_key=True, index=True)
    rider_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    driver_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    pickup_address = Column(Text, nullable=False)
    dropoff_address = Column(Text, nullable=False)
    pickup_lat = Column(Float, nullable=False)
    pickup_lng = Column(Float, nullable=False)
    dropoff_lat = Column(Float, nullable=False)
    dropoff_lng = Column(Float, nullable=False)
    fare = Column(Float, nullable=True)
    vehicle_type = Column(String(30), nullable=True)
    status = Column(String(30), default="requested")  # requested, scheduled, driver_en_route, arrived, in_trip, completed, canceled
    scheduled_at = Column(DateTime, nullable=True)  # None = ride now
    is_airport = Column(Boolean, default=False)
    airport_code = Column(String(10), nullable=True)  # e.g. 'BHM', 'ATL'
    terminal = Column(String(50), nullable=True)
    pickup_zone = Column(String(100), nullable=True)  # e.g. 'Terminal A - Door 3'
    notes = Column(Text, nullable=True)  # flight number, special instructions
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

class DispatchOffer(Base):
    __tablename__ = "dispatch_offers"
    id = Column(Integer, primary_key=True, index=True)
    trip_id = Column(Integer, ForeignKey("trips.id"), nullable=False)
    driver_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    status = Column(String(20), default="pending")  # pending, accepted, rejected, expired
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

class PayoutMethod(Base):
    __tablename__ = "payout_methods"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    method_type = Column(String(50), nullable=False)
    display_name = Column(String(255), nullable=False)
    is_default = Column(Boolean, default=False)

class Cashout(Base):
    __tablename__ = "cashouts"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    amount = Column(Float, nullable=False)
    status = Column(String(20), default="pending")
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

# ── Firestore Sync ─────────────────────────────────────
try:
    import firestore_sync
    _HAS_FIRESTORE = True
except ImportError:
    _HAS_FIRESTORE = False
    logging.warning("firestore_sync module not available — dispatch sync disabled")

# ── App lifecycle ───────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Create tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    # Bulk-sync existing data to Firestore on startup
    if _HAS_FIRESTORE:
        try:
            await firestore_sync.bulk_sync_all(SessionLocal)
        except Exception as e:
            logging.error("Bulk Firestore sync failed: %s", e)
    yield

app = FastAPI(title="Cruise Ride API", lifespan=lifespan, docs_url=None, redoc_url=None)

# ═══════════════════════════════════════════════════════
#  8 LAYERS OF SECURITY PROTECTION
# ═══════════════════════════════════════════════════════

# ── LAYER 1: CORS — Only allow app origins ─────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:8000", "http://127.0.0.1:8000"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PATCH", "DELETE"],
    allow_headers=["Authorization", "Content-Type", "X-Api-Key", "X-Timestamp", "X-Nonce", "X-Signature"],
)

# ── LAYER 2: Security Headers ─────────────────────────
@app.middleware("http")
async def security_headers_middleware(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Permissions-Policy"] = "geolocation=(), camera=(), microphone=()"
    response.headers["Content-Security-Policy"] = "default-src 'none'; frame-ancestors 'none'"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    # Hide server identity
    if "server" in response.headers:
        del response.headers["server"]
    return response

# ── LAYER 3: Rate Limiting (per-IP, anti-DDoS) ────────
_rate_buckets: dict[str, collections.deque] = {}
_RATE_LIMIT = 60          # max requests …
_RATE_WINDOW = 60         # … per this many seconds

@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    client_ip = request.client.host if request.client else "unknown"
    now = time.monotonic()
    bucket = _rate_buckets.setdefault(client_ip, collections.deque())
    while bucket and bucket[0] < now - _RATE_WINDOW:
        bucket.popleft()
    if len(bucket) >= _RATE_LIMIT:
        return JSONResponse({"detail": "Rate limit exceeded"}, status_code=429)
    bucket.append(now)
    return await call_next(request)

# ── LAYER 4: Request Size Limit (anti-payload bomb) ───
_MAX_BODY_SIZE = 5 * 1024 * 1024  # 5 MB max (photos are ~1-2MB base64)

@app.middleware("http")
async def request_size_limit_middleware(request: Request, call_next):
    content_length = request.headers.get("content-length")
    if content_length and int(content_length) > _MAX_BODY_SIZE:
        return JSONResponse({"detail": "Request body too large"}, status_code=413)
    return await call_next(request)

# ── LAYER 5: Brute Force Protection (login) ───────────
_login_attempts: dict[str, list] = {}  # ip -> [(timestamp, count)]
_LOGIN_MAX_ATTEMPTS = 5
_LOGIN_LOCKOUT_SECONDS = 300  # 5 minutes lockout

def _check_login_throttle(client_ip: str) -> bool:
    """Returns True if login is BLOCKED for this IP."""
    now = time.monotonic()
    record = _login_attempts.get(client_ip)
    if not record:
        return False
    # Clean old entries
    _login_attempts[client_ip] = [
        (ts, cnt) for ts, cnt in record if now - ts < _LOGIN_LOCKOUT_SECONDS
    ]
    record = _login_attempts.get(client_ip, [])
    total = sum(cnt for _, cnt in record)
    return total >= _LOGIN_MAX_ATTEMPTS

def _record_login_failure(client_ip: str):
    now = time.monotonic()
    _login_attempts.setdefault(client_ip, []).append((now, 1))

def _clear_login_failures(client_ip: str):
    _login_attempts.pop(client_ip, None)

# ── LAYER 6: IP Blacklist (auto-ban suspicious IPs) ───
_ip_blacklist: set[str] = set()
_ip_violations: dict[str, int] = {}  # ip -> violation count
_IP_BAN_THRESHOLD = 20  # violations before auto-ban

@app.middleware("http")
async def ip_blacklist_middleware(request: Request, call_next):
    client_ip = request.client.host if request.client else "unknown"
    if client_ip in _ip_blacklist:
        return JSONResponse({"detail": "Access denied"}, status_code=403)
    return await call_next(request)

def _record_violation(client_ip: str):
    """Record a security violation. Auto-ban after threshold."""
    _ip_violations[client_ip] = _ip_violations.get(client_ip, 0) + 1
    if _ip_violations[client_ip] >= _IP_BAN_THRESHOLD:
        _ip_blacklist.add(client_ip)
        logging.warning("[BANNED] IP auto-banned: %s (violations: %d)", client_ip, _ip_violations[client_ip])

# ── LAYER 7: Input Sanitization ───────────────────────
_SQL_INJECTION_PATTERN = re.compile(
    r"(\b(SELECT|INSERT|UPDATE|DELETE|DROP|UNION|ALTER|CREATE|EXEC)\b.*\b(FROM|INTO|TABLE|SET|WHERE)\b)|"
    r"(--|;.*--|/\*|\*/|xp_|0x[0-9a-fA-F]{8,})",
    re.IGNORECASE
)
_XSS_PATTERN = re.compile(r"<\s*script|javascript\s*:|on\w+\s*=", re.IGNORECASE)

def _sanitize_string(value: str) -> str:
    """Strip dangerous characters from input strings."""
    if not value:
        return value
    # Reject SQL injection attempts
    if _SQL_INJECTION_PATTERN.search(value):
        raise HTTPException(400, "Invalid input detected")
    # Reject XSS attempts
    if _XSS_PATTERN.search(value):
        raise HTTPException(400, "Invalid input detected")
    return value.strip()

# ── LAYER 8: Crash Protection & Error Handling ────────
@app.middleware("http")
async def crash_protection_middleware(request: Request, call_next):
    try:
        response = await call_next(request)
        return response
    except Exception as e:
        client_ip = request.client.host if request.client else "unknown"
        logging.error("[CRASH] Unhandled error from %s on %s: %s", client_ip, request.url.path, str(e))
        return JSONResponse(
            {"detail": "Internal server error"},
            status_code=500,
        )

# ── Health check (public, no auth) ────────────────────
@app.get("/health")
async def health():
    return {"status": "ok", "timestamp": datetime.now(timezone.utc).isoformat()}

# ── Dependencies ────────────────────────────────────────
async def get_db():
    async with SessionLocal() as session:
        yield session

def _verify_api_key(
    x_api_key: str = Header(...),
    x_timestamp: str = Header(...),
    x_nonce: str = Header(...),
    x_signature: str = Header(...),
):
    """Validates API key and HMAC signature."""
    if x_api_key != API_KEY:
        raise HTTPException(401, "Invalid API key")
    # Verify timestamp is within 5 minutes
    try:
        ts = int(x_timestamp)
        now = int(time.time())
        if abs(now - ts) > 300:
            raise HTTPException(401, "Timestamp expired")
    except ValueError:
        raise HTTPException(401, "Invalid timestamp")
    # Verify HMAC signature
    message = f"{x_api_key}:{x_timestamp}:{x_nonce}"
    expected = hmac.new(
        HMAC_SECRET.encode(), message.encode(), hashlib.sha256
    ).hexdigest()
    if not hmac.compare_digest(expected, x_signature):
        raise HTTPException(401, "Invalid signature")

def _create_token(user_id: int) -> str:
    expire = datetime.now(timezone.utc) + timedelta(hours=JWT_EXPIRE_HOURS)
    return jwt.encode({"sub": str(user_id), "exp": expire}, JWT_SECRET, algorithm=JWT_ALGORITHM)

def _create_login_token(user_id: int) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=10)
    return jwt.encode({"sub": str(user_id), "type": "login", "exp": expire}, JWT_SECRET, algorithm=JWT_ALGORITHM)

async def _get_current_user(
    authorization: str = Header(None),
    db: AsyncSession = Depends(get_db),
):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "Not authenticated")
    token = authorization.split(" ")[1]
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        user_id = int(payload["sub"])
    except (JWTError, ValueError):
        raise HTTPException(401, "Invalid token")
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(401, "User not found")
    return user

def _user_dict(u: User) -> dict:
    return {
        "id": u.id,
        "first_name": u.first_name,
        "last_name": u.last_name,
        "email": u.email,
        "phone": u.phone,
        "photo_url": u.photo_url,
        "role": u.role,
        "is_verified": u.is_verified or False,
        "id_document_type": u.id_document_type,
        "verification_status": u.verification_status or "none",
        "verification_reason": u.verification_reason,
        "verified_at": u.verified_at.isoformat() if u.verified_at else None,
        "status": u.status or "active",
    }

# ── Schemas (with input validation) ─────────────────────
class RegisterIn(BaseModel):
    first_name: str
    last_name: str
    email: Optional[str] = None
    phone: Optional[str] = None
    password: str
    photo_url: Optional[str] = None
    role: str = "rider"  # rider | driver

    @field_validator('first_name', 'last_name')
    @classmethod
    def validate_name(cls, v):
        v = v.strip()
        if len(v) > 100:
            raise ValueError('Name too long')
        _sanitize_string(v)
        return v

    @field_validator('email')
    @classmethod
    def validate_email(cls, v):
        if v is None:
            return v
        v = v.strip().lower()
        if len(v) > 255 or '@' not in v:
            raise ValueError('Invalid email')
        _sanitize_string(v)
        return v

    @field_validator('password')
    @classmethod
    def validate_password(cls, v):
        if len(v) < 6 or len(v) > 128:
            raise ValueError('Password must be 6-128 characters')
        return v

class CheckExistsIn(BaseModel):
    identifier: str

class LoginIn(BaseModel):
    identifier: str
    password: str

class CompleteLoginIn(BaseModel):
    login_token: str

class CreateTripIn(BaseModel):
    rider_id: int
    pickup_address: str
    dropoff_address: str
    pickup_lat: float
    pickup_lng: float
    dropoff_lat: float
    dropoff_lng: float
    fare: Optional[float] = None
    vehicle_type: Optional[str] = None
    scheduled_at: Optional[str] = None  # ISO datetime string
    is_airport: bool = False
    airport_code: Optional[str] = None
    terminal: Optional[str] = None
    pickup_zone: Optional[str] = None
    notes: Optional[str] = None

class AcceptTripIn(BaseModel):
    driver_id: int

class DriverLocationIn(BaseModel):
    lat: float
    lng: float
    is_online: bool = True

class CashoutIn(BaseModel):
    amount: float

class PayoutMethodIn(BaseModel):
    method_type: str
    display_name: str
    set_default: bool = False

class DispatchRequestIn(BaseModel):
    rider_id: int
    pickup_address: str
    dropoff_address: str
    pickup_lat: float
    pickup_lng: float
    dropoff_lat: float
    dropoff_lng: float
    fare: Optional[float] = None
    vehicle_type: Optional[str] = None

# ═══════════════════════════════════════════════════════
#  AUTH  ENDPOINTS
# ═══════════════════════════════════════════════════════

@app.post("/auth/register", dependencies=[Depends(_verify_api_key)])
async def register(body: RegisterIn, db: AsyncSession = Depends(get_db)):
    # Check duplicates — return 409 so the Flutter client can auto-login
    if body.email:
        exists = await db.execute(select(User).where(User.email == body.email))
        if exists.scalar_one_or_none():
            raise HTTPException(409, "Email already registered")
    if body.phone:
        exists = await db.execute(select(User).where(User.phone == body.phone))
        if exists.scalar_one_or_none():
            raise HTTPException(409, "Phone already registered")

    role = body.role if body.role in ("rider", "driver") else "rider"
    user = User(
        first_name=body.first_name,
        last_name=body.last_name,
        email=body.email,
        phone=body.phone,
        password_hash=pwd.hash(body.password),
        photo_url=body.photo_url,
        role=role,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    # Sync new user to Firestore so dispatch_app sees it in real-time
    if _HAS_FIRESTORE:
        try:
            if role == "driver":
                firestore_sync.sync_driver(
                    user_id=user.id, first_name=user.first_name,
                    last_name=user.last_name, phone=user.phone or "",
                    email=user.email, photo_url=user.photo_url,
                    is_online=False, created_at=user.created_at,
                    password_hash=user.password_hash,
                    is_verified=False,
                )
            else:
                firestore_sync.sync_client(
                    user_id=user.id, first_name=user.first_name,
                    last_name=user.last_name, phone=user.phone or "",
                    email=user.email, photo_url=user.photo_url,
                    role=user.role, created_at=user.created_at,
                    password_hash=user.password_hash,
                    is_verified=False,
                )
        except Exception as e:
            logging.error("Firestore sync on register failed: %s", e)

    token = _create_token(user.id)
    return {"access_token": token, "token_type": "bearer", "user": _user_dict(user)}

@app.post("/auth/check-exists", dependencies=[Depends(_verify_api_key)])
async def check_exists(body: CheckExistsIn, db: AsyncSession = Depends(get_db)):
    identifier = body.identifier.strip()
    result = await db.execute(
        select(User).where((User.email == identifier) | (User.phone == identifier))
    )
    return {"exists": result.scalar_one_or_none() is not None}

@app.post("/auth/login", dependencies=[Depends(_verify_api_key)])
async def login(body: LoginIn, request: Request, db: AsyncSession = Depends(get_db)):
    client_ip = request.client.host if request.client else "unknown"

    # Layer 5: Brute force protection
    if _check_login_throttle(client_ip):
        _record_violation(client_ip)
        raise HTTPException(429, "Too many login attempts. Try again in 5 minutes.")

    identifier = body.identifier.strip()
    _sanitize_string(identifier)

    # Normalize phone: if it looks like digits, ensure E.164 format
    cleaned = identifier.replace(" ", "").replace("-", "").replace("(", "").replace(")", "")
    if cleaned.lstrip("+").isdigit() and len(cleaned.lstrip("+")) >= 7:
        if not cleaned.startswith("+"):
            cleaned = "+1" + cleaned  # Default to US
        identifier = cleaned

    result = await db.execute(
        select(User).where((User.email == body.identifier) | (User.phone == identifier))
    )
    user = result.scalar_one_or_none()
    if not user or not pwd.verify(body.password, user.password_hash):
        _record_login_failure(client_ip)
        raise HTTPException(401, "Invalid credentials")
    if (user.status or "active") in ("deleted", "blocked"):
        raise HTTPException(403, f"Account {user.status}")

    # Successful login — clear failures
    _clear_login_failures(client_ip)

    login_token = _create_login_token(user.id)
    return {
        "login_token": login_token,
        "method": "email" if user.email == body.identifier else "phone",
        "email": user.email,
        "phone": user.phone,
    }

@app.post("/auth/complete-login", dependencies=[Depends(_verify_api_key)])
async def complete_login(body: CompleteLoginIn, db: AsyncSession = Depends(get_db)):
    try:
        payload = jwt.decode(body.login_token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        if payload.get("type") != "login":
            raise HTTPException(401, "Invalid login token")
        user_id = int(payload["sub"])
    except (JWTError, ValueError):
        raise HTTPException(401, "Invalid or expired login token")

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(404, "User not found")

    token = _create_token(user.id)
    return {"access_token": token, "token_type": "bearer", "user": _user_dict(user)}

@app.get("/auth/me", dependencies=[Depends(_verify_api_key)])
async def get_me(user: User = Depends(_get_current_user)):
    return _user_dict(user)

@app.patch("/auth/me", dependencies=[Depends(_verify_api_key)])
async def update_me(request: Request, user: User = Depends(_get_current_user), db: AsyncSession = Depends(get_db)):
    updates = await request.json()
    # Re-fetch user in THIS session to avoid cross-session detached state
    result = await db.execute(select(User).where(User.id == user.id))
    db_user = result.scalar_one_or_none()
    if not db_user:
        raise HTTPException(404, "User not found")
    for key in ("first_name", "last_name", "email", "phone", "photo_url", "role",
                 "is_verified", "id_document_type", "verification_status", "verification_reason"):
        if key in updates:
            setattr(db_user, key, updates[key])
    if updates.get("is_verified") and not db_user.verified_at:
        db_user.verified_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(db_user)

    # Sync updated profile to Firestore
    if _HAS_FIRESTORE:
        try:
            if db_user.role == "driver":
                firestore_sync.sync_driver(
                    user_id=db_user.id, first_name=db_user.first_name,
                    last_name=db_user.last_name, phone=db_user.phone or "",
                    email=db_user.email, photo_url=db_user.photo_url,
                    is_online=db_user.is_online or False,
                    created_at=db_user.created_at,
                    password_hash=db_user.password_hash,
                    is_verified=db_user.is_verified or False,
                    id_document_type=db_user.id_document_type,
                    verification_status=db_user.verification_status or "none",
                    verification_reason=db_user.verification_reason,
                    status=db_user.status or "active",
                )
            else:
                firestore_sync.sync_client(
                    user_id=db_user.id, first_name=db_user.first_name,
                    last_name=db_user.last_name, phone=db_user.phone or "",
                    email=db_user.email, photo_url=db_user.photo_url,
                    role=db_user.role, created_at=db_user.created_at,
                    password_hash=db_user.password_hash,
                    is_verified=db_user.is_verified or False,
                    id_document_type=db_user.id_document_type,
                    verification_status=db_user.verification_status or "none",
                    verification_reason=db_user.verification_reason,
                    status=db_user.status or "active",
                )
        except Exception as e:
            logging.error("Firestore profile sync failed: %s", e)

    return _user_dict(db_user)

# ── Photo Upload / Serve ──────────────────────────────
PHOTOS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "photos")
os.makedirs(PHOTOS_DIR, exist_ok=True)

@app.post("/auth/photo", dependencies=[Depends(_verify_api_key)])
async def upload_photo(request: Request, user: User = Depends(_get_current_user), db: AsyncSession = Depends(get_db)):
    """Upload profile photo as base64. Saves file and updates user's photo_url."""
    body = await request.json()
    photo_b64 = body.get("photo")
    if not photo_b64 or not isinstance(photo_b64, str):
        raise HTTPException(400, "Missing 'photo' field (base64)")
    # Validate and decode base64
    try:
        photo_bytes = base64.b64decode(photo_b64, validate=True)
    except Exception:
        raise HTTPException(400, "Invalid base64 data")
    # Limit decoded size to 3MB
    if len(photo_bytes) > 3 * 1024 * 1024:
        raise HTTPException(413, "Photo too large (max 3MB)")
    # Detect format from magic bytes
    ext = "jpg"
    if photo_bytes[:8] == b'\x89PNG\r\n\x1a\n':
        ext = "png"
    filename = f"user_{user.id}.{ext}"
    filepath = os.path.join(PHOTOS_DIR, filename)
    with open(filepath, "wb") as f:
        f.write(photo_bytes)
    # Update user photo_url in DB
    result = await db.execute(select(User).where(User.id == user.id))
    db_user = result.scalar_one_or_none()
    if db_user:
        db_user.photo_url = f"/photos/{filename}"
        await db.commit()
        await db.refresh(db_user)
        # Sync to Firestore
        if _HAS_FIRESTORE:
            try:
                collection = "drivers" if db_user.role == "driver" else "clients"
                firestore_sync.sync_client(
                    user_id=db_user.id, first_name=db_user.first_name,
                    last_name=db_user.last_name, phone=db_user.phone or "",
                    email=db_user.email, photo_url=db_user.photo_url,
                    role=db_user.role, created_at=db_user.created_at,
                    password_hash=db_user.password_hash,
                    is_verified=db_user.is_verified or False,
                ) if collection == "clients" else firestore_sync.sync_driver(
                    user_id=db_user.id, first_name=db_user.first_name,
                    last_name=db_user.last_name, phone=db_user.phone or "",
                    email=db_user.email, photo_url=db_user.photo_url,
                    is_online=db_user.is_online or False,
                    created_at=db_user.created_at,
                    password_hash=db_user.password_hash,
                    is_verified=db_user.is_verified or False,
                )
            except Exception as e:
                logging.error("Firestore photo sync failed: %s", e)
    return {"photo_url": f"/photos/{filename}"}

@app.get("/photos/{filename}")
async def serve_photo(filename: str):
    """Serve uploaded profile photos. Public endpoint (no auth)."""
    # Sanitize filename — prevent path traversal
    safe_name = os.path.basename(filename)
    if safe_name != filename or ".." in filename:
        raise HTTPException(400, "Invalid filename")
    filepath = os.path.join(PHOTOS_DIR, safe_name)
    if not os.path.isfile(filepath):
        raise HTTPException(404, "Photo not found")
    media = "image/jpeg" if safe_name.endswith(".jpg") else "image/png"
    return FileResponse(filepath, media_type=media)

@app.delete("/auth/me", dependencies=[Depends(_verify_api_key)])
async def delete_account(user: User = Depends(_get_current_user), db: AsyncSession = Depends(get_db)):
    """Delete (soft-delete) the current user's account."""
    result = await db.execute(select(User).where(User.id == user.id))
    db_user = result.scalar_one_or_none()
    if not db_user:
        raise HTTPException(404, "User not found")
    db_user.status = "deleted"
    await db.commit()
    # Sync deletion to Firestore
    if _HAS_FIRESTORE:
        try:
            if db_user.role == "driver":
                firestore_sync.delete_user(db_user.id, "drivers")
            else:
                firestore_sync.delete_user(db_user.id, "clients")
        except Exception as e:
            logging.error("Firestore delete sync failed: %s", e)
    return {"detail": "Account deleted"}

@app.post("/auth/verify-request", dependencies=[Depends(_verify_api_key)])
async def submit_verification(request: Request, user: User = Depends(_get_current_user), db: AsyncSession = Depends(get_db)):
    """Submit identity verification for dispatch review."""
    body = await request.json()
    result = await db.execute(select(User).where(User.id == user.id))
    db_user = result.scalar_one_or_none()
    if not db_user:
        raise HTTPException(404, "User not found")
    db_user.id_document_type = body.get("id_document_type", "id_card")
    db_user.verification_status = "pending"
    db_user.verification_reason = None
    db_user.is_verified = False
    await db.commit()
    await db.refresh(db_user)
    # Sync to Firestore so dispatch can review
    if _HAS_FIRESTORE:
        try:
            firestore_sync.sync_verification(
                user_id=db_user.id,
                first_name=db_user.first_name,
                last_name=db_user.last_name,
                email=db_user.email,
                phone=db_user.phone or "",
                id_document_type=db_user.id_document_type,
                role=db_user.role,
            )
        except Exception as e:
            logging.error("Firestore verification sync failed: %s", e)
    return _user_dict(db_user)

@app.get("/auth/verification-status", dependencies=[Depends(_verify_api_key)])
async def verification_status(user: User = Depends(_get_current_user), db: AsyncSession = Depends(get_db)):
    """Check current verification status. Also syncs from Firestore if dispatch updated it."""
    result = await db.execute(select(User).where(User.id == user.id))
    db_user = result.scalar_one_or_none()
    if not db_user:
        raise HTTPException(404, "User not found")
    # Check Firestore for dispatch updates
    if _HAS_FIRESTORE and db_user.verification_status == "pending":
        try:
            fs_status = firestore_sync.get_verification_status(db_user.id)
            if fs_status and fs_status.get("status") in ("approved", "rejected"):
                db_user.verification_status = fs_status["status"]
                db_user.verification_reason = fs_status.get("reason")
                if fs_status["status"] == "approved":
                    db_user.is_verified = True
                    if not db_user.verified_at:
                        db_user.verified_at = datetime.now(timezone.utc)
                await db.commit()
                await db.refresh(db_user)
        except Exception as e:
            logging.error("Firestore verification check failed: %s", e)
    return {
        "verification_status": db_user.verification_status or "none",
        "verification_reason": db_user.verification_reason,
        "is_verified": db_user.is_verified or False,
    }

@app.get("/auth/account-status", dependencies=[Depends(_verify_api_key)])
async def account_status(user: User = Depends(_get_current_user), db: AsyncSession = Depends(get_db)):
    """Check if account is active, blocked, or deleted (dispatch can change this via Firestore)."""
    result = await db.execute(select(User).where(User.id == user.id))
    db_user = result.scalar_one_or_none()
    if not db_user:
        raise HTTPException(404, "User not found")
    # Sync status from Firestore (dispatch may have blocked/deleted)
    if _HAS_FIRESTORE:
        try:
            collection = "drivers" if db_user.role == "driver" else "clients"
            fs_status = firestore_sync.get_account_status(db_user.id, collection)
            if fs_status and fs_status != (db_user.status or "active"):
                db_user.status = fs_status
                await db.commit()
                await db.refresh(db_user)
        except Exception as e:
            logging.error("Firestore account status check failed: %s", e)
    return {"status": db_user.status or "active"}

# ═══════════════════════════════════════════════════════
#  TRIP  ENDPOINTS
# ═══════════════════════════════════════════════════════

def _trip_dict(t: Trip) -> dict:
    return {
        "id": t.id, "rider_id": t.rider_id, "driver_id": t.driver_id,
        "pickup_address": t.pickup_address, "dropoff_address": t.dropoff_address,
        "pickup_lat": t.pickup_lat, "pickup_lng": t.pickup_lng,
        "dropoff_lat": t.dropoff_lat, "dropoff_lng": t.dropoff_lng,
        "fare": t.fare, "vehicle_type": t.vehicle_type, "status": t.status,
        "scheduled_at": t.scheduled_at.isoformat() if t.scheduled_at else None,
        "is_airport": t.is_airport or False,
        "airport_code": t.airport_code,
        "terminal": t.terminal,
        "pickup_zone": t.pickup_zone,
        "notes": t.notes,
        "created_at": t.created_at.isoformat() if t.created_at else None,
    }

@app.post("/trips", dependencies=[Depends(_verify_api_key)])
async def create_trip(body: CreateTripIn, user: User = Depends(_get_current_user), db: AsyncSession = Depends(get_db)):
    data = body.model_dump()
    # Parse scheduled_at string → datetime
    if data.get("scheduled_at") and isinstance(data["scheduled_at"], str):
        try:
            data["scheduled_at"] = datetime.fromisoformat(data["scheduled_at"].replace("Z", "+00:00"))
            data["status"] = "scheduled"
        except ValueError:
            data["scheduled_at"] = None
    trip = Trip(**data)
    db.add(trip)
    await db.commit()
    await db.refresh(trip)

    # Sync trip to Firestore for dispatch_app
    if _HAS_FIRESTORE:
        try:
            rider_result = await db.execute(select(User).where(User.id == trip.rider_id))
            rider = rider_result.scalar_one_or_none()
            firestore_sync.sync_trip(
                trip_id=trip.id, rider_id=trip.rider_id,
                rider_name=f"{rider.first_name} {rider.last_name}" if rider else "Unknown",
                rider_phone=rider.phone or "" if rider else "",
                pickup_address=trip.pickup_address, pickup_lat=trip.pickup_lat, pickup_lng=trip.pickup_lng,
                dropoff_address=trip.dropoff_address, dropoff_lat=trip.dropoff_lat, dropoff_lng=trip.dropoff_lng,
                status=trip.status, fare=trip.fare, vehicle_type=trip.vehicle_type,
                created_at=trip.created_at,
                scheduled_at=trip.scheduled_at, is_airport=trip.is_airport,
                airport_code=trip.airport_code, terminal=trip.terminal,
                pickup_zone=trip.pickup_zone, notes=trip.notes,
            )
        except Exception as e:
            logging.error("Firestore sync on create_trip failed: %s", e)

    return _trip_dict(trip)

@app.get("/trips/{trip_id}", dependencies=[Depends(_verify_api_key)])
async def get_trip(trip_id: int, user: User = Depends(_get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Trip).where(Trip.id == trip_id))
    trip = result.scalar_one_or_none()
    if not trip:
        raise HTTPException(404, "Trip not found")
    return _trip_dict(trip)

@app.get("/trips/available", dependencies=[Depends(_verify_api_key)])
async def get_available_trips(
    lat: float = Query(...), lng: float = Query(...), radius_km: float = Query(15.0),
    user: User = Depends(_get_current_user), db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Trip).where(Trip.status == "requested"))
    trips = result.scalars().all()
    nearby = []
    for t in trips:
        dist = _haversine(lat, lng, t.pickup_lat, t.pickup_lng)
        if dist <= radius_km:
            nearby.append(_trip_dict(t))
    return nearby

@app.post("/trips/{trip_id}/accept", dependencies=[Depends(_verify_api_key)])
async def accept_trip(trip_id: int, body: AcceptTripIn, user: User = Depends(_get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Trip).where(Trip.id == trip_id))
    trip = result.scalar_one_or_none()
    if not trip:
        raise HTTPException(404, "Trip not found")
    trip.driver_id = body.driver_id
    trip.status = "driver_en_route"
    await db.commit()
    await db.refresh(trip)

    # Sync to Firestore
    if _HAS_FIRESTORE:
        try:
            drv = await db.execute(select(User).where(User.id == body.driver_id))
            driver = drv.scalar_one_or_none()
            firestore_sync.sync_trip_status(
                trip_id=trip.id, status="driver_en_route",
                driver_id=body.driver_id,
                driver_name=f"{driver.first_name} {driver.last_name}" if driver else None,
                driver_phone=driver.phone if driver else None,
            )
        except Exception as e:
            logging.error("Firestore sync on accept_trip failed: %s", e)

    return _trip_dict(trip)

@app.patch("/trips/{trip_id}/status", dependencies=[Depends(_verify_api_key)])
async def update_trip_status(trip_id: int, status: str = Query(...), user: User = Depends(_get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Trip).where(Trip.id == trip_id))
    trip = result.scalar_one_or_none()
    if not trip:
        raise HTTPException(404, "Trip not found")
    trip.status = status
    trip.updated_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(trip)

    # Sync status to Firestore
    if _HAS_FIRESTORE:
        try:
            firestore_sync.sync_trip_status(trip_id=trip.id, status=status)
        except Exception as e:
            logging.error("Firestore sync on update_trip_status failed: %s", e)

    return _trip_dict(trip)

# ═══════════════════════════════════════════════════════
#  SCHEDULED / AIRPORT TRIPS
# ═══════════════════════════════════════════════════════

@app.get("/trips/scheduled/rider/{rider_id}", dependencies=[Depends(_verify_api_key)])
async def get_rider_scheduled_trips(rider_id: int, user: User = Depends(_get_current_user), db: AsyncSession = Depends(get_db)):
    """Get all scheduled (future) trips for a rider."""
    result = await db.execute(
        select(Trip).where(
            and_(Trip.rider_id == rider_id, Trip.status.in_(["scheduled", "requested"]), Trip.scheduled_at.isnot(None))
        ).order_by(Trip.scheduled_at.asc())
    )
    return [_trip_dict(t) for t in result.scalars().all()]

@app.get("/trips/scheduled/driver/{driver_id}", dependencies=[Depends(_verify_api_key)])
async def get_driver_scheduled_trips(driver_id: int, user: User = Depends(_get_current_user), db: AsyncSession = Depends(get_db)):
    """Get all scheduled trips assigned to a driver."""
    result = await db.execute(
        select(Trip).where(
            and_(Trip.driver_id == driver_id, Trip.status.in_(["scheduled", "driver_en_route"]), Trip.scheduled_at.isnot(None))
        ).order_by(Trip.scheduled_at.asc())
    )
    return [_trip_dict(t) for t in result.scalars().all()]

@app.post("/trips/{trip_id}/cancel", dependencies=[Depends(_verify_api_key)])
async def cancel_trip(trip_id: int, user: User = Depends(_get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Trip).where(Trip.id == trip_id))
    trip = result.scalar_one_or_none()
    if not trip:
        raise HTTPException(404, "Trip not found")
    if trip.status in ("completed", "canceled"):
        raise HTTPException(400, f"Cannot cancel trip with status '{trip.status}'")
    trip.status = "canceled"
    trip.updated_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(trip)
    if _HAS_FIRESTORE:
        try:
            firestore_sync.sync_trip_status(trip_id=trip.id, status="canceled")
        except Exception as e:
            logging.error("Firestore sync on cancel_trip failed: %s", e)
    return _trip_dict(trip)

# ═══════════════════════════════════════════════════════
#  DRIVER  ENDPOINTS
# ═══════════════════════════════════════════════════════

@app.patch("/drivers/{driver_id}/location", dependencies=[Depends(_verify_api_key)])
async def update_driver_location(driver_id: int, body: DriverLocationIn, user: User = Depends(_get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.id == driver_id))
    driver = result.scalar_one_or_none()
    if not driver:
        raise HTTPException(404, "Driver not found")
    driver.lat = body.lat
    driver.lng = body.lng
    driver.is_online = body.is_online
    await db.commit()

    # Sync driver location to Firestore
    if _HAS_FIRESTORE:
        try:
            firestore_sync.sync_driver_location(driver_id, body.lat, body.lng, body.is_online)
        except Exception as e:
            logging.error("Firestore sync on driver location failed: %s", e)

    return {"status": "ok", "lat": driver.lat, "lng": driver.lng, "is_online": driver.is_online}

@app.get("/riders/{rider_id}/trips", dependencies=[Depends(_verify_api_key)])
async def get_rider_trips(rider_id: int, user: User = Depends(_get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Trip).where(Trip.rider_id == rider_id).order_by(Trip.created_at.desc()))
    return [_trip_dict(t) for t in result.scalars().all()]

@app.get("/drivers/{driver_id}/trips", dependencies=[Depends(_verify_api_key)])
async def get_driver_trips(driver_id: int, user: User = Depends(_get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Trip).where(Trip.driver_id == driver_id).order_by(Trip.created_at.desc()))
    return [_trip_dict(t) for t in result.scalars().all()]

# ═══════════════════════════════════════════════════════
#  EARNINGS  ENDPOINTS
# ═══════════════════════════════════════════════════════

@app.get("/drivers/earnings", dependencies=[Depends(_verify_api_key)])
async def get_driver_earnings(period: str = Query("week"), user: User = Depends(_get_current_user), db: AsyncSession = Depends(get_db)):
    now = datetime.now(timezone.utc)
    if period == "today":
        since = now.replace(hour=0, minute=0, second=0)
    elif period == "month":
        since = now - timedelta(days=30)
    else:
        since = now - timedelta(days=7)

    result = await db.execute(
        select(Trip).where(
            and_(Trip.driver_id == user.id, Trip.status == "completed", Trip.created_at >= since)
        )
    )
    trips = result.scalars().all()
    total = sum(t.fare or 0 for t in trips)
    return {
        "total": total,
        "trips_count": len(trips),
        "online_hours": len(trips) * 0.5,
        "tips_total": 0.0,
        "daily_earnings": [0.0] * 7,
        "day_labels": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
        "transactions": [],
    }

@app.post("/drivers/cashout", dependencies=[Depends(_verify_api_key)])
async def request_cashout(body: CashoutIn, user: User = Depends(_get_current_user), db: AsyncSession = Depends(get_db)):
    cashout = Cashout(user_id=user.id, amount=body.amount)
    db.add(cashout)
    await db.commit()
    await db.refresh(cashout)
    return {"id": cashout.id, "amount": cashout.amount, "status": cashout.status}

@app.get("/drivers/cashouts", dependencies=[Depends(_verify_api_key)])
async def get_cashouts(user: User = Depends(_get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Cashout).where(Cashout.user_id == user.id).order_by(Cashout.created_at.desc()))
    return [{"id": c.id, "amount": c.amount, "status": c.status, "created_at": c.created_at.isoformat()} for c in result.scalars().all()]

@app.get("/drivers/payout-methods", dependencies=[Depends(_verify_api_key)])
async def get_payout_methods(user: User = Depends(_get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(PayoutMethod).where(PayoutMethod.user_id == user.id))
    return [{"id": p.id, "method_type": p.method_type, "display_name": p.display_name, "is_default": p.is_default} for p in result.scalars().all()]

@app.post("/drivers/payout-methods", dependencies=[Depends(_verify_api_key)])
async def add_payout_method(body: PayoutMethodIn, user: User = Depends(_get_current_user), db: AsyncSession = Depends(get_db)):
    pm = PayoutMethod(user_id=user.id, method_type=body.method_type, display_name=body.display_name, is_default=body.set_default)
    db.add(pm)
    await db.commit()
    await db.refresh(pm)
    return {"id": pm.id, "method_type": pm.method_type, "display_name": pm.display_name, "is_default": pm.is_default}

@app.delete("/drivers/payout-methods/{payout_id}", dependencies=[Depends(_verify_api_key)])
async def delete_payout_method(payout_id: int, user: User = Depends(_get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(PayoutMethod).where(PayoutMethod.id == payout_id, PayoutMethod.user_id == user.id))
    pm = result.scalar_one_or_none()
    if not pm:
        raise HTTPException(404, "Payout method not found")
    await db.delete(pm)
    await db.commit()
    return {"status": "deleted"}

# ═══════════════════════════════════════════════════════
#  PLAID  (stub)
# ═══════════════════════════════════════════════════════

@app.post("/plaid/create-link-token", dependencies=[Depends(_verify_api_key)])
async def create_plaid_link_token(user: User = Depends(_get_current_user)):
    return {"link_token": f"link-sandbox-{secrets.token_hex(16)}"}

@app.post("/plaid/exchange-token", dependencies=[Depends(_verify_api_key)])
async def exchange_plaid_token(request: Request, user: User = Depends(_get_current_user)):
    body = await request.json()
    return {"status": "ok", "account_id": body.get("account_id", "acct_stub")}

# ═══════════════════════════════════════════════════════
#  DISPATCH  ENDPOINTS
# ═══════════════════════════════════════════════════════

def _haversine(lat1, lng1, lat2, lng2):
    R = 6371
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = math.sin(dlat/2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlng/2)**2
    return R * 2 * math.asin(math.sqrt(a))

@app.post("/dispatch/request", dependencies=[Depends(_verify_api_key)])
async def dispatch_request(body: DispatchRequestIn, user: User = Depends(_get_current_user), db: AsyncSession = Depends(get_db)):
    trip = Trip(**body.model_dump())
    db.add(trip)
    await db.commit()
    await db.refresh(trip)

    # Find nearby online drivers
    result = await db.execute(
        select(User).where(
            and_(User.role == "driver", User.is_online == True, User.lat.isnot(None))
        )
    )
    drivers = result.scalars().all()
    drivers_sorted = sorted(drivers, key=lambda d: _haversine(trip.pickup_lat, trip.pickup_lng, d.lat or 0, d.lng or 0))

    # Create offer for closest driver
    if drivers_sorted:
        offer = DispatchOffer(trip_id=trip.id, driver_id=drivers_sorted[0].id)
        db.add(offer)
        await db.commit()
        await db.refresh(offer)
        return {**_trip_dict(trip), "offer_id": offer.id, "dispatched_to": drivers_sorted[0].id}

    return {**_trip_dict(trip), "offer_id": None, "dispatched_to": None}

@app.get("/dispatch/driver/pending", dependencies=[Depends(_verify_api_key)])
async def get_driver_pending(driver_id: int = Query(...), user: User = Depends(_get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(DispatchOffer, Trip)
        .join(Trip, DispatchOffer.trip_id == Trip.id)
        .where(and_(DispatchOffer.driver_id == driver_id, DispatchOffer.status == "pending"))
    )
    offers = []
    for offer, trip in result.all():
        offers.append({
            "offer_id": offer.id,
            **_trip_dict(trip),
        })
    return offers

@app.post("/dispatch/driver/accept", dependencies=[Depends(_verify_api_key)])
async def accept_offer(offer_id: int = Query(...), driver_id: int = Query(...), user: User = Depends(_get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(DispatchOffer).where(DispatchOffer.id == offer_id))
    offer = result.scalar_one_or_none()
    if not offer:
        raise HTTPException(404, "Offer not found")
    offer.status = "accepted"

    trip_result = await db.execute(select(Trip).where(Trip.id == offer.trip_id))
    trip = trip_result.scalar_one_or_none()
    if trip:
        trip.driver_id = driver_id
        trip.status = "driver_en_route"
    await db.commit()
    return {"status": "accepted", "trip": _trip_dict(trip) if trip else None}

@app.post("/dispatch/driver/reject", dependencies=[Depends(_verify_api_key)])
async def reject_offer(offer_id: int = Query(...), driver_id: int = Query(...), user: User = Depends(_get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(DispatchOffer).where(DispatchOffer.id == offer_id))
    offer = result.scalar_one_or_none()
    if not offer:
        raise HTTPException(404, "Offer not found")
    offer.status = "rejected"
    await db.commit()

    # Cascade: find next available driver
    trip_result = await db.execute(select(Trip).where(Trip.id == offer.trip_id))
    trip = trip_result.scalar_one_or_none()
    if trip and trip.status == "requested":
        rejected_ids_result = await db.execute(
            select(DispatchOffer.driver_id).where(DispatchOffer.trip_id == trip.id)
        )
        rejected_ids = {r[0] for r in rejected_ids_result.all()}
        drivers_result = await db.execute(
            select(User).where(
                and_(User.role == "driver", User.is_online == True, User.lat.isnot(None), ~User.id.in_(rejected_ids))
            )
        )
        drivers = drivers_result.scalars().all()
        drivers_sorted = sorted(drivers, key=lambda d: _haversine(trip.pickup_lat, trip.pickup_lng, d.lat or 0, d.lng or 0))
        if drivers_sorted:
            new_offer = DispatchOffer(trip_id=trip.id, driver_id=drivers_sorted[0].id)
            db.add(new_offer)
            await db.commit()

    return {"status": "rejected"}

@app.get("/dispatch/trip/status", dependencies=[Depends(_verify_api_key)])
async def get_dispatch_status(trip_id: int = Query(...), user: User = Depends(_get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Trip).where(Trip.id == trip_id))
    trip = result.scalar_one_or_none()
    if not trip:
        return {"status": "not_found"}

    offer_result = await db.execute(
        select(DispatchOffer).where(and_(DispatchOffer.trip_id == trip_id, DispatchOffer.status == "accepted"))
    )
    accepted = offer_result.scalar_one_or_none()

    if accepted:
        driver_result = await db.execute(select(User).where(User.id == accepted.driver_id))
        driver = driver_result.scalar_one_or_none()
        return {
            "status": trip.status,
            "driver": _user_dict(driver) if driver else None,
            "trip": _trip_dict(trip),
        }
    return {"status": trip.status, "driver": None, "trip": _trip_dict(trip)}

# ── Tunnel URL discovery ───────────────────────────────
_TUNNEL_URL_FILE = os.path.join(os.path.dirname(__file__), "tunnel_url.txt")

@app.get("/tunnel-url")
async def tunnel_url():
    """Return the current Cloudflare Tunnel public URL (if available)."""
    if os.path.isfile(_TUNNEL_URL_FILE):
        url = open(_TUNNEL_URL_FILE, "r").read().strip()
        if url:
            return {"tunnel_url": url}
    return {"tunnel_url": None}
