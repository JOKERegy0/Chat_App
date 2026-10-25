import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../constants/app_config.dart';

class SecurityEngine {
  /// البصمة المشفرة للتحقق من هوية التطبيق ومنع التلاعب
  static Map<String, dynamic> generateHandshakePayload({
    required String userId,
    required String deviceId,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    // دمج البيانات بنفس الترتيب الرياضي المعتمد في السيرفر
    final message = "$userId:$deviceId:$timestamp";

    // استخدام المفتاح السري المحفور في النواة HMAC-SHA256 تطبيق خوارزمية
    final keyBytes = utf8.encode(AppConfig.developerSignatureKey);
    final messageBytes = utf8.encode(message);
    final hmacSha256 = Hmac(sha256, keyBytes);
    final digest = hmacSha256.convert(messageBytes);
    final signature = digest.toString();

         return {
      "type": "handshake",
      "user_id": userId,
      "device_id": deviceId,
      "timestamp": timestamp,
      "signature": signature,
     }; // هنا الـ Map قفلت بـ }; لأنها جوه الدالة
   }    // هنا قفلة الدالة
 }      // هنا قفلة الكلاس (قوس عادي بدون نقطة منقوطة)


