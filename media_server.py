from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import FileResponse
import shutil
import os
import uuid

app = FastAPI(title="KIURA Media & Storage Microservice", version="1.0.0")

# مجلد تخزين الملفات محلياً (يمكن ربطه بـ AWS S3 أو تخزين سحابي لاحقاً)
UPLOAD_DIR = "storage_media"
os.makedirs(UPLOAD_DIR, exist_ok=True)

# الأنبواع المسموح بها لضمان الأمان وعدم رفع ملفات خبيثة
ALLOWED_EXTENSIONS = {"png", "jpg", "jpeg", "mp4", "mp3", "pdf", "webp"}

def verify_file_extension(filename: str) -> bool:
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS

@app.post("/api/v1/media/upload")
async def upload_media(file: UploadFile = File(...)):
    if not verify_file_extension(file.filename):
        raise HTTPException(status_code=400, detail="نوع الملف غير مدعوم لأسباب أمنية في نظام KIURA")
    
    # توليد اسم فريد للملف لمنع تداخل الأسماء
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
        "message": "تم رفع الملف ومعالجته بنجاح",
        "file_url": f"/api/v1/media/download/{unique_filename}",
        "filename": unique_filename
    }

@app.get("/api/v1/media/download/{filename}")
async def get_media(filename: str):
    file_path = os.path.join(UPLOAD_DIR, filename)
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="الملف غير موجود")
    return FileResponse(file_path)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8002)