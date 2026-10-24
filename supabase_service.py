import os
from supabase import create_client, Client
from fastapi import UploadFile, HTTPException
import uuid

# بيانات الاتصال بمشروع Supabase (تأخذهم من لوحة التحكم مجاناً)
SUPABASE_URL = "https://your-supabase-project.supabase.co"
SUPABASE_KEY = "your-supabase-anon-or-service-role-key"

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

class SupabaseCloudManager:
    @staticmethod
    async def upload_media_to_cloud(file: UploadFile, bucket_name: str = "kiura-media") -> str:
        """
        رفع الصور، الفيديوهات، والصوتيات الخاصة بالحالات والملف الشخصي للسحابة
        """
        try:
            file_extension = file.filename.rsplit(".", 1)[1].lower()
            unique_filename = f"{uuid.uuid4()}.{file_extension}"
            
            # قراءة محتوى الملف
            file_bytes = await file.read()
            
            # رفع الملف إلى Supabase Storage Bucket
            response = supabase.storage.from_(bucket_name).upload(
                path=unique_filename,
                file=file_bytes,
                file_options={"content_type": file.content_type}
            )
            
            if response.get("error"):
                raise HTTPException(status_code=500, detail=f"فشل الرفع للسحابة: {response['error']['message']}")
            
            # جلب الرابط العام للملف (Public URL)
            public_url_response = supabase.storage.from_(bucket_name).get_public_url(unique_filename)
            return public_url_response
            
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"خطأ غير متوقع أثناء رفع الوسائط: {str(e)}")

    @staticmethod
    def save_user_status_to_db(user_id: str, media_url: str, expires_at: str):
        """
        حفظ بيانات الحالة (Story) في جدول Statuses داخل PostgreSQL
        """
        data = {
            "user_id": user_id,
            "media_url": media_url,
            "expires_at": expires_at
        }
        response = supabase.table("Statuses").insert(data).execute()
        return response