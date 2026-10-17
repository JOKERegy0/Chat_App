import 'dart:io';
import 'dart:convert';
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
      title: 'Offline Chat',
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
  Socket? socket;
  List<String> messages = [];
  final TextEditingController messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    connectToServer();
  }

  void connectToServer() async {
    try {
      // الاتصال بالسيرفر المحلي (10.0.2.2 للمحاكي، أو آي بي الكمبيوتر لو على موبايل حقيقي)
      socket = await Socket.connect('10.0.2.2', 3000);
      setState(() {
        messages.add('تم الاتصال بالسيرفر المحلي بنجاح!');
      });

      socket!.listen((data) {
        setState(() {
          messages.add('الطرف الآخر: ${utf8.decode(data)}');
        });
      }, onError: (error) {
        setState(() {
          messages.add('خطأ في الاتصال: $error');
        });
      }, onDone: () {
        setState(() {
          messages.add('انقطع الاتصال بالسيرفر');
        });
      });
    } catch (e) {
      setState(() {
        messages.add('فشل الاتصال بالسيرفر: تأكد أن السيرفر يعمل');
      });
    }
  }

  void sendMessage() {
    if (messageController.text.isNotEmpty && socket != null) {
      socket!.write(messageController.text);
      setState(() {
        messages.add('أنا: ${messageController.text}');
      });
      messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('شات محلي أوفلاين')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: ListTile(
                    title: Text(messages[index]),
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
                      hintText: 'اكتب رسالتك...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
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