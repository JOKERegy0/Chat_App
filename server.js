const WebSocket = require('ws');
const url = require('url');
const jwt = require('jsonwebtoken');

// إعداد السيرفر على البورت 8080 أو المنفذ المتاح
const PORT = process.env.PORT || 8080;
const wss = new WebSocket.Server({ port: PORT });

// المفتاح السري الموحد لنواة KIURA (المطابق لسيرفر المصادقة)
const SECRET_KEY = "KIURA_SECURE_DEV_SIGNATURE_2026_JOKER";

// النسخة الأدنى المسموح لها بالاتصال (لمنع النسخ القديمة غير الآمنة)
const MIN_ALLOWED_VERSION = '1.0.0+1';

// تخزين العملاء المتصلين حالياً
const connectedClients = new Map();

wss.on('connection', (ws, req) => {
  const parameters = url.parse(req.url, true).query;
  const userId = parameters.user_id;
  const clientVersion = parameters.version;
  const authToken = parameters.token;

  // 1. فحص إصدار التطبيق (رفض النسخ القديمة فوراً)
  if (!clientVersion || clientVersion !== MIN_ALLOWED_VERSION) {
    ws.send(JSON.stringify({ 
      error: 'نسخة التطبيق قديمة وغير مصرح لها بالاتصال. يرجى التحديث إلى أحدث إصدار آمن من KIURA.' 
    }));
    ws.close(4001, 'Unauthorized Version');
    console.log(`[Security Alert] رفض اتصال من نسخة قديمة مرفوضة: ${clientVersion}`);
    return;
  }

  // 2. التحقق من صحة التوكن (JWT Authentication Check)
  if (!authToken) {
    ws.send(JSON.stringify({ error: 'مطلوب رمز مصادقة صحيح (Auth Token Missing)' }));
    ws.close(4003, 'Forbidden - No Token');
    console.log('[Security Alert] رفض اتصال لعدم وجود توكن مصادقة.');
    return;
  }

  try {
    const decoded = jwt.verify(authToken, SECRET_KEY);
    console.log(`[Auth Success] مستخدم موثوق متصل: ${decoded.sub} (User ID: ${userId})`);
  } catch (err) {
    ws.send(JSON.stringify({ error: 'رمز المصادقة غير صالح أو منتهي الصلاحية' }));
    ws.close(4001, 'Invalid Token');
    console.log(`[Security Alert] فشل التحقق من الـ Token للمستخدم: ${userId}`);
    return;
  }

  // تسجيل العميل في قائمة المتصلين
  if (userId) {
    connectedClients.set(userId, ws);
  }

  // استقبال الرسائل وتوجيهها للمستقبل لحظياً
  ws.on('message', (messageData) => {
    try {
      const parsedMessage = JSON.parse(messageData);
      console.log(`رسالة جديدة من ${userId} إلى ${parsedMessage.recipient_id}: ${parsedMessage.content || parsedMessage.message}`);

      // التحقق من وجود المستقبل وإرسال الرسالة له لو كان متصلاً
      const recipientWs = connectedClients.get(parsedMessage.recipient_id);
      if (recipientWs && recipientWs.readyState === WebSocket.OPEN) {
        recipientWs.send(JSON.stringify({
          id: parsedMessage.id || Date.now().toString(),
          sender_id: userId,
          chat_id: parsedMessage.chat_id,
          content: parsedMessage.content || parsedMessage.message,
          timestamp: parsedMessage.timestamp || new Date().toISOString()
        }));

        // إرسال تأكيد وصول (Ack) للمرسل
        ws.send(JSON.stringify({
          type: 'ack',
          message_id: parsedMessage.id,
          status: 'sent'
        }));
      } else {
        // لو المستقبل غير متصل، يتم تخزينها في قاعدة البيانات عبر النظام المحلي أو Supabase لاحقاً
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

  // عند قطع الاتصال
  ws.on('close', () => {
    if (userId) {
      connectedClients.delete(userId);
      console.log(`[Disconnect] انقطع اتصال المستخدم: ${userId}`);
    }
  });
});

console.log(`🚀 KIURA Secure WebSocket Chat Server is running on port ${PORT}`);
