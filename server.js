const WebSocket = require('ws');
const url = require('url');
const jwt = require('jsonwebtoken');

// إعداد السيرفر على المنفذ المتاح
const PORT = process.env.PORT || 8080;
const wss = new WebSocket.Server({ port: PORT });

// المفتاح السري الموحد لنواة KIURA
const SECRET_KEY = "KIURA_SECURE_DEV_SIGNATURE_2026_JOKER";

// الحد الأدنى لإصدار التطبيق المقبول أمنياً (أي نسخة قديمة أقل ترفض فوراً)
const MIN_ALLOWED_VERSION = '1.0.0+1';

// خريطة لتخزين المستخدمين المتصلين حالياً
const connectedClients = new Map();

wss.on('connection', (ws, req) => {
  const parameters = url.parse(req.url, true).query;
  const userId = parameters.user_id;
  const clientVersion = parameters.version;
  const authToken = parameters.token;

  // 1. الحماية الصارمة ضد النسخ القديمة (Version Enforcement)
  if (!clientVersion || clientVersion !== MIN_ALLOWED_VERSION) {
    ws.send(JSON.stringify({ 
      error: 'نسخة التطبيق قديمة وغير مصرح لها بالاتصال بالسيرفر. يرجى التحديث إلى أحدث إصدار آمن.' 
    }));
    ws.close(4001, 'Unauthorized Outdated Version');
    console.log(`[Security Block] تم رفض اتصال نسخة قديمة مرفوضة: ${clientVersion || 'غير معروف'}`);
    return;
  }

  // 2. التحقق من وجود وصحة الـ Token (Authentication Check)
  if (!authToken) {
    ws.send(JSON.stringify({ error: 'مطلوب رمز مصادقة صحيح للاتصال' }));
    ws.close(4003, 'Forbidden - Missing Token');
    console.log('[Security Block] رفض اتصال لعدم وجود توكن مصادقة.');
    return;
  }

  try {
    const decoded = jwt.verify(authToken, SECRET_KEY);
    console.log(`[Auth Verified] مستخدم موثوق متصل بأمان: ${decoded.sub} (ID: ${userId})`);
  } catch (err) {
    ws.send(JSON.stringify({ error: 'رمز المصادقة منتهي الصلاحية أو غير صالح' }));
    ws.close(4001, 'Invalid Token');
    console.log(`[Security Block] فشل التحقق من الـ Token للمستخدم: ${userId}`);
    return;
  }

  // تسجيل العميل ضمن المتصلين النشطين
  if (userId) {
    connectedClients.set(userId, ws);
  }

  // استقبال رسائل الدردشة وتوجيهها لحظياً
  ws.on('message', (messageData) => {
    try {
      const parsedMessage = JSON.parse(messageData);
      console.log(`رسالة من ${userId} إلى ${parsedMessage.recipient_id}: ${parsedMessage.content || parsedMessage.message}`);

      const recipientWs = connectedClients.get(parsedMessage.recipient_id);
      if (recipientWs && recipientWs.readyState === WebSocket.OPEN) {
        recipientWs.send(JSON.stringify({
          id: parsedMessage.id || Date.now().toString(),
          sender_id: userId,
          chat_id: parsedMessage.chat_id,
          content: parsedMessage.content || parsedMessage.message,
          timestamp: parsedMessage.timestamp || new Date().toISOString()
        }));

        ws.send(JSON.stringify({
          type: 'ack',
          message_id: parsedMessage.id,
          status: 'sent'
        }));
      } else {
        ws.send(JSON.stringify({
          type: 'ack',
          message_id: parsedMessage.id,
          status: 'pending'
        }));
      }
    } catch (e) {
      console.error('خطأ في معالجة رسالة الـ WebSocket:', e);
    }
  });

  // تنظيف القائمة عند قطع الاتصال
  ws.on('close', () => {
    if (userId) {
      connectedClients.delete(userId);
      console.log(`[Disconnect] انقطع اتصال المستخدم: ${userId}`);
    }
  });
});

console.log(`🚀 KIURA Secure WebSocket Chat Server is running and protected on port ${PORT}`);
