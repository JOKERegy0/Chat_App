import 'dart:io';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Joker Chat',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<String> messages = [];
  final TextEditingController messageController = TextEditingController();
  WebSocket? channel;
  bool isConnecting = false;

  @override
  void initState() {
    super.initState();
    // الانتظار لحين اكتمال بناء الواجهة تماماً قبل بدء الاتصال لمنع الانهيار
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
            messages.add('خطأ في الاتصال بالسيرفر');
            isConnecting = false;
          });
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            messages.add('انقطع الاتصال بالسيرفر');
            isConnecting = false;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        messages.add('فشل الاتصال بالسيرفر، تأكد من الإنترنت');
        isConnecting = false;
      });
    }
  }

  void sendMessage() {
    final text = messageController.text.trim();
    if (text.isEmpty || channel == null) return;

    try {
      channel!.add(text);
      setState(() {
        messages.add('أنا: $text');
      });
      messageController.clear();
    } catch (e) {
      setState(() {
        messages.add('فشل إرسال الرسالة');
      });
    }
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
        title: const Text('Joker Chat - Pro'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        messages[index],
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
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
                      hintText: 'اكتب رسالتك هنا...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.deepPurple),
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


