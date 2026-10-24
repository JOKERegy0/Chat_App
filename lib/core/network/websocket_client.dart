import 'dart:convert';
import 'dart:io';
import '../constants/app_config.dart';
import '../security/security_engine.dart';

class KiuraWebSocketClient {
  WebSocket? _socket;

  /// فتح الاتصال مع السيرفر وإرسال حزمة المصادقة والتحقق الفوري
  Future<void> connect({required String userId, required String deviceId}) async {
    try {
      // الاتصال برابط الـ WebSocket المعرف في الثوابت
      _socket = await WebSocket.connect(AppConfig.serverWsUrl);
      
      // توليد حزمة الـ Handshake المشفرة من محرك الأمان
      final handshakePayload = SecurityEngine.generateHandshakePayload(
        userId: userId,
        deviceId: deviceId,
      );

      // إرسال البصمة الأمنية كأول رسالة للسيرفر للتأكد من سلامة التطبيق
      _socket?.add(jsonEncode(handshakePayload));

      // الاستماع للرسائل القادمة من السيرفر
      _socket?.listen(
        (data) {
          final response = jsonDecode(data);
          print("Server Response: ${response['message']}");
          
          // لو السيرفر رفض التوقيع (تم كشف تلاعب)، سيتم قطع الاتصال فوراً
          if (response['status'] == 'unauthorized') {
            disconnect();
          }
        },
        onError: (error) {
          print("WebSocket Error: $error");
        },
        onDone: () {
          print("WebSocket Connection Closed by Server.");
        },
      );
    } catch (e) {
      print("Failed to connect to server: $e");
    }
  }

  /// إرسال رسالة نصية بعد نجاح المصادقة
  void sendMessage(String recipientId, String content) {
    if (_socket != null && _socket?.readyState == WebSocket.open) {
      final messagePayload = {
        "type": "chat_message",
        "recipient_id": recipientId,
        "content": content,
        "timestamp": DateTime.now().millisecondsSinceEpoch.toString(),
      };
      _socket?.add(jsonEncode(messagePayload));
    } else {
      print("Cannot send message: WebSocket is not connected.");
    }
  }

  /// إغلاق الاتصال بأمان
  void disconnect() {
    _socket?.close();
    print("Connection terminated securely.");
  }
}