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

   @override
  void initState() {
    super.initState();
    // الانتظار لحين اكتمال بناء الواجهة تماماً قبل بدء الاتصال لمنع الانهيار
    WidgetsBinding.instance.addPostFrameCallback((_) {
      connectToServer();
    });
  }

  bool isConnecting = false;

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
        messages.add('تم الاتصال بالسيرفر بنجاح!');
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
            messages.add('خطأ في الاتصال');
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
        messages.add('فشل الاتصال بالسيرفر، تأكد أن السيرفر يعمل');
        isConnecting = false;
      });
    }
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
