import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'dart:convert';

class WebSocketService {
  // رابط سيرفر الـ WebSocket على Render (تغيير http إلى wss للاتصال الآمن)
  final String _wsUrl = 'wss://chat-app-4hax.onrender.com';
  WebSocketChannel? _channel;

  // 1. الاتصال بالسيرفر
  void connect(String userId) {
    try {
      _channel = WebSocketChannel.connect(Uri.parse('$_wsUrl?user_id=$userId'));
      print('تم الاتصال بسيرفر الشات الفوري بنجاح 🚀');
    } catch (e) {
      print('خطأ في الاتصال بالـ WebSocket: $e');
    }
  }

  // 2. إرسال رسالة جديدة
  void sendMessage(String recipientId, String messageText) {
    if (_channel != null) {
      final messageData = jsonEncode({
        'recipient_id': recipientId,
        'message': messageText,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      _channel!.sink.add(messageData);
    }
  }

  // 3. الاستماع للرسائل الواردة لحظياً
  Stream? get messagesStream => _channel?.stream;

  // 4. قطع الاتصال عند الخروج
  void disconnect() {
    if (_channel != null) {
      _channel!.sink.close(status.goingAway);
      print('تم قطع الاتصال بالسيرفر.');
    }
  }
}
