import 'dart:convert';
import 'dart:io';
import '../constants/app_config.dart';
import '../security/security_engine.dart';


class KiuraWebSocketClient {
  WebSocket? _socket;

  Future<void> connect({required String userId, required String deviceId}) async {
    try {
      _socket = await WebSocket.connect(AppConfig.serverWsUrl);

      final handshakePayload = SecurityEngine.generateHandshakePayload(
        userId: userId,
        deviceId: deviceId,
      );

      _socket?.add(jsonEncode(handshakePayload));
    } catch (e) {
      print('WebSocket connection error: $e');
    }
  }

  void disconnect() {
    _socket?.close();
    print('Connection terminated securely.');
  }
}
