const express = require('express');
const app = express();

app.use(express.json());

// مفتاح الأمان للتحقق من الاتصال بين البوابة والخدمات المصغرة
const INTERNAL_SERVICE_SECRET = "KIURA_INTERNAL_SERVICE_KEY_2026";

// 1. نظام الإقلاع والتحقق من إصدار التطبيق (Handshake & Version Control)
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

    return res.json({
        success: true,
        status: "KIURA API Gateway is secure and operational 🚀",
        server_time: new Date().toISOString()
    });
});

// 2. تسجيل نبضات الأمان والـ IP (Security & IP Pulse Logging)
app.post('/api/core/security-pulse', (req, res) => {
    const clientIp = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
    const { device_info, user_id } = req.body;
    
    console.log(`🛡️ [SECURITY PULSE] IP: ${clientIp} | User: ${user_id || 'Guest'} | Device: ${device_info || 'Unknown'}`);
    
    return res.status(200).json({
        success: true,
        message: "Pulse recorded securely."
    });
});

// نقطة فحص الحيوية العامة للسيرفر
app.get('/health', (req, res) => {
    res.status(200).json({ status: "API Gateway is active 🔒" });
});

const PORT = process.env.PORT || 5001;
app.listen(PORT, () => {
    console.log(`🚀 KIURA API Gateway & Security Core running on port ${PORT}`);
});
