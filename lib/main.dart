import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'views/signup_screen.dart';
import 'views/chats_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تشغيل فحص الأمان والسلامة عند الإقلاع
  try {
    await SecurityEngine.initializeSecurity();
  } catch (e) {
    print('تنبيه أمني: $e');
  }

  // تهيئة Supabase بالبيانات الأساسية
  await Supabase.initialize(
    url: 'https://dymrernfuorzmbcaaocy.supabase.co',
    anonKey: 'sb_publishable_OZRyylmfNPqP99y7PlT32Q_s-0YyJ9z',
  );

  runApp(const KiuraApp());
}

class KiuraApp extends StatelessWidget {
  const KiuraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KIURA',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        useMaterial3: true,
        fontFamily: 'Cairo',
      ),
      // التوجيه الذكي الفوري المعتمد على حالة المصادقة
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null) {
            return const ChatsListScreen();
          }
          return const SignupScreen();
        },
      ),
    );
  }
}
