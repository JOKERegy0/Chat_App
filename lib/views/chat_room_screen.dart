import 'package:flutter/material.dart';
import 'websocket_service.dart';
import 'media_service.dart';
import 'dart:io';

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  // 1. حط كود التعريف هنا فوق في بداية الـ State
  final ReportService _reportService = ReportService();
  bool _isReporting = false;

  // 2. دالة التعامل مع الإبلاغ اللي سألت عنها
  void handleUserReport(String reportedUserId, String chatEvidence, String ipAddress) async {
    setState(() { _isReporting = true; });

    bool success = await _reportService.submitReport(
      reportedUserId: reportedUserId,
      chatEvidence: chatEvidence,
      reportedUserIp: ipAddress,
    );

    setState(() { _isReporting = false; });

    if (success) {
      // إرسال رسالة نجاح للمبلغ (تظهر كـ SnackBar مثلاً)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال البلاغ بنجاح وسيتم مراجعته.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ, حاول مرة أخرى.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipientName),
        actions: [
          // 3. مثال لزرار إبلاغ في الـ AppBar (PopupMenuButton)
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'report') {
                // هنا بنستدعي الدالة وندديها البيانات المطلوبة
                handleUserReport(
                  widget.recipientId, 
                  'محتوى آخر رسالة أو المحادثة', 
                  '192.168.1.1' // أو جلب الآيبي الحقيقي للمستخدم لو متاح
                );
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'report',
                child: Text('إبلاغ عن المستخدم', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: /* باقي تصميم الشاشة */,
    );
  }
}

@overrideeState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final WebSocketService _wsService = WebSocketService();
  final MediaService _mediaService = MediaService();
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    // 1. الاتصال بسيرفر الـ WebSocket لحظياً
    _wsService.connect(widget.currentUserId);

    // 2. الاستماع للرسائل الواردة من السيرفر
    _wsService.messagesStream?.listen((data) {
      setState(() {
        _messages.add({
          'sender': 'other',
          'text': data.toString(),
          'time': DateTime.now().toString(),
        });
      });
    });
  }

  // دالة إرسال الرسالة عبر الـ WebSocket
  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    String textToSend = _messageController.text.trim();

    // إرسال الرسالة للسيرفر
    _wsService.sendMessage(widget.recipientId, textToSend);

    // إضافة الرسالة مباشرة لواجهة المستخدم المحلية
    setState(() {
      _messages.add({
        'sender': 'me',
        'text': textToSend,
        'time': DateTime.now().toString(),
      });
    });

    _messageController.clear();
  }

  @override
  void dispose() {
    _wsService.disconnect();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipientName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          // قائمة عرض الرسائل لحظياً
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                bool isMe = msg['sender'] == 'me';
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg['text'],
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                );
              },
            ),
          ),

          // شريط إدخال الرسائل والأزرار
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.white,
            child: Row(
              children: [
                // زر إرفاق الوسائط (صور أو ملفات) باستخدام MediaService
                IconButton(
                  icon: const Icon(Icons.attach_file, color: Colors.blueAccent),
                  onPressed: () {
                    // هنا سيتم فتح معرض الصور ورفعها عبر MediaService لاحقاً
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'اكتب رسالتك هنا...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
