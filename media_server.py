from fastapi import FastAPI, File, UploadFile, HTTPException, Header, Depends
from fastapi.responses import FileResponse
import jwt
import shutil
import os
import uuid

app = FastAPI(title="KIURA Secure Media & Storage Microservice", version="1.0.0")

UPLOAD_DIR = "storage_media"
os.makedirs(UPLOAD_DIR, exist_ok=True)

SECRET_KEY = "KIURA_SECURE_DEV_SIGNATURE_2026_JOKER"
ALGORITHM = "HS256"
ALLOWED_EXTENSIONS = {"png", "jpg", "jpeg", "mp4", "mp3", "pdf", "webp"}

def verify_jwt_token(authorization: str = Header(default=None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="مطلوب رمز مصادقة صحيح للوصول لسيرفر الوسائط")
    
    token = authorization.split(" ")[1]
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload.get("sub")
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="انتهت صلاحية الجلسة")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="رمز المصادقة غير صالح")

def verify_file_extension(filename: str) -> bool:
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS

@app.post("/api/v1/media/upload")
async def upload_media(file: UploadFile = File(...), current_user: str = Depends(verify_jwt_token)):
    if not verify_file_extension(file.filename):
        raise HTTPException(status_code=400, detail="نوع الملف غير مدعوم لأسباب أمنية في نظام KIURA")
    
    file_extension = file.filename.rsplit(".", 1)[1].lower()
    unique_filename = f"{uuid.uuid4()}.{file_extension}"
    file_path = os.path.join(UPLOAD_DIR, unique_filename)
    
    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"فشل حفظ الملف: {str(e)}")
    
    return {
        "status": "success",
        "uploader": current_user,
        "message": "تم رفع الملف ومعالجته بأمان تام",
        "file_url": f"/api/v1/media/download/{unique_filename}",
        "filename": unique_filename
    }

@app.get("/api/v1/media/download/{filename}")
async def get_media(filename: str, current_user: str = Depends(verify_jwt_token)):
    file_path = os.path.join(UPLOAD_DIR, filename)
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="الملف غير موجود")
    return FileResponse(file_path)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8002)
