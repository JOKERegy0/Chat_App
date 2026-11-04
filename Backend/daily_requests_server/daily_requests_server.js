const express = require('express');
require('dotenv').config();

const app = express();
app.use(express.json());

// جلب الروابط ومفاتيح الأمان من متغيرات البيئة على Render
const CORE_SERVER_URL = process.env.CORE_SERVER_URL || 'https://chat-appcerver-js.onrender.com';
const INTERNAL_SERVICE_SECRET = "KIURA_INTERNAL_SERVICE_KEY_2026"; // لازم يكون مطابق للمفتاح في السيرفر الرئيسي

// فحص الحيوية
app.get('/health', (req, res) => {
  res.status(200).json({
    status: "Daily Requests Server is live and securely connected to Core 📋",
    service: "daily-requests"
  });
});

// 1. استقبال الطلب من تطبيق الموبايل وتمريره بذكاء للسيرفر الرئيسي
app.post('/api/requests/add', async (req, res) => {
  try {
    const { user_id, title, description, category } = req.body;
    
    // التحقق السريع من البيانات قبل الإرسال
    if (!user_id || !title) {
      return res.status(400).json({ 
        success: false, 
        error: "بيانات الطلب ناقصة: يجب توفير معرف المستخدم والعنوان" 
      });
    }

    // إرسال الطلب للسيرفر الرئيسي مع تمرير مفتاح المصادقة الداخلي (Service Secret)
    const coreResponse = await fetch(`${CORE_SERVER_URL}/api/core/save-request`, {
      method: 'POST',
      headers: { 
        'Content-Type': 'application/json',
        'x-service-secret': INTERNAL_SERVICE_SECRET // مفتاح الحراسة للتعارف الذكي
      },
      body: JSON.stringify({ user_id, title, description, category })
    });

    const coreData = await coreResponse.json();

    if (coreResponse.ok && coreData.success) {
      return res.status(201).json({
        success: true,
        message: "تم حفظ الطلب بنجاح عبر السيرفر الرئيسي",
        data: coreData.data
      });
    } else {
      return res.status(400).json({
        success: false,
        error: coreData.error || "فشل السيرفر الرئيسي في معالجة الطلب"
      });
    }

  } catch (error) {
    console.error("خطأ في الاتصال بالسيرفر الرئيسي:", error);
    res.status(500).json({ 
      success: false, 
      error: "خطأ في الشبكة بين الخدمات" 
    });
  }
});

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`📋 سيرفر الطلبات اليومية شغال ومرتبط بالكور بذكاء على البورت ${PORT}`);
});
