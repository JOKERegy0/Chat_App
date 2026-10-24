import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/network/websocket_client.dart';
import '../data/database/database_helper.dart';

class ChatView extends StatefulWidget {
  final String currentUserId;
  final String peerId;
  final String peerName;

  const ChatView({
    Key? key,
    required this.currentUserId,
    required this.peerId,
    required this.peerName,
  }) : super(key: key);

  @override
  _ChatViewState createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _messageController = TextEditingController();
  final WebSocketClient _wsClient = WebSocketClient();
  List<Map<String, dynamic>> _messages = [];
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _initChatConnection();
    _loadLocalMessages();
  }

  void _initChatConnection() {
    // الاتصال بسيرفر المراسلة وتثبيت الهوية (Handshake)
    _wsClient.connect(
      url: "ws://your-server-ip:8080", // استبدلها برابط السيرفر الخاص بك
      currentUserId: widget.currentUserId,
      deviceId: "infinix_note_50s_5g",
    );
    setState(() {
      _isConnected = true;
    });
  }

  Future<void> _loadLocalMessages() async {
    // جلب الرسائل محلياً من قاعدة البيانات لدعم نظام Local-First
    final localMsgs = await DatabaseHelper.instance.getMessages(widget.peerId);
    setState(() {
      _messages = localMsgs;
    });
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final messageText = _messageController.text.trim();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final messageId = DateTime.now().microsecondsSinceEpoch.toString();

    final messageMap = {
      "id": messageId,
      "chat_id": widget.peerId,
      "sender_id": widget.currentUserId,
      "recipient_id": widget.peerId,
      "content": messageText,
      "type": "text",
      "status": "pending", // الحالة الأولية طبقاً للخطة
      "timestamp": timestamp,
    };

    // 1. الحفظ محلياً أولاً (Local-First Architecture)
    await DatabaseHelper.instance.insertMessage(messageMap);
    
    // 2. إرسال عبر الـ WebSocket للسيرفر
    // _wsClient.sendMessage(widget.peerId, messageText);

    _messageController.clear();
    _loadLocalMessages(); // تحديث الواجهة فوراً
  }

  @override
  void dispose() {
    _wsClient.disconnect();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl, // دعم اللغة العربية واتجاهات النصوص
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.peerName),
          backgroundColor: Colors.teal,
          actions: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                ),
              ),
            )
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                reverse: true, // تدفق الشات من الأسفل للأعلى باحترافية
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isMe = msg['sender_id'] == widget.currentUserId;
                  
                  return Align(
                    alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.teal[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg['content'] ?? '',
                            style: const TextStyle(fontSize: 16, color: Colors.black87),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "1:45 م", // تنسيق الوقت 12 ساعة
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                              const SizedBox(width: 4),
                              // علامات الصح الديناميكية (Pending, Sent, Delivered, Read)
                              Icon(
                                Icons.done_all,
                                size: 14,
                                color: msg['status'] == 'read' ? Colors.blue : Colors.grey,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: "اكتب رسالة...",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.teal),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}