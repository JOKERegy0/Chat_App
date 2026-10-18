const WebSocket = require('ws');

const PORT = process.env.PORT || 3000;
const wss = new WebSocket.Server({ port: PORT });

console.log('اليسرفر شغال ونافل للرسائل علي البورت ${PORT}');

wss.on('connection', (ws) => {
    console.log('تن اتصال جهاز جديد بالسيرفر!');

    ws.on('message', (message) => {
        console.log('رسالة مستلمة: ' + message);
        wss.clients.forEach((client) => {
            if (client !== ws && client.readyState === WebSocket.OPEN) {
                client.send(message.toString());
            }
        });
    });

    ws.on('error', (err) => {
        console.log('(تم تجنب الايقاف) خطا في الاتصال:', err.message);
    });

ws.on('close', () => {
  console.log('انقطع اتصال احد الاجهزة');
});
});