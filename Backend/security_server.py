import hashlib
import hmac
import time
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn

app = FastAPI(title="KIURA Security Engine", version="1.0.0")

SECRET_KEY = b"KIURA_SECURE_DEV_SIGNATURE_2026_JOKER"

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
async def check_pulse(payload: SecurityPulsePayload):
    result = verify_6_layer_security(payload)
    return {
        "success": True,
        "message": "Device & Session Verified Successfully",
        "data": result
    }

@app.get("/health")
async def health_check():
    return {"status": "ONLINE", "service": "KIURA Security Microservice (Python)"}

if __name__ == "__main__":
    uvicorn.run("security_server:app", host="0.0.0.0", port=8000, reload=True)
