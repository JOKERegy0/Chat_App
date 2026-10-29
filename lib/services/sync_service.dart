import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../data/database/db_helper.dart';

class SyncService {
  static final SyncService instance = SyncService._init();
  SyncService._init();

  Future<void> syncPendingMessages(WebSocketChannel? channel) async {
    if (channel == null) return;

    try {
      List pendingMessages = await DatabaseHelper.instance.getPendingMessages();

      if (pendingMessages.isEmpty) return;

      for (var msg in pendingMessages) {
        final messagePayload = {
          'id': msg['id'],
          'chat_id': msg['chat_id'],
          'recipient_id': msg['recipient_id'],
          'content': msg['content'],
          'type': msg['type'] ?? 'text',
          'timestamp': msg['timestamp'] ?? DateTime.now().toIso8601String(),
        };

        channel.sink.add(jsonEncode(messagePayload));
        await DatabaseHelper.instance.updateMessageStatus(msg['id'], 'sent');
      }
    } catch (e) {
      print('Sync Error: $e');
    }
  }

  Future<void> handleOutgoingMessage({
    required String id,
    required String chatId,
    required String senderId,
    required String recipientId,
    required String content,
    required WebSocketChannel? channel,
  }) async {
    final messageRow = {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'recipient_id': recipientId,
      'content': content,
      'type': 'text',
      'status': 'pending',
      'timestamp': DateTime.now().toIso8601String(),
    };

    await DatabaseHelper.instance.insertMessage(messageRow);

    if (channel != null) {
      try {
        channel.sink.add(jsonEncode(messageRow));
        await DatabaseHelper.instance.updateMessageStatus(id, 'sent');
      } catch (e) {
        print('Send Error: $e');
      }
    }
  }
}
