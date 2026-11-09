const express = require('express');
const axios = require('axios');
const app = express();

app.use(express.json());

// 🌐 عناوين السيرفرات الداخلية (تأخذ من متغيرات البيئة أو الـ Fallback محلياً)
const INTERNAL_AUTH_SERVER = process.env.INTERNAL_AUTH_SERVER || 'http://localhost:5001';
const INTERNAL_CHAT_SERVER = process.env.INTERNAL_CHAT_SERVER || 'http://localhost:5002';         // سيرفر المراسلة
const INTERNAL_SECURITY_SERVER = process.env.INTERNAL_SECURITY_SERVER || 'http://localhost:5003'; // سيرفر الأمان
const INTERNAL_MEDIA_SERVER = process.env.INTERNAL_MEDIA_SERVER || 'http://localhost:5004';       // سيرفر الوسائط والملف
const INTERNAL_DAILY_SERVER = process.env.INTERNAL_DAILY_SERVER || 'http://localhost:5005';       // سيرفر الطلبات اليومية

// 🔑 مفتاح الأمان الموحد والمتفق عليه للخدمات الداخلية
const INTERNAL_SERVICE_SECRET = process.env.INTERNAL_SERVICE_SECRET || "KIURA_INTERNAL_SERVICE_KEY_2026";

// 🛡️ Middleware عام لسحب وتتبع آيبي الجهاز لكل الطلبات الواردة
app.use((req, res, next) => {
    const clientIp = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
    req.clientIp = clientIp;
    
    console.log(`🌐 [Node DMZ Traffic] IP: ${clientIp} | Method: ${req.method} | Path: ${req.path}`);
    next();
});

// 1. 🚀 هاندشيك الإقلاع وفحص الجهاز
app.post('/api/core/handshake', (req, res) => {
    try {
        const { deviceId, appVersion, securityKey } = req.body;
        const clientIp = req.clientIp;

        if (!securityKey || securityKey !== INTERNAL_SERVICE_SECRET) {
            console.warn(`🚨 Unauthorized Handshake Attempt from IP: ${clientIp}`);
            return res.status(403).json({
                status: "Rejected",
                error: "Invalid Security Key or Device Handshake Failed ❌"
            });
        }

        console.log(`✅ Handshake Passed for Device ID: ${deviceId} from IP: ${clientIp}`);
        
        return res.status(200).json({
            status: "Success",
            message: "Secure DMZ Handshake Passed 🛡️",
            gateway: "Cserver.js (Node.js DMZ)",
            assignedIp: clientIp,
            sessionToken: "kiura_secure_token_" + Date.now()
        });
    } catch (error) {
        res.status(500).json({ error: "Handshake Processing Error", details: error.message });
    }
});

// 2. 💓 نبضة الأمان المستمرة (Heartbeat)
app.post('/api/core/pulse', (req, res) => {
    const { deviceToken } = req.body;
    const clientIp = req.clientIp;

    if (!deviceToken) {
        return res.status(401).json({ status: "Dead", error: "Pulse Rejected: No Token Provided" });
    }

    return res.status(200).json({
        status: "Alive",
        pulseCheck: "Secure",
        serverTime: new Date().toISOString(),
        clientIp: clientIp
    });
});

// 3. 🔄 توجيه طلبات المصادقة (Auth)
app.all('/api/auth/*', async (req, res) => {
    try {
        const targetUrl = `${INTERNAL_AUTH_SERVER}${req.originalUrl}`;
        const response = await axios({
            method: req.method,
            url: targetUrl,
            data: req.body,
            headers: { ...req.headers, 'x-client-ip': req.clientIp, 'x-forwarded-by': 'kiura-node-dmz' }
        });
        res.status(response.status).json(response.data);
    } catch (error) {
        res.status(error.response?.status || 500).json({ error: "Auth Gateway Routing Error", details: error.message });
    }
});

// 4. 💬 توجيه طلبات المراسلة والشات (Chat)
app.all('/api/chat/*', async (req, res) => {
    try {
        const targetUrl = `${INTERNAL_CHAT_SERVER}${req.originalUrl}`;
        const response = await axios({
            method: req.method,
            url: targetUrl,
            data: req.body,
            headers: { ...req.headers, 'x-client-ip': req.clientIp, 'x-forwarded-by': 'kiura-node-dmz' }
        });
        res.status(response.status).json(response.data);
    } catch (error) {
        res.status(error.response?.status || 500).json({ error: "Chat Gateway Routing Error" });
    }
});

// 5. 🔒 توجيه طلبات الحماية (Security)
app.all('/api/security/*', async (req, res) => {
    try {
        const targetUrl = `${INTERNAL_SECURITY_SERVER}${req.originalUrl}`;
        const response = await axios({
            method: req.method,
            url: targetUrl,
            data: req.body,
            headers: { ...req.headers, 'x-client-ip': req.clientIp, 'x-forwarded-by': 'kiura-node-dmz' }
        });
        res.status(response.status).json(response.data);
    } catch (error) {
        res.status(error.response?.status || 500).json({ error: "Security Gateway Routing Error" });
    }
});

// 6. 📁 توجيه طلبات الوسائط والملفات (Media)
app.all('/api/media/*', async (req, res) => {
    try {
        const targetUrl = `${INTERNAL_MEDIA_SERVER}${req.originalUrl}`;
        const response = await axios({
            method: req.method,
            url: targetUrl,
            data: req.body,
            headers: { ...req.headers, 'x-client-ip': req.clientIp, 'x-forwarded-by': 'kiura-node-dmz' }
        });
        res.status(response.status).json(response.data);
    } catch (error) {
        res.status(error.response?.status || 500).json({ error: "Media Gateway Routing Error" });
    }
});

// 7. 📅 توجيه الطلبات والمهام اليومية (Daily Requests)
app.all('/api/daily/*', async (req, res) => {
    try {
        const targetUrl = `${INTERNAL_DAILY_SERVER}${req.originalUrl}`;
        const response = await axios({
            method: req.method,
            url: targetUrl,
            data: req.body,
            headers: { ...req.headers, 'x-client-ip': req.clientIp, 'x-forwarded-by': 'kiura-node-dmz' }
        });
        res.status(response.status).json(response.data);
    } catch (error) {
        res.status(error.response?.status || 500).json({ error: "Daily Gateway Routing Error" });
    }
});

// تشغيل البوابة
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🛡️ Cserver.js (Node.js Comprehensive DMZ Gateway) is active on port ${PORT}`);
});
