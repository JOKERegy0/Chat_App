from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel
import jwt
import hashlib
import datetime

app = FastAPI(title="KIURA Auth & Identity Microservice", version="1.0.0")

# المفتاح السري الموحد لنواة KIURA
SECRET_KEY = "KIURA_SECURE_DEV_SIGNATURE_2026_JOKER"
ALGORITHM = "HS256"

class UserCredentials(BaseModel):
    username: str
    password: str

# قاعدة بيانات مؤقتة للذاكرة (يمكن ربطها بـ PostgreSQL أو MongoDB لاحقاً حسب الخطة)
fake_users_db = {}

@app.post("/api/v1/auth/register")
async def register(credentials: UserCredentials):
    if credentials.username in fake_users_db:
        raise HTTPException(status_code=400, detail="اسم المستخدم مسجل مسبقاً")
    
    # تشفير كلمة المرور بأمان تام
    hashed_password = hashlib.sha256(credentials.password.encode()).hexdigest()
    fake_users_db[credentials.username] = hashed_password
    
    return {
        "status": "success",
        "message": f"تم تسجيل المستخدم {credentials.username} بنجاح في نظام KIURA"
    }

@app.post("/api/v1/auth/login")
async def login(credentials: UserCredentials):
    stored_password = fake_users_db.get(credentials.username)
    hashed_input = hashlib.sha256(credentials.password.encode()).hexdigest()
    
    if not stored_password or stored_password != hashed_input:
        raise HTTPException(status_code=401, detail="بيانات الاعتماد غير صحيحة أو الحساب غير موجود")
    
    # إصدار JWT Token مشفر وموثق للجلسة
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

@app.get("/api/v1/auth/verify")
async def verify_token(token: str):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return {"status": "valid", "username": payload.get("sub")}
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="انتهت صلاحية الجلسة (Token Expired)")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="رمز المصادقة غير صالح (Invalid Token)")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)