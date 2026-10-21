import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

void main() {
  // التقاط الأخطاء غير المتوقعة في الفريم وورك لمنع الكراش
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Captured Flutter Error: ${details.exception}');
  };

  // التقاط الأخطاء التي تحصل خارج نطاق الـ UI
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(const ChatApp());
  }, (error, stackTrace) {
    debugPrint('Captured Async Error: $error');
  });
}

class ChatApp extends StatelessWidget {
  const ChatApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Joker Chat',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      // حماية الواجهة من الكراش بصفحة أخطاء مخصصة
      builder: (context, widget) {
        ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 60),
                    const SizedBox(height: 10),
                    const Text(
                      'حدث خطأ غير متوقع في الواجهة',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      errorDetails.exception.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        };
        return widget!;
      },
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
  final List<String> logsAndMessages = [];
  final TextEditingController messageController = TextEditingController();
  WebSocket? channel;
  bool isConnecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      connectToServer();
    });
  }

  void log(String text) {
    if (!mounted) return;
    setState(() {
      logsAndMessages.add(text);
    });
  }

  Future<void> connectToServer() async {
    if (isConnecting) return;
    isConnecting = true;

    log('⏳ [تسجيل]: جاري محاولة الاتصال بالسيرفر...');

    try {
      channel = await WebSocket.connect('wss://chat-app-4hax.onrender.com');
      log('✅ [تسجيل]: تم الاتصال بالسيرفر السحابي بنجاح!');
      isConnecting = false;

      channel!.listen(
        (data) {
          log('📩 الطرف الآخر: $data');
        },
        onError: (error) {
          log('❌ [خطأ اتصال]: $error');
          isConnecting = false;
          _scheduleReconnect();
        },
        onDone: () {
          log('⚠️ [تنبيه]: انقطع الاتصال، جاري إعادة المحاولة خلال 5 ثوانٍ...');
          isConnecting = false;
          _scheduleReconnect();
        },
      );
    } catch (e) {
      log('❌ [خطأ في السيرفر/الشبكة]: $e');
      isConnecting = false;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        connectToServer();
      }
    });
  }

  void sendMessage() {
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    if (channel == null) {
      log('⚠️ [تنبيه]: لا يمكنك الإرسال، غير متصل بالسيرفر حالياً.');
      return;
    }

    try {
      channel!.add(text);
      log('💬 أنا: $text');
      messageController.clear();
    } catch (e) {
      log('❌ [خطأ إرسال]: $e');
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
        title: const Text('Joker Chat - Safe Guard'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: logsAndMessages.length,
              itemBuilder: (context, index) {
                final item = logsAndMessages[index];
                final isError = item.contains('❌') || item.contains('⚠️');
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                  child: Card(
                    color: isError ? Colors.red.shade50 : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 15,
                          color: isError ? Colors.red.shade900 : Colors.black87,
                        ),
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
                      hintText: 'اكتب رسالتك...',
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


