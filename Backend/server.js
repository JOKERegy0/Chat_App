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
const QUEUE_BATCH = 100;
const QUEUE_TTL_DAYS = 7;

const ID_RE = /^[A-Za-z0-9_-]{1,80}$/;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function short(id) {
  return String(id).slice(0, 8);
}

// ---------- version check (minimum version, not exact match) ----------
function parseVersion(v) {
  // a raw "+" in a URL query arrives as a space, so accept both
  const m = /^(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$/.exec(String(v || '').trim().replace(' ', '+'));
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

// ---------- database calls with the USER's own token (RLS protects every row) ----------
async function db(path, token, { method = 'GET', body, prefer } = {}) {
  const headers = {
    apikey: SUPABASE_KEY,
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
  };
  if (prefer) headers.Prefer = prefer;

  const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(8000),
  });

  let data = null;
  const text = await res.text();
  if (text) {
    try {
      data = JSON.parse(text);
    } catch (_) {}
  }
  return { ok: res.ok, status: res.status, data };
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

function isOpen(ws) {
  return ws && ws.readyState === WebSocket.OPEN;
}

// ---------- queue helpers ----------

// the token was refused by the database: ask the app to reconnect with a fresh one
function tokenExpired(ws) {
  ws.close(4001, 'Token expired');
}

// send the messages that are waiting for this user
async function deliverQueue(ws) {
  if (ws.deliveringQueue) return;
  ws.deliveringQueue = true;
  try {
    const r = await db(
      `message_queue?recipient_id=eq.${ws.userId}&delivered_at=is.null` +
        `&select=id,sender_id,content,sent_at&order=sent_at.asc&limit=${QUEUE_BATCH}`,
      ws.token
    );
    if (r.status === 401) return tokenExpired(ws);
    if (r.ok && Array.isArray(r.data)) {
      ws.hasMoreQueue = r.data.length === QUEUE_BATCH;
      for (const row of r.data) {
        sendJson(ws, {
          id: row.id,
          sender_id: row.sender_id,
          chat_id: `chat_${row.sender_id}`,
          content: row.content,
          timestamp: new Date(row.sent_at).toISOString(),
        });
      }
      if (r.data.length > 0) console.log(`[queue] delivered ${r.data.length} to ${short(ws.userId)}`);
    }
  } catch (_) {
  } finally {
    ws.deliveringQueue = false;
  }
}

// tell a user (as sender) about messages that were delivered while he was offline
async function collectReceipts(ws) {
  try {
    const r = await db(
      `message_queue?sender_id=eq.${ws.userId}&delivered_at=not.is.null&select=id&limit=${QUEUE_BATCH}`,
      ws.token
    );
    if (r.ok && Array.isArray(r.data) && r.data.length > 0) {
      const ids = r.data.map((x) => x.id);
      ids.forEach((id) => sendJson(ws, { type: 'ack', message_id: id, status: 'sent' }));
      await db(`message_queue?id=in.(${ids.join(',')})&sender_id=eq.${ws.userId}&delivered_at=not.is.null`, ws.token, {
        method: 'DELETE',
      });
    }
  } catch (_) {}
}

// remove this user's messages that nobody collected for a week
async function cleanupExpired(ws) {
  try {
    const cutoff = new Date(Date.now() - QUEUE_TTL_DAYS * 24 * 60 * 60 * 1000).toISOString();
    await db(`message_queue?sent_at=lt.${encodeURIComponent(cutoff)}`, ws.token, { method: 'DELETE' });
  } catch (_) {}
}

// ---------- incoming socket messages ----------

async function handleReceipt(ws, msg) {
  // the app sends one id (message_id); a list (ids) is accepted too
  const rawIds = Array.isArray(msg.ids) ? msg.ids : typeof msg.message_id === 'string' ? [msg.message_id] : [];
  const ids = rawIds.filter((i) => typeof i === 'string' && ID_RE.test(i)).slice(0, QUEUE_BATCH);
  if (ids.length === 0) return;

  try {
    // the recipient confirms: mark delivered (the database wipes the text at this moment)
    const r = await db(
      `message_queue?id=in.(${ids.join(',')})&recipient_id=eq.${ws.userId}&delivered_at=is.null&select=id,sender_id`,
      ws.token,
      { method: 'PATCH', body: { delivered_at: new Date().toISOString() }, prefer: 'return=representation' }
    );
    if (r.status === 401) return tokenExpired(ws);

    if (r.ok && Array.isArray(r.data)) {
      const bySender = new Map();
      for (const row of r.data) {
        if (!bySender.has(row.sender_id)) bySender.set(row.sender_id, []);
        bySender.get(row.sender_id).push(row.id);
      }

      for (const [senderId, rowIds] of bySender) {
        const senderWs = connectedClients.get(senderId);
        if (isOpen(senderWs)) {
          rowIds.forEach((id) => sendJson(senderWs, { type: 'ack', message_id: id, status: 'sent' }));
          // the sender clears the delivery marker with his own token
          db(`message_queue?id=in.(${rowIds.join(',')})&sender_id=eq.${senderId}&delivered_at=not.is.null`, senderWs.token, {
            method: 'DELETE',
          }).catch(() => {});
        }
        // if the sender is offline, collectReceipts() tells him when he connects
      }
    }
  } catch (_) {}

  if (ws.hasMoreQueue) deliverQueue(ws);
}

async function handleChatMessage(ws, msg) {
  const recipientId = msg && msg.recipient_id;
  const content = msg && (msg.content || msg.message);

  const clientId = msg && typeof msg.id === 'string' && ID_RE.test(msg.id) ? msg.id : null;
  const reject = (text) => {
    sendJson(ws, { error: text });
    if (clientId) sendJson(ws, { type: 'ack', message_id: clientId, status: 'rejected' });
  };

  if (typeof recipientId !== 'string' || typeof content !== 'string' || !UUID_RE.test(recipientId)) {
    return reject('بيانات الرسالة ناقصة');
  }
  if (recipientId === ws.userId) {
    return reject('لا يمكن إرسال رسالة لنفسك');
  }
  if (content.length === 0 || content.length > MAX_CONTENT_LENGTH) {
    return reject('طول الرسالة غير مقبول');
  }

  const messageId =
    clientId || `${short(ws.userId)}-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`;

  // 1) save first, so the message is never lost
  let stored;
  try {
    const r = await db('message_queue', ws.token, {
      method: 'POST',
      body: { id: messageId, sender_id: ws.userId, recipient_id: recipientId, content },
      prefer: 'return=minimal',
    });
    if (r.status === 401) return tokenExpired(ws);

    if (r.ok) stored = 'new';
    else if (r.data && r.data.code === '23505') stored = 'duplicate';
    else {
      console.log(`[queue] insert refused (${r.status}) for ${short(ws.userId)}`);
      const final = r.data && (r.data.code === '23503' || r.data.code === '23514');
      return sendJson(ws, { type: 'ack', message_id: messageId, status: final ? 'rejected' : 'failed' });
    }
  } catch (_) {
    return sendJson(ws, { type: 'ack', message_id: messageId, status: 'failed' });
  }

  // 2) if the recipient is online, push it now (he will confirm with a receipt)
  if (stored === 'new') {
    const recipientWs = connectedClients.get(recipientId);
    if (isOpen(recipientWs)) {
      sendJson(recipientWs, {
        id: messageId,
        sender_id: ws.userId,
        chat_id: `chat_${ws.userId}`,
        content,
        timestamp: new Date().toISOString(),
      });
    }
  }

  // 3) tell the sender: "the server has it". The double check comes with the recipient's receipt.
  sendJson(ws, { type: 'ack', message_id: messageId, status: 'queued' });
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

  ws.userId = null; // set only after the token is verified
  ws.token = authToken;
  ws.hasMoreQueue = false;
  ws.deliveringQueue = false;

  const earlyMessages = []; // messages that arrive while the token is being checked
  let windowStart = Date.now();
  let windowCount = 0;
  let chain = Promise.resolve(); // handles this user's messages one after another, in order

  function handleRaw(raw) {
    let msg;
    try {
      msg = JSON.parse(raw);
    } catch (_) {
      return sendJson(ws, { error: 'صيغة الرسالة غير صحيحة' });
    }
    if (!msg || typeof msg !== 'object') return;

    if (msg.type === 'receipt') {
      chain = chain.then(() => handleReceipt(ws, msg)).catch(() => {});
      return;
    }

    const now = Date.now();
    if (now - windowStart > RATE_LIMIT_WINDOW_MS) {
      windowStart = now;
      windowCount = 0;
    }
    if (++windowCount > RATE_LIMIT_COUNT) {
      return sendJson(ws, { error: 'عدد الرسائل كبير. حاول بعد قليل.' });
    }

    chain = chain.then(() => handleChatMessage(ws, msg)).catch(() => {});
  }

  ws.on('message', (data) => {
    const raw = data.toString();
    if (ws.userId) handleRaw(raw);
    else if (earlyMessages.length < 10) earlyMessages.push(raw);
  });

  ws.isAlive = true;
  ws.on('pong', () => {
    ws.isAlive = true;
  });

  ws.on('close', () => {
    if (ws.userId && connectedClients.get(ws.userId) === ws) {
      connectedClients.delete(ws.userId);
      console.log(`[ws] ${short(ws.userId)} disconnected (${connectedClients.size} online)`);
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

    ws.userId = verifiedId;
    connectedClients.set(verifiedId, ws);
    console.log(`[ws] ${short(verifiedId)} connected (${connectedClients.size} online)`);

    earlyMessages.splice(0).forEach(handleRaw);

    // catch up: waiting messages, delivery news for his own messages, and old leftovers
    deliverQueue(ws);
    collectReceipts(ws);
    cleanupExpired(ws);
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
