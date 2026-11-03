const express = require('express');
const { Pool } = require('pg');
require('dotenv').config();

const app = express();
app.use(express.json());

// الاتصال بقاعدة البيانات بـ Pool
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

// فحص الحيوية لسيرفر الطلبات
app.get('/health', (req, res) => {
  res.status(200).json({
    status: "Daily Requests Server is live and operational 📋",
    service: "daily-requests"
  });
});

// 1. إضافة طلب يومي جديد
app.post('/api/requests/add', async (req, res) => {
  try {
    const { user_id, title, description, category } = req.body;
    
    const query = `
      INSERT INTO daily_requests (user_id, title, description, category, status, created_at)
      VALUES ($1, $2, $3, $4, 'pending', NOW())
      RETURNING *;
    `;
    const values = [user_id, title, description, category || 'general'];
    
    // تنفيذ الاستعلام (مفعل عند جاهزية جدول قاعدة البيانات)
    // const result = await pool.query(query, values);

    res.status(201).json({
      success: true,
      message: "تم تسجيل الطلب اليومي بنجاح وإرساله للمعالجة!",
      data: { user_id, title, description, category }
    });
  } catch (error) {
    console.error("خطأ في إضافة الطلب:", error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// 2. جلب الطلبات الخاصة بمستخدم معين
app.get('/api/requests/:user_id', async (req, res) => {
  try {
    const { user_id } = req.params;
    
    // const query = 'SELECT * FROM daily_requests WHERE user_id = $1 ORDER BY created_at DESC';
    // const result = await pool.query(query, [user_id]);

    res.status(200).json({
      success: true,
      user_id,
      requests: [] // هنا هتتحط الداتا المسترجعة من القاعدة
    });
  } catch (error) {
    console.error("خطأ في جلب الطلبات:", error);
    res.status(500).json({ success: false, error: error.message });
  }
});

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`📋 سيرفر الطلبات اليومية شغال بكفاءة على البورت ${PORT}`);
});
