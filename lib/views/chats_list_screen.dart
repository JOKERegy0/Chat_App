import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_room_screen.dart';
import 'profile_screen.dart';
import 'statuses_screen.dart';
import '../data/database/db_helper.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChatsFromLocalDb();
  }

  // جلب المحادثات الحقيقية المخزنة محلياً بنظام Local-First
  Future<void> _loadChatsFromLocalDb() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final chatsData = await db.query('chats', orderBy: 'updated_at DESC');
      if (mounted) {
        setState(() {
          _chats = chatsData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('KIURA - المحادثات', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          // زر البحث
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF38BDF8)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('خاصية البحث قيد التفعيل')),
              );
            },
          ),
          // زر الانتقال للحالات اليومية
          IconButton(
            icon: const Icon(Icons.data_usage_rounded, color: Color(0xFF38BDF8)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatusesScreen()),
              );
            },
          ),
          // زر الإعدادات والملف الشخصي (مربوط تماماً)
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Color(0xFF38BDF8)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : _chats.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.white.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      const Text(
                        'لا توجد محادثات نشطة حالياً\nابحث عن أصدقائك وابدأ التواصل الآمن',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _chats.length,
                  itemBuilder: (context, index) {
                    final chat = _chats[index];
                    final name = chat['name'] ?? 'مستخدم كيورا';
                    final lastMessage = chat['last_message'] ?? 'اضغط لبدء المحادثة';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFF0284C7),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'K',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Text(
                        lastMessage,
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        'نشط',
                        style: TextStyle(color: Colors.greenAccent.withOpacity(0.8), fontSize: 11),
                      ),
                      onTap: () {
                        // الانتقال لغرفة الدردشة الفورية مع تمرير بيانات المستخدم
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatRoomScreen(
                              recipientId: chat['id'] ?? 'peer_id',
                              recipientName: name,
                              chatId: chat['id'] ?? 'chat_default',
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF38BDF8),
        child: const Icon(Icons.add_comment_rounded, color: Color(0xFF0F172A)),
        onPressed: () {
          // نافذة أو إجراء لبدء محادثة جديدة
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ميزة إضافة محادثة جديدة قادمة بقوة!')),
          );
        },
      ),
    );
  }
}
