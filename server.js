const net = require('net');
const clients = [];

const server = net.createServer((socket) => {
  console.log('تم اتصال جهاز جديد محلياً!');
  clients.push(socket);

  socket.on('data', (data) => {
    console.log('رسالة مستلمة: ' + data);
    // إرسال الرسالة لكل الأجهزة التانية المتصلة
    clients.forEach((client) => {
      if (client !== socket) {
        client.write(data);
      }
    });
  });

  socket.on('end', () => {
    console.log('انقطع اتصال أحد الأجهزة');
    const index = clients.indexOf(socket);
    if (index !== -1) clients.splice(index, 1);
  });
});

server.listen(3000, () => {
  console.log('السيرفر المحلي شغال 100% بدون إنترنت على البورت 3000!');
});