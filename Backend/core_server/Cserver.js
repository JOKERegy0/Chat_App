const express = require('express');
const { Pool } = require('pg');

const app = express();
app.use(express.json());

const connectionString = process.env.DATABASE_URL;
const SECRET_KEY = "KIURA_SECURE_DEV_SIGNATURE_2026_JOKER";
const INTERNAL_SERVICE_SECRET = "KIURA_INTERNAL_SERVICE_KEY_2026"; // مفتاح تواصل الخدمات الفرعية الآمن

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
            console.log('🔄 تم اكتشاف مشكلة في شبكة الاتصال (IPv6)، جاري إعادة توجيه المسار تلقائياً...');
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
function verifyInternalService(req, res, next) {
    const serviceSecret = req.headers['x-service-secret'];
    if (!serviceSecret || serviceSecret !== INTERNAL_SERVICE_SECRET) {
        return res.status(403).json({ success: false, error: "Access Denied: مصدر غير مصرح له بالتواصل المباشر" });
    }
    next();
}

// نقطة فحص الإقلاع للتطبيق (App Handshake)
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

// استقبال وحفظ الطلبات اليومية
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

// تسجيل مستخدم جديد (يُستدعى من سيرفر المصادقة)
app.post('/api/core/register-user', verifyInternalService, async (req, res) => {
    try {
        const { username, hashed_password } = req.body;
        
        const checkUser = await pool.query('SELECT * FROM users WHERE username = $1', [username]);
        if (checkUser.rows.length > 0) {
            return res.status(400).json({ success: false, error: "اسم المستخدم مسجل مسبقاً" });
        }

        const insertQuery = `
            INSERT INTO users (username, password_hash, created_at)
            VALUES ($1, $2, NOW())
            RETURNING id, username, created_at;
        `;
        const result = await pool.query(insertQuery, [username, hashed_password]);

        res.status(201).json({
            success: true,
            message: "تم تسجيل المستخدم بنجاح في قاعدة البيانات المركزية",
            user: result.rows[0]
        });
    } catch (error) {
        console.error("خطأ في تسجيل المستخدم:", error);
        res.status(500).json({ success: false, error: error.message });
    }
});

// التحقق من بيانات المستخدم (يُستدعى من سيرفر المصادقة)
app.post('/api/core/verify-user', verifyInternalService, async (req, res) => {
    try {
        const { username } = req.body;
        const userQuery = await pool.query('SELECT * FROM users WHERE username = $1', [username]);
        
        if (userQuery.rows.length === 0) {
            return res.status(404).json({ success: false, error: "المستخدم غير موجود" });
        }

        res.status(200).json({
            success: true,
            user: userQuery.rows[0]
        });
    } catch (error) {
        console.error("خطأ في التحقق من المستخدم:", error);
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
