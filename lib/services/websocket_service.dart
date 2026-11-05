import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'dart:convert';
import 'api_config.dart';

class WebSocketService {
  WebSocketChannel? _channel;

  // 1. الاتصال بالسيرفر مع تمرير المعايير الأمنية (User ID, Version, Token)
  void connect({
    required String userId,
    required String token,
  }) {
    try {
      final wsUri = Uri.parse(
        '${AppConfig.webService}?user_id=$userId&version=${AppConfig.appVersion}&token=$token',
      );
      
      _channel = WebSocketChannel.connect(wsUri);
      print('تم الاتصال بسيرفر الشات الفوري بأمان تام 🚀');
    } catch (e) {
      print('خطأ في الاتصال بالـ WebSocket: $e');
    }
  }

  // 2. إرسال رسالة جديدة
  void sendMessage(String recipientId, String messageText, {String? chatId}) {
    if (_channel != null) {
      final messageData = jsonEncode({
        'recipient_id': recipientId,
        'chat_id': chatId ?? '',
        'content': messageText,
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
