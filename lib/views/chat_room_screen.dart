import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/database/db_helper.dart';
import '../services/chat_service.dart';

class ChatRoomScreen extends StatefulWidget {
  final String chatId;
  final String recipientId;
  final String recipientName;

  const ChatRoomScreen({
    super.key,
    required this.chatId,
    required this.recipientId,
    required this.recipientName,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  late String _currentUserId;
  bool _isConnected = false;
  StreamSubscription<String>? _changesSub;
  StreamSubscription<bool>? _connectionSub;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';

    // the connection lives in ChatService; this screen only listens to it
    final chat = ChatService.instance;
    chat.activeChatId = widget.chatId;
    chat.start();
    _isConnected = chat.isConnected;

    _changesSub = chat.changes.listen((chatId) {
      if (chatId == widget.chatId || chatId == '*') _loadMessages();
    });
    _connectionSub = chat.connectionState.listen((connected) {
      if (mounted) setState(() => _isConnected = connected);
    });

    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final rows = await DatabaseHelper.instance.getMessagesForChat(widget.chatId);
    if (!mounted) return;
    setState(() {
      _messages = rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();

    await ChatService.instance.sendMessage(
      chatId: widget.chatId,
      recipientId: widget.recipientId,
      content: text,
    );
    await _loadMessages();
  }

  String _formatTime(dynamic timestamp) {
    final parsed = DateTime.tryParse(timestamp?.toString() ?? '');
    if (parsed == null) return '';
    final t = parsed.toLocal();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    if (ChatService.instance.activeChatId == widget.chatId) {
      ChatService.instance.activeChatId = null;
    }
    _changesSub?.cancel();
    _connectionSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.recipientName, style: const TextStyle(color: Colors.white)),
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
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['sender_id'] == _currentUserId;
                final status = msg['status'];

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
                              _formatTime(msg['timestamp']),
                              style: const TextStyle(color: Colors.white54, fontSize: 10),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              Icon(
                                status == 'sent'
                                    ? Icons.done_all
                                    : status == 'queued'
                                        ? Icons.done
                                        : status == 'failed'
                                            ? Icons.error_outline
                                            : Icons.access_time,
                                size: 12,
                                color: status == 'sent'
                                    ? Colors.lightBlueAccent
                                    : status == 'failed'
                                        ? Colors.redAccent
                                        : Colors.grey,
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
