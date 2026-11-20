const http = require('http');
const WebSocket = require('ws');

const PORT = process.env.PORT || 8080;
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_KEY; // publishable key
const MIN_APP_VERSION = process.env.MIN_APP_VERSION || '1.0.0+1';

if (!SUPABASE_URL || !SUPABASE_KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_KEY environment variables');
  process.exit(1);
}

const MAX_CONTENT_LENGTH = 4000;
const RATE_LIMIT_COUNT = 30; // messages
const RATE_LIMIT_WINDOW_MS = 10000; // per 10 seconds

// ---------- version check (minimum version, not exact match) ----------
function parseVersion(v) {
  const m = /^(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$/.exec(String(v || ''));
  if (!m) return null;
  return [m[1], m[2], m[3], m[4] || 0].map(Number);
}

function isVersionAllowed(v) {
  const cur = parseVersion(v);
  const min = parseVersion(MIN_APP_VERSION);
  if (!cur || !min) return false;
  for (let i = 0; i < 4; i++) {
    if (cur[i] !== min[i]) return cur[i] > min[i];
  }
  return true;
}

// ---------- token check: ask Supabase who this token belongs to ----------
async function verifyToken(token) {
  try {
    const res = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: { apikey: SUPABASE_KEY, Authorization: `Bearer ${token}` },
      signal: AbortSignal.timeout(5000),
    });
    if (!res.ok) return null;
    const user = await res.json();
    return user && user.id ? user.id : null;
  } catch (_) {
    return null;
  }
}

// ---------- http + websocket ----------
const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ status: 'ONLINE', service: 'kiura-ws' }));
  }
  res.writeHead(404);
  res.end();
});

const wss = new WebSocket.Server({ server, maxPayload: 64 * 1024 });

// userId -> ws
const connectedClients = new Map();

function sendJson(ws, obj) {
  if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(obj));
}

wss.on('connection', (ws, req) => {
  const params = new URL(req.url, 'http://localhost').searchParams;
  const clientVersion = params.get('version');
  const authToken = params.get('token');

  if (!isVersionAllowed(clientVersion)) {
    sendJson(ws, { error: 'نسخة التطبيق قديمة. يرجى التحديث.' });
    return ws.close(4001, 'Outdated Version');
  }
  if (!authToken) {
    sendJson(ws, { error: 'مطلوب رمز مصادقة صحيح للاتصال' });
    return ws.close(4003, 'Missing Token');
  }

  let userId = null; // set only after the token is verified
  const earlyMessages = []; // messages that arrive while the token is being checked
  let windowStart = Date.now();
  let windowCount = 0;

  function handleMessage(raw) {
    const now = Date.now();
    if (now - windowStart > RATE_LIMIT_WINDOW_MS) {
      windowStart = now;
      windowCount = 0;
    }
    if (++windowCount > RATE_LIMIT_COUNT) {
      return sendJson(ws, { error: 'عدد الرسائل كبير. حاول بعد قليل.' });
    }

    let msg;
    try {
      msg = JSON.parse(raw);
    } catch (_) {
      return sendJson(ws, { error: 'صيغة الرسالة غير صحيحة' });
    }

    const recipientId = msg && msg.recipient_id;
    const content = msg && (msg.content || msg.message);
    if (typeof recipientId !== 'string' || typeof content !== 'string') {
      return sendJson(ws, { error: 'بيانات الرسالة ناقصة' });
    }
    if (content.length === 0 || content.length > MAX_CONTENT_LENGTH) {
      return sendJson(ws, { error: 'طول الرسالة غير مقبول' });
    }

    const messageId = typeof msg.id === 'string' ? msg.id : Date.now().toString();
    const recipientWs = connectedClients.get(recipientId);

    if (recipientWs && recipientWs.readyState === WebSocket.OPEN) {
      sendJson(recipientWs, {
        id: messageId,
        sender_id: userId,
        // thread id on the receiver's side is built from the sender's id
        chat_id: `chat_${userId}`,
        content,
        timestamp: new Date().toISOString(),
      });
      sendJson(ws, { type: 'ack', message_id: messageId, status: 'sent' });
    } else {
      // recipient offline: offline queue is not built yet
      sendJson(ws, { type: 'ack', message_id: messageId, status: 'pending' });
    }
  }

  ws.on('message', (data) => {
    const raw = data.toString();
    if (userId) handleMessage(raw);
    else if (earlyMessages.length < 10) earlyMessages.push(raw);
  });

  ws.isAlive = true;
  ws.on('pong', () => {
    ws.isAlive = true;
  });

  ws.on('close', () => {
    if (userId && connectedClients.get(userId) === ws) {
      connectedClients.delete(userId);
    }
  });

  ws.on('error', () => {});

  verifyToken(authToken).then((verifiedId) => {
    if (!verifiedId) {
      sendJson(ws, { error: 'رمز المصادقة غير صالح أو منتهي' });
      return ws.close(4001, 'Invalid Token');
    }
    if (ws.readyState !== WebSocket.OPEN) return;

    // one live connection per user: replace the old one
    const old = connectedClients.get(verifiedId);
    if (old && old !== ws) old.close(4009, 'Replaced by a new connection');

    userId = verifiedId;
    connectedClients.set(userId, ws);
    earlyMessages.splice(0).forEach(handleMessage);
  });
});

// keep connections alive and drop dead ones
setInterval(() => {
  wss.clients.forEach((ws) => {
    if (ws.isAlive === false) return ws.terminate();
    ws.isAlive = false;
    ws.ping();
  });
}, 25000);

server.listen(PORT, () => {
  console.log(`KIURA WebSocket server running on port ${PORT}`);
});
