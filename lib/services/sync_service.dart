import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../data/database/db_helper.dart';

class SyncService {
  static final SyncService instance = SyncService._init();
  SyncService._init();

  /// فحص الرسائل المعلقة وإرسالها عند توفر الاتصال
  Future<void> syncPendingMessages(WebSocketChannel? channel) async {
    if (channel == null) {
      print('[Sync Service] لا يوجد اتصال نشط بالـ WebSocket حالياً.');
      return;
    }

    try {
      // 1. جلب الرسائل التي لم يتم إرسالها وحالتها pending من قاعدة البيانات المحلية
      List> pendingMessages = await DatabaseHelper.instance.getPendingMessages();

      if (pendingMessages.isEmpty) {
        print('[Sync Service] لا توجد رسائل معلقة للمزامنة.');
        return;
      }

      print('[Sync Service] جاري مزامنة ${pendingMessages.length} رسالة معلقة...');

      // 2. المرور على الرسائل وإرسالها تباعاً
      for (var msg in pendingMessages) {
        final messagePayload = {
          'id': msg['id'],
          'chat_id': msg['chat_id'],
          'recipient_id': msg['recipient_id'],
          'content': msg['content'],
          'type': msg['type'] ?? 'text',
          'timestamp': msg['timestamp'] ?? DateTime.now().toIso8601String(),
        };

        // إرسال الرسالة عبر قناة الـ WebSocket
        channel.sink.add(jsonEncode(messagePayload));

        // 3. تحديث حالة الرسالة محلياً إلى sent بعد الإرسال الناجح
        await DatabaseHelper.instance.updateMessageStatus(msg['id'], 'sent');
        print('[Sync Service] تم إرسال ومزامنة الرسالة بنجاح: ${msg['id']}');
      }
    } catch (e) {
      print('[Sync Service] حدث خطأ أثناء عملية المزامنة: $e');
    }
  }

  /// حفظ رسالة جديدة محلياً كـ pending في حال غياب الإنترنت ثم محاولة إرسالها
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
      'status': 'pending', // تبدأ كمعلقة لحين التأكد من الإرسال
      'timestamp': DateTime.now().toIso8601String(),
    };

    // حفظها في قاعدة البيانات المحلية أولاً (Local-First Strategy)
    await DatabaseHelper.instance.insertMessage(messageRow);
    print('[Local-First] تم حفظ الرسالة محلياً بحالة pending.');

    // محاولة إرسالها فوراً لو الاتصال موجود
    if (channel != null) {
      try {
        channel.sink.add(jsonEncode(messageRow));
        await DatabaseHelper.instance.updateMessageStatus(id, 'sent');
        print('[Local-First] تم إرسال الرسالة الفورية وتحديث حالتها إلى sent.');
      } catch (e) {
        print('[Local-First] فشل الإرسال الفوري، ستظل الرسالة في طابور الانتظار: $e');
      }
    }
  }
}
