import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../constants/app_config.dart';

class SecurityEngine {
  static Map<String, dynamic> generateHandshakePayload({
    required String userId,
    required String deviceId,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final message = '$userId:$deviceId:$timestamp';

    final keyBytes = utf8.encode(AppConfig.developerSignatureKey);
    final messageBytes = utf8.encode(message);
    final digest = Hmac(sha256, keyBytes).convert(messageBytes);
    final signature = digest.toString();

    return {
      'type': 'handshake',
      'user_id': userId,
      'device_id': deviceId,
      'timestamp': timestamp,
      'signature': signature,
    };
  }
}
