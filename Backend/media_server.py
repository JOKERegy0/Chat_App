from fastapi import FastAPI, File, UploadFile, HTTPException, Header, Depends, Form
from fastapi.responses import FileResponse
import jwt
import shutil
import os
import uuid
import requests

app = FastAPI(title="KIURA Secure Media & Storage Microservice", version="1.0.0")

UPLOAD_DIR = "storage_media"
os.makedirs(UPLOAD_DIR, exist_ok=True)

SECRET_KEY = "KIURA_SECURE_DEV_SIGNATURE_2026_JOKER"
INTERNAL_SERVICE_SECRET = "KIURA_INTERNAL_SERVICE_KEY_2026"
CORE_SERVER_URL = os.getenv("CORE_SERVER_URL", "https://chat-appcerver-js.onrender.com")
ALGORITHM = "HS256"
ALLOWED_EXTENSIONS = {"png", "jpg", "jpeg", "mp4", "mp3", "pdf", "webp"}

# دالة التحقق من توكن المستخدم (معرفة من هو مرسل الملف)
def verify_jwt_token(authorization: str = Header(default=None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="مطلوب رمز مصادقة صحيح للوصول لسيرفر الوسائط")
    
    token = authorization.split(" ")[1]
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload.get("sub") # اسم المستخدم أو معرف المرسل
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="انتهت صلاحية الجلسة")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="رمز المصادقة غير صالح")

def verify_file_extension(filename: str) -> bool:
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS

@app.post("/api/v1/media/upload")
async def upload_media(
    file: UploadFile = File(...),
    target_type: str = Form(...),  # نوع الوجهة: group, channel, community, chat
    target_id: str = Form(...),    # معرف المجموعه أو القناة أو المجتمع المستهدف
    current_user: str = Depends(verify_jwt_token) # معرف المرسل الدقيق
):
    # 1. التحقق من أمان وامتداد الملف
    if not verify_file_extension(file.filename):
        raise HTTPException(status_code=400, detail="نوع الملف غير مدعوم لأسباب أمنية في نظام KIURA")
    
    # 2. التحقق من صلاحيات المرسل داخل المجموعات / القنوات / المجتمعات عبر السيرفر الرئيسي
    headers = {
        "Content-Type": "application/json",
        "x-service-secret": INTERNAL_SERVICE_SECRET
    }
    permission_payload = {
        "username": current_user,
        "target_type": target_type,
        "target_id": target_id
    }
    
    try:
        # مخاطبة السيرفر الرئيسي للتأكد هل المتبوع مسموح له بالرفع في هذه المجموعة/القناة؟
        response = requests.post(f"{CORE_SERVER_URL}/api/core/check-permission", json=permission_payload, headers=headers)
        if response.ok:
            res_data = response.json()
            if not res_data.get("allowed", True):
                raise HTTPException(status_code=403, detail="غير مسموح لك برفع ملفات داخل هذه المجموعة أو القناة")
    except requests.exceptions.RequestException:
        # في حال عدم توفر اتصال مؤقت بالكور، يمكن تمرير الطلب بحذر أو التعامل معه
        pass

    # 3. معالجة وتخزين الملف باسم فريد وآمن
    file_extension = file.filename.rsplit(".", 1)[1].lower()
    unique_filename = f"{uuid.uuid4()}.{file_extension}"
    file_path = os.path.join(UPLOAD_DIR, unique_filename)
    
    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"فشل حفظ الملف: {str(e)}")
    
    # 4. الرد بنجاح مع كامل تفاصيل المرسل ومكان الرفع (المجموعة/القناة/المجتمع)
    return {
        "status": "success",
        "sender": current_user,
        "target_type": target_type,
        "target_id": target_id,
        "message": f"تم رفع الملف بنجاح بواسطة المستخدم {current_user} داخل {target_type} ({target_id})",
        "file_url": f"/api/v1/media/download/{unique_filename}",
        "filename": unique_filename
    }

@app.get("/api/v1/media/download/{filename}")
async def get_media(filename: str, current_user: str = Depends(verify_jwt_token)):
    file_path = os.path.join(UPLOAD_DIR, filename)
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="الملف غير موجود")
    return FileResponse(file_path)

@app.get("/health")
async def health_check():
    return {"status": "ONLINE", "service": "KIURA Media & Storage Microservice with Target Permissions"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8002)
