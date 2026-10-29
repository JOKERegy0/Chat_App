import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WebSocketService {
  WebSocketChannel? _channel;

  void connect(String userId) async {
    // جلب التوكن من جلسة Supabase الحالية
    final session = Supabase.instance.client.auth.currentSession;
    final accessToken = session?.accessToken ?? '';
    
    // إصدار التطبيق المطابق لشرط السيرفر
    const String appVersion = '1.0.0+1'; 

    // بناء الرابط مع تمرير الإصدار والتوكن الإلزامي
    final uri = Uri.parse('wss://chat-app-4hax.onrender.com?user_id=$userId&version=$appVersion&token=$accessToken');

    try {
      _channel = WebSocketChannel.connect(uri);
      print('تم الاتصال بسيرفر المحادثات الفورية بنجاح وبشكل آمن 🚀');
    } catch (e) {
      print('خطأ في الاتصال بالـ WebSocket: $e');
    }
  }

  void disconnect() {
    _channel?.sink.close();
  }
}
