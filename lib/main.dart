import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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

class _ChatScreenState extends State<ChatScreen > {
  List<String> messages = [];
  final TextEditingController messageController = TextEditingController();
  late WebSocketChannel channel;

  @override
  void initState() {
    super.initState();
    connectToServer();
  }

  void connectToServer() {
    try {
      channel = WebSocketChannel.connect(
        Uri.parse('wss://chat-app-4hax.onrender.com'),
      );

      setState(() {
        messages.add('تم الاتصال بالسيرفر السحابي بنجاح!');
      });

      channel.stream.listen(
        (data) {
          setState(() {
            messages.add('الطرف الآخر: $data');
          });
        },
        onError: (error) {
          setState(() {
            messages.add('خطأ في الاتصال: $error');
          });
        },
        onDone: () {
          setState(() {
            messages.add('انقطع الاتصال بالسيرفر');
          });
        },
      );
    } catch (e) {
      setState(() {
        messages.add('فشل الاتصال بالسيرفر: تأكد أن السيرفر يعمل');
      });
    }
  }

  void sendMessage() {
    if (messageController.text.isNotEmpty) {
      channel.sink.add(messageController.text);
      setState(() {
        messages.add('أنا: ${messageController.text}');
      });
      messageController.clear();
    }
  }

  @override
  void dispose() {
    channel.sink.close();
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

