const WebSocket = require('ws');
const crypto = require('crypto');
const Redis = require('ioredis');

// 1. إنشاء خادم WebSocket على البورت المحدد
const PORT = process.env.PORT || 8080;
const wss = new WebSocket.Server({ port: PORT });

// 2. إعداد الاتصال بقاعدة بيانات Redis السحابية أو المحلية لتوزيع الأحمال
const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';
const pubClient = new Redis(REDIS_URL);
const subClient = pubClient.duplicate();

// المفتاح السري المطابق 100% لتطبيق الفلاتر
const DEVELOPER_SECRET_KEY = "KIURA_SECURE_DEV_SIGNATURE_2026_JOKER";

// خريطة لتخزين الجلسات والاتصالات النشطة على هذه النسخة بالتحديد
const activeConnections = new Map();

// التعامل مع أخطاء اتصالات الـ Redis لمنع توقف السيرفر
pubClient.on('error', (err) => console.error('🚨 Redis Pub Error:', err.message));
subClient.on('error', (err) => console.error('🚨 Redis Sub Error:', err.message));

// الاستماع للرسائل القادمة عبر الـ Redis Cluster من النسخ الأخرى
subClient.subscribe('kiura_cluster_messages', (err, count) => {
    if (err) {
        console.error('❌ Failed to subscribe to Redis cluster channel:', err.message);
    } else {
        console.log(`🔗 Subscribed successfully to Redis cluster channel. Total Active: ${count}`);
    }
});

subClient.on('message', (channel, messageString) => {
    try {
        const parsedMessage = JSON.parse(messageString);
        const { recipient_id, payload } = parsedMessage;

        // إذا كان المستلم متصلاً بهذه النسخة تحديداً، قم بإعادة توجيه الرسالة فوراً
        if (activeConnections.has(recipient_id)) {
            const recipientWs = activeConnections.get(recipient_id);
            if (recipientWs.readyState === WebSocket.OPEN) {
                recipientWs.send(JSON.stringify(payload));
                console.log(`📡 Routed message via Redis cluster to user: ${recipient_id}`);
            }
        }
    } catch (e) {
        console.error('⚠️ Error processing Redis cluster message:', e.message);
    }
});

// 3. إدارة اتصالات العملاء
wss.on('connection', (ws) => {
    let currentUserId = null;
    console.log('🔌 New connection request received. Waiting for Handshake...');

    // 🛡️ حارس الأخطاء القاتل: حماية السيرفر من السقوط (Crash Protection) عند انقطاع مفاجئ للعميل
    ws.on('error', (error) => {
        console.error(`⚠️ Socket error detected for user [${currentUserId || 'Unknown/Unverified'}]:`, error.message);
        _cleanupUserSession(currentUserId);
    });

    ws.on('message', async (message) => {
        try {
            const payload = JSON.parse(message);
            
            // أ. مصادقة الـ Handshake
            if (payload.type === 'handshake') {
                const { user_id, device_id, timestamp, signature } = payload;
                
                const rawMessage = `${user_id}:${device_id}:${timestamp}`;
                const expectedSignature = crypto
                    .createHmac('sha256', DEVELOPER_SECRET_KEY)
                    .update(rawMessage)
                    .digest('hex');
                
                const isValid = crypto.timingSafeEqual(
                    Buffer.from(expectedSignature, 'utf-8'),
                    Buffer.from(signature || '', 'utf-8')
                );

                if (isValid) {
                    currentUserId = user_id;
                    activeConnections.set(user_id, ws);
                    console.log(`✅ Authorized connection for User: ${user_id} on Device: ${device_id}`);
                    
                    ws.send(JSON.stringify({
                        status: 'authorized',
                        message: 'Welcome to KIURA Secure Network'
                    }));
                } else {
                    console.log('🚨 SECURITY ALERT: Invalid signature detected! Rejecting connection.');
                    ws.send(JSON.stringify({
                        status: 'unauthorized',
                        message: 'Tampering detected. Connection terminated.'
                    }));
                    ws.close();
                }
            } 
            // ب. معالجة وتوجيه رسائل الشات عبر الـ Cluster
            else if (payload.type === 'chat_message') {
                if (!currentUserId) {
                    console.log('🚨 Unauthorized attempt to send message without valid Handshake.');
                    ws.close();
                    return;
                }

                const recipientId = payload.recipient_id;
                console.log(`💬 Chat message from ${currentUserId} to ${recipientId}`);

                // نشر الرسالة لشبكة السيرفرات المتصلة عبر Redis Pub/Sub
                await pubClient.publish('kiura_cluster_messages', JSON.stringify({
                    recipient_id: recipientId,
                    payload: {
                        type: 'incoming_message',
                        sender_id: currentUserId,
                        content: payload.content,
                        timestamp: payload.timestamp
                    }
                }));

                ws.send(JSON.stringify({
                    status: 'delivered',
                    timestamp: payload.timestamp
                }));
            } else {
                ws.close();
            }
        } catch (e) {
            console.error('⚠️ Error processing incoming WS frame:', e.message);
        }
    });

    // ج. تنظيف الجلسات عند الإغلاق الطبيعي للاتصال
    ws.on('close', () => {
        _cleanupUserSession(currentUserId);
        console.log(`❌ Connection closed for user: ${currentUserId || 'Unauthenticated'}`);
    });

    // دالة حرة لتنظيف الذاكرة ومسح المستخدم عند الفصل أو الخطأ
    function _cleanupUserSession(userId) {
        if (userId && activeConnections.has(userId)) {
            activeConnections.delete(userId);
            console.log(`🧹 Cleaned up session memory for user: ${userId}`);
        }
    }
});

// التعامل مع أخطاء السيرفر البرمجية العامة لمنع القفل المفاجئ
process.on('uncaughtException', (err) => {
    console.error('💥 Uncaught Exception caught by Server Guard:', err.stack || err);
});

process.on('unhandledRejection', (reason, promise) => {
    console.error('💥 Unhandled Rejection at Promise:', promise, 'reason:', reason);
});

console.log(`🛡️ KIURA High-Availability Server running on port ${PORT}`);