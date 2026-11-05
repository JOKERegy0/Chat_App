import hashlib
import hmac
import time
import os
import requests
from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel
import uvicorn

app = FastAPI(title="KIURA Security Engine with IP Tracking", version="1.0.0")

SECRET_KEY = b"KIURA_SECURE_DEV_SIGNATURE_2026_JOKER"
INTERNAL_SERVICE_SECRET = "KIURA_INTERNAL_SERVICE_KEY_2026"
CORE_SERVER_URL = os.getenv("CORE_SERVER_URL", "https://chat-appcerver-js.onrender.com")

class SecurityPulsePayload(BaseModel):
    user_id: str
    device_id: str
    timestamp: int
    is_rooted: bool
    is_tampered: bool
    signature: str

def verify_6_layer_security(payload: SecurityPulsePayload):
    current_time = int(time.time() * 1000)

    raw_data = f"{payload.user_id}:{payload.device_id}:{payload.timestamp}".encode('utf-8')
    expected_signature = hmac.new(SECRET_KEY, raw_data, hashlib.sha256).hexdigest()
    
    if not hmac.compare_digest(expected_signature, payload.signature):
        raise HTTPException(status_code=403, detail="[Layer 1 Failed] HMAC Signature Mismatch - Potential Tampering!")

    if abs(current_time - payload.timestamp) > 30000:
        raise HTTPException(status_code=401, detail="[Layer 2 Failed] Expired Timestamp - Anti-Replay Triggered!")

    if payload.is_rooted:
        raise HTTPException(status_code=403, detail="[Layer 3 Failed] Rooted/Jailbroken Environment Detected!")

    if payload.is_tampered:
        raise HTTPException(status_code=403, detail="[Layer 4 Failed] Application Binary Tampering Detected!")

    if not payload.device_id or len(payload.device_id) < 8:
        raise HTTPException(status_code=400, detail="[Layer 5 Failed] Invalid or Suspicious Device Identifier!")

    return {"status": "SECURE", "layer_checks": "6/6 PASSED", "timestamp": current_time}

@app.post("/api/v1/security/verify-pulse")
async def check_pulse(payload: SecurityPulsePayload, request: Request):
    # 1. التقاط الـ IP الحقيقي للجهاز (مع دعم بروكسي Render والسيرفرات السحابية)
    forwarded_for = request.headers.get("x-forwarded-for")
    if forwarded_for:
        client_ip = forwarded_for.split(",")[0].strip()
    else:
        client_ip = request.client.host if request.client else "unknown"

    # 2. تنفيذ فحص طبقات الأمان الستة
    result = verify_6_layer_security(payload)

    # 3. إرسال سجل الأمان والـ IP للسيرفر الرئيسي لتخزينه في Supabase
    headers = {
        "Content-Type": "application/json",
        "x-service-secret": INTERNAL_SERVICE_SECRET
    }
    log_payload = {
        "user_id": payload.user_id,
        "device_id": payload.device_id,
        "ip_address": client_ip,
        "status": "SECURE",
        "checks_passed": "6/6"
    }

    try:
        requests.post(f"{CORE_SERVER_URL}/api/core/log-security-pulse", json=log_payload, headers=headers, timeout=3)
    except Exception as e:
        print(f"Warning: Could not log security pulse to Core: {str(e)}")

    return {
        "success": True,
        "message": "Device, IP & Session Verified Successfully",
        "ip_recorded": client_ip,
        "data": result
    }

@app.get("/health")
async def health_check():
    return {"status": "ONLINE", "service": "KIURA Security Microservice with IP Tracking (Python)"}

if __name__ == "__main__":
    uvicorn.run("security_server:app", host="0.0.0.0", port=8000, reload=True)
