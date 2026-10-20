import 'dart:io';
import 'package:flutter/material.dart';

void main() {
  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cloud Chat',
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<String> messages = [];
  final TextEditingController messageController = TextEditingController();
  WebSocket? channel;

    bool isConnecting = false;

  @override
  void initState() {
    super.initState();
    // حماية التطبيق من الانهيار والانتظار حتى اكتمال بناء الواجهة تماماً
    WidgetsBinding.instance.addPostFrameCallback((_) {
      connectToServer();
    });
  }

  Future<void> connectToServer() async {
    if (isConnecting) return;
    isConnecting = true;

    if (!mounted) return;
    setState(() {
      messages.add('جاري الاتصال بالسيرفر...');
    });

    try {
      channel = await WebSocket.connect('wss://chat-app-4hax.onrender.com');
      
      if (!mounted) return;
      setState(() {
        messages.add('تم الاتصال بالسيرفر السحابي بنجاح!');
        isConnecting = false;
      });

      channel!.listen(
        (data) {
          if (!mounted) return;
          setState(() {
            messages.add('الطرف الآخر: $data');
          });
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            messages.add('خطأ في الاتصال، جاري إعادة المحاولة خلال 5 ثوانٍ...');
            isConnecting = false;
          });
          _scheduleReconnect();
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            messages.add('انقطع الاتصال، جاري إعادة المحاولة خلال 5 ثوانٍ...');
            isConnecting = false;
          });
          _scheduleReconnect();
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        messages.add('فشل الاتصال، جاري إعادة المحاولة خلال 5 ثوانٍ...');
        isConnecting = false;
      });
      _scheduleReconnect();
    }
  }

  // دالة إعادة الاتصال التلقائي بشكل آمن
  void _scheduleReconnect() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        connectToServer();
      }
    });
  }


  void sendMessage() {
    final text = messageController.text.trim();
    if (text.isEmpty || channel == null) return;

    channel!.add(text);
    setState(() {
      messages.add('أنا: $text');
    });
    messageController.clear();
  }

  @override
  void dispose() {
    channel?.close();
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('شات سحابي مباشر'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(messages[index]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      hintText: 'اكتب رسالة...',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
