const express = require('express');
const axios = require('axios');
const app = express();

app.use(express.json());

// عناوين السيرفرات الداخلية (تأخذ من متغيرات البيئة أو الـ Fallback محلياً)
const INTERNAL_AUTH_SERVER = process.env.INTERNAL_AUTH_SERVER || 'http://localhost:5001';
const INTERNAL_CHAT_SERVER = process.env.INTERNAL_CHAT_SERVER || 'http://localhost:5002'; // خاص بـ server.js للمراسلة
const INTERNAL_SECURITY_SERVER = process.env.INTERNAL_SECURITY_SERVER || 'http://localhost:5003'; // خاص بـ security_server.py

// مفتاح الأمان الموحد والمتفق عليه للخدمات الداخلية
const INTERNAL_SERVICE_SECRET = process.env.INTERNAL_SERVICE_SECRET || "KIURA_INTERNAL_SERVICE_KEY_2026";

// 🛡️ Middleware عام لسحب وتتبع آيبي الجهاز لكل الطلبات الواردة
app.use((req, res, next) => {
    const clientIp = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
    req.clientIp = clientIp;
    
    console.log(`🌐 [DMZ Traffic] IP: ${clientIp} | Method: ${req.method} | Path: ${req.path}`);
    next();
});

// 1. 🚀 هاندشيك الإقلاع (Startup Handshake & Device Check)
app.post('/api/core/handshake', (req, res) => {
    try {
        const { deviceId, appVersion, securityKey } = req.body;
        const clientIp = req.clientIp;

        // التحقق من صحة مفتاح الأمان المرسل من التطبيق
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

// 2. 💓 نبضة الأمان المستمرة (Security Pulse / Heartbeat)
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

// 3. 🔄 توجيه طلبات المصادقة وتسجيل الدخول للسيرفر الداخلي
app.all('/api/auth/*', async (req, res) => {
    try {
        const targetUrl = `${INTERNAL_AUTH_SERVER}${req.originalUrl}`;
        console.log(`🔄 Proxying Auth request to: ${targetUrl}`);

        const response = await axios({
            method: req.method,
            url: targetUrl,
            data: req.body,
            headers: {
                ...req.headers,
                'x-client-ip': req.clientIp,
                'x-forwarded-by': 'kiura-dmz-gateway',
            }
        });

        res.status(response.status).json(response.data);
    } catch (error) {
        console.error(`❌ Auth Proxy Error: ${error.message}`);
        res.status(error.response?.status || 500).json({
            error: "Auth Gateway Routing Error",
            details: error.response?.data || error.message
        });
    }
});

// 4. 💬 توجيه طلبات المراسلة والشات إلى سيرفر server.js الداخلي
app.all('/api/chat/*', async (req, res) => {
    try {
        const targetUrl = `${INTERNAL_CHAT_SERVER}${req.originalUrl}`;
        console.log(`💬 Proxying Chat request to: ${targetUrl}`);

        const response = await axios({
            method: req.method,
            url: targetUrl,
            data: req.body,
            headers: {
                ...req.headers,
                'x-client-ip': req.clientIp,
                'x-forwarded-by': 'kiura-dmz-gateway',
            }
        });

        res.status(response.status).json(response.data);
    } catch (error) {
        console.error(`❌ Chat Proxy Error: ${error.message}`);
        res.status(error.response?.status || 500).json({
            error: "Chat Gateway Routing Error",
            details: error.response?.data || error.message
        });
    }
});

// 5. 🔒 توجيه طلبات الفحص الأمني إلى security_server.py الداخلي
app.all('/api/security/*', async (req, res) => {
    try {
        const targetUrl = `${INTERNAL_SECURITY_SERVER}${req.originalUrl}`;
        console.log(`🔒 Proxying Security request to: ${targetUrl}`);

        const response = await axios({
            method: req.method,
            url: targetUrl,
            data: req.body,
            headers: {
                ...req.headers,
                'x-client-ip': req.clientIp,
                'x-forwarded-by': 'kiura-dmz-gateway',
            }
        });

        res.status(response.status).json(response.data);
    } catch (error) {
        console.error(`❌ Security Proxy Error: ${error.message}`);
        res.status(error.response?.status || 500).json({ 
            error: "Security Gateway Routing Error",
            details: error.response?.data || error.message
        });
    }
});

// تشغيل البوابة على البورت المحدد
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🛡️ Cserver.js (DMZ Secure Gateway) is active and running on port ${PORT}`);
});
