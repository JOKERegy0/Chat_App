const express = require('express');
const { Pool } = require('pg');

const app = express();
app.use(express.json());

// إجبار الاتصال على استخدام IPv4 فقط (family: 4) لتجنب عناوين IPv6 الميتة
const pool = new Pool({
    user: 'postgres',
    password: 'KIURASERVEREGYJOKERFORME2026112',
    host: 'db.dymrernfuorzmbcaaocy.supabase.co',
    database: 'postgres',
    port: 5432,
    ssl: false,
    family: 4 // ⭐ هذا هو السر لإجبار الاتصال على IPv4 حصرياً
});

pool.connect((dbErr, client, release) => {
    if (dbErr) {
        console.error('❌ خطأ في الاتصال بقاعدة البيانات:', dbErr.message);
    } else {
        console.log('🛡️ السيرفر المركزي متصل بقاعدة البيانات سحابياً بنجاح تام عبر IPv4!');
        release();
    }
});

// نقطة فحص الحيوية
app.get('/health', (req, res) => {
    res.json({ status: "Core Database Server is running securely via JS 🔒" });
});

// نقطة استقبال العمليات
app.post('/internal/execute', (req, res) => {
    res.json({
        success: true,
        message: "تم تنفيذ العملية بنجاح عبر السيرفر المركزي بـ JavaScript"
    });
});

// تشغيل السيرفر على البورت 5001
const PORT = 5001;
app.listen(PORT, () => {
    console.log(`🚀 السيرفر شغال بنجاح على البورت ${PORT}`);
});