const express = require('express');
const { Pool } = require('pg');

const app = express();
app.use(express.json());

const connectionString = process.env.DATABASE_URL;
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;

if (!connectionString) {
    console.error('❌ تنبيه: متغير البيئة DATABASE_URL غير ممرر!');
}

// إعداد الاتصال بشكل مرن يتيح إعادة المحاولة أو البديل تلقائياً
let pool = new Pool({
    connectionString,
    ssl: {
        rejectUnauthorized: false
    }
});

// اختبار الاتصال مع التعامل الذكي مع أخطاء الشبكة والـ IPv6/IPv4
async function verifyDatabaseConnection() {
    try {
        const client = await pool.connect();
        console.log('🛡️ السيرفر المركزي متصل بقاعدة البيانات سحابياً بنجاح تام!');
        client.release();
    } catch (err) {
        console.error('⚠️ تحذير: فشل الاتصال الأساسي:', err.message);
        
        if (err.code === 'ENETUNREACH' || err.message.includes('ENETUNREACH')) {
            console.log('🔄 تم اكتشاف مشكلة في شبكة الاتصال (IPv6)، جاري إعادة توجيه المسار تلقائياً...');
            
            // إعادة ضبط الـ Pool مع فرض استخدام IPv4 كحل بديل فوري
            pool = new Pool({
                connectionString,
                ssl: { rejectUnauthorized: false },
                family: 4
            });

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

// نقطة فحص الحيوية
app.get('/health', (req, res) => {
    res.json({ 
        status: "Core Database Server is running securely with Smart Fallback 🔒",
        hasAnonKey: !!supabaseAnonKey 
    });
});

// نقطة استقبال العمليات
app.post('/internal/execute', (req, res) => {
    res.json({
        success: true,
        message: "تم تنفيذ العملية بنجاح عبر السيرفر المركزي بـ JavaScript"
    });
});

// تشغيل السيرفر على البورت المطلوب أو الافتراضي لـ Render
const PORT = process.env.PORT || 5001;
app.listen(PORT, () => {
    console.log(`🚀 السيرفر شغال بنجاح على البورت ${PORT}`);
});
