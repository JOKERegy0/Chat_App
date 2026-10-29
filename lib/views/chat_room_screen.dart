import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/sync_service.dart';
import '../data/database/db_helper.dart';

class ChatRoomScreen extends StatefulWidget {
  final String recipientId;
  final String recipientName;

  const ChatRoomScreen({
    super.key,
    required this.recipientId,
    required this.recipientName,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List> _messages = [];
  WebSocketChannel? _channel;
  late String _currentUserId;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    _initWebSocketAndSync();
    _loadLocalMessages();
  }

  void _initWebSocketAndSync() {
    final session = Supabase.instance.client.auth.currentSession;
    final accessToken = session?.accessToken ?? '';
    const String appVersion = '1.0.0+1';

    final uri = Uri.parse(
      'wss://chat-app-4hax.onrender.com?user_id=$_currentUserId&version=$appVersion&token=$accessToken',
    );

    try {
      _channel = WebSocketChannel.connect(uri);
      setState(() {
        _isConnected = true;
      });

      SyncService.instance.syncPendingMessages(_channel);

      _channel!.stream.listen(
        (data) {
          final decoded = jsonDecode(data);
          if (decoded['type'] != 'ack') {
            setState(() {
              _messages.add(decoded);
            });
          }
        },
        onError: (error) {
          setState(() {
            _isConnected = false;
          });
        },
        onDone: () {
          setState(() {
            _isConnected = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _isConnected = false;
      });
    }
  }

  Future<void> _loadLocalMessages() async {
    final localMsgs = await DatabaseHelper.instance.getMessagesForChat(widget.recipientId);
    setState(() {
      _messages.clear();
      _messages.addAll(localMsgs);
    });
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final messageContent = _messageController.text.trim();
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    _messageController.clear();

    final newMessage = {
      'id': messageId,
      'chat_id': widget.recipientId,
      'sender_id': _currentUserId,
      'recipient_id': widget.recipientId,
      'content': messageContent,
      'type': 'text',
      'status': 'pending',
      'timestamp': DateTime.now().toIso8601String(),
    };

    setState(() {
      _messages.add(newMessage);
    });

    await SyncService.instance.handleOutgoingMessage(
      id: messageId,
      chatId: widget.recipientId,
      senderId: _currentUserId,
      recipientId: widget.recipientId,
      content: messageContent,
      channel: _isConnected ? _channel : null,
    );
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.recipientName),
            const SizedBox(width: 8),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isConnected ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['sender_id'] == _currentUserId;

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFF3B82F6) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['content'] ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              msg['timestamp'] != null
                                  ? msg['timestamp'].toString().substring(11, 16)
                                  : '',
                              style: const TextStyle(color: Colors.white54, fontSize: 10),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              Icon(
                                msg['status'] == 'sent' ? Icons.done_all : Icons.done,
                                size: 12,
                                color: msg['status'] == 'sent' ? Colors.lightBlueAccent : Colors.grey,
                              ),
                            ]
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
            color: const Color(0xFF0F172A),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالتك في KIURA...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF3B82F6),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
