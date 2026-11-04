const express = require('express');
const { Pool } = require('pg');
const jwt = require('jsonwebtoken');

const app = express();
app.use(express.json());

const connectionString = process.env.DATABASE_URL;
const SECRET_KEY = "KIURA_SECURE_DEV_SIGNATURE_2026_JOKER";
const INTERNAL_SERVICE_SECRET = "KIURA_INTERNAL_SERVICE_KEY_2026"; // مفتاح تواصل الخدمات الفرعية

if (!connectionString) {
    console.error('❌ تنبيه: متغير البيئة DATABASE_URL غير ممرر!');
}

// إعداد الاتصال مع دعم IPv4/IPv4 Fallback الذكي
let pool = new Pool({
    connectionString,
    ssl: { rejectUnauthorized: false }
});

async function verifyDatabaseConnection() {
    try {
        const client = await pool.connect();
        console.log('🛡️ السيرفر المركزي متصل بقاعدة البيانات سحابياً بنجاح تام!');
        client.release();
    } catch (err) {
        console.error('⚠️ تحذير: فشل الاتصال الأساسي:', err.message);
        if (err.code === 'ENETUNREACH' || err.message.includes('ENETUNREACH')) {
            pool = new Pool({ connectionString, ssl: { rejectUnauthorized: false }, family: 4 });
            try {
                const fallbackClient = await pool.connect();
                console.log('✅ تم تفعيل المسار البديل (IPv4) والاتصال بنجاح تام!');
                fallbackClient.release();
            } catch (fallbackErr) {
                console.error('❌ فشل المسار البديل أيضاً:', fallbackErr.message);
            }
        }
    }
}

verifyDatabaseConnection();

// ==========================================
// 🛡️ نظام الحراسة والتعرف الذكي (Middleware)
// ==========================================

// 1. التحقق من أن الطلب جاي من سيرفر فرعي موثوق
function verifyInternalService(req, res, next) {
    const serviceSecret = req.headers['x-service-secret'];
    if (!serviceSecret || serviceSecret !== INTERNAL_SERVICE_SECRET) {
        return res.status(403).json({ success: false, error: "Access Denied: مصدر غير مصرح له بالتواصل المباشر" });
    }
    next();
}

// 2. نقطة فحص الإقلاع للتطبيق (App Handshake)
app.get('/api/core/handshake', (req, res) => {
    const clientVersion = req.headers['x-app-version'];
    const MIN_ALLOWED_VERSION = '1.0.0+1';

    if (!clientVersion || clientVersion !== MIN_ALLOWED_VERSION) {
        return res.status(403).json({
            success: false,
            force_update: true,
            message: "نسخة التطبيق قديمة. يرجى التحديث إلى أحدث إصدار آمن من KIURA."
        });
    }

    res.json({
        success: true,
        status: "System is secure and fully operational 🚀",
        server_time: Date.now()
    });
});

// 3. مسار استقبال الطلبات من "سيرفر الطلبات اليومية" والتعامل معها بذكاء
app.post('/api/core/save-request', verifyInternalService, async (req, res) => {
    try {
        const { user_id, title, description, category } = req.body;
        
        if (!user_id || !title) {
            return res.status(400).json({ success: false, error: "بيانات الطلب غير مكتملة" });
        }

        const query = `
            INSERT INTO daily_requests (user_id, title, description, category, status, created_at)
            VALUES ($1, $2, $3, $4, 'pending', NOW())
            RETURNING *;
        `;
        const values = [user_id, title, description, category || 'general'];
        
        const result = await pool.query(query, values);

        res.status(201).json({
            success: true,
            message: "تم حفظ الطلب في قاعدة البيانات بنجاح بواسطة السيرفر المركزي",
            data: result.rows[0]
        });

    } catch (error) {
        console.error("خطأ في قاعدة البيانات:", error);
        res.status(500).json({ success: false, error: error.message });
    }
});

// نقطة فحص الحيوية
app.get('/health', (req, res) => {
    res.json({ status: "Core Database Server is running with Smart Recognition 🔒" });
});

const PORT = process.env.PORT || 5001;
app.listen(PORT, () => {
    console.log(`🚀 السيرفر المركزي شغال بنجاح على البورت ${PORT}`);
});
