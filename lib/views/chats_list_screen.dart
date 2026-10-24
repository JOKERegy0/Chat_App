import 'package:flutter/material.dart';
import 'supabase_flutter/supabase_flutter.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _chats = [];

  @override
  void initState() {
    super.initState();
    _fetchChats();
  }

  // دالة لجلب المحادثات أو الأصدقاء من قاعدة البيانات
  Future<void> _fetchChats() async {
    try {
      // كمثال، بنجيب المستخدمين المسجلين في النظام عشان نعرضهم كقائمة محادثات
      final response = await _supabase.from('users').select().limit(10);
      
      setState(() {
        _chats = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('خطأ في جلب المحادثات: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KIURA - المحادثات', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // بحث عن مستخدم أو محادثة
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // الانتقال للإعدادات لتعديل الـ Username مثلاً
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
              ? const Center(
                  child: Text(
                    'لا توجد محادثات سابقة، ابدأ دردشة جديدة الآن!',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _chats.length,
                  itemBuilder: (context, index) {
                    final chat = _chats[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blueAccent,
                        child: Text(
                          (chat['username'] ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(chat['username'] ?? 'مستخدم كيورا'),
                      subtitle: Text(chat['email'] ?? chat['phone'] ?? 'متصل الآن'),
                      trailing: const Text(
                        '12:45 م',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      onTap: () {
                        // هنا هنتقل لشاشة الشات الفردي Chat Room Screen لما نخلصها
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // زر لبدء محادثة جديدة
        },
        child: const Icon(Icons.chat),
      ),
    );
  }
}
