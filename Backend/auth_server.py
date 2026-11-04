from fastapi import FastAPI, HTTPException, Header, Depends
from pydantic import BaseModel
import jwt
import hashlib
import datetime
import os
import requests

app = FastAPI(title="KIURA Secure Auth & Identity Microservice", version="1.0.0")

SECRET_KEY = "KIURA_SECURE_DEV_SIGNATURE_2026_JOKER"
ALGORITHM = "HS256"
MIN_ALLOWED_VERSION = "1.0.0+1"
INTERNAL_SERVICE_SECRET = "KIURA_INTERNAL_SERVICE_KEY_2026"
CORE_SERVER_URL = os.getenv("CORE_SERVER_URL", "https://chat-appcerver-js.onrender.com")

class UserCredentials(BaseModel):
    username: str
    password: str

# دالة التحقق الإلزامي من إصدار التطبيق لمنع النسخ القديمة
def verify_app_version(x_app_version: str = Header(default=None)):
    if not x_app_version or x_app_version != MIN_ALLOWED_VERSION:
        raise HTTPException(
            status_code=403, 
            detail="نسخة التطبيق قديمة أو غير مصرح لها. يرجى التحديث إلى أحدث إصدار آمن من KIURA."
        )
    return x_app_version

@app.post("/api/v1/auth/register")
async def register(credentials: UserCredentials, app_version: str = Depends(verify_app_version)):
    hashed_password = hashlib.sha256(credentials.password.encode()).hexdigest()
    
    payload = {
        "username": credentials.username,
        "hashed_password": hashed_password
    }
    headers = {
        "Content-Type": "application/json",
        "x-service-secret": INTERNAL_SERVICE_SECRET
    }
    
    try:
        response = requests.post(f"{CORE_SERVER_URL}/api/core/register-user", json=payload, headers=headers)
        res_data = response.json()
        
        if not response.ok or not res_data.get("success"):
            raise HTTPException(status_code=response.status_code, detail=res_data.get("error", "فشل التسجيل"))
            
        return {
            "status": "success",
            "message": f"تم تسجيل المستخدم {credentials.username} بنجاح في نظام KIURA الآمن عبر النواة"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"خطأ في الاتصال بالسيرفر الرئيسي: {str(e)}")

@app.post("/api/v1/auth/login")
async def login(credentials: UserCredentials, app_version: str = Depends(verify_app_version)):
    hashed_input = hashlib.sha256(credentials.password.encode()).hexdigest()
    
    headers = {
        "Content-Type": "application/json",
        "x-service-secret": INTERNAL_SERVICE_SECRET
    }
    
    try:
        response = requests.post(f"{CORE_SERVER_URL}/api/core/verify-user", json={"username": credentials.username}, headers=headers)
        res_data = response.json()
        
        if not response.ok or not res_data.get("success"):
            raise HTTPException(status_code=401, detail="بيانات الاعتماد غير صحيحة أو الحساب غير موجود")
            
        db_user = res_data.get("user")
        if db_user["password_hash"] != hashed_input:
            raise HTTPException(status_code=401, detail="كلمة المرور غير صحيحة")
        
        expiration = datetime.datetime.utcnow() + datetime.timedelta(days=7)
        token_payload = {
            "sub": credentials.username,
            "exp": expiration
        }
        jwt_token = jwt.encode(token_payload, SECRET_KEY, algorithm=ALGORITHM)
        
        return {
            "status": "success",
            "access_token": jwt_token,
            "token_type": "bearer",
            "expires_in": "7 days"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"خطأ أثناء عملية تسجيل الدخول: {str(e)}")

@app.get("/health")
async def health_check():
    return {"status": "ONLINE", "service": "KIURA Auth Microservice (Python)"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
