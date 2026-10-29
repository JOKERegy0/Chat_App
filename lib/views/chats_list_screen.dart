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
  List> _chats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // جلب المحادثات أو المستخدمين من قاعدة البيانات المحلية أو Supabase
      final localChats = await DatabaseHelper.instance.getPendingMessages();
      
      // محادثات تجريبية افتراضية لضمان ظهور واجهة غنية في حال كانت القائمة فارغة
      _chats = [
        {
          'id': 'chat_001',
          'recipient_id': 'user_001',
          'name': 'أحمد (مطور KIURA)',
          'last_message': 'تم تأمين الـ WebSocket بنجاح يا هندسة 🚀',
          'time': '11:15 ص',
          'unread_count': 2,
          'is_online': true,
        },
        {
          'id': 'chat_002',
          'recipient_id': 'user_002',
          'name': 'محمود',
          'last_message': 'جاهز لتجربة النظام المحلي?',
          'time': 'أمس',
          'unread_count': 0,
          'is_online': false,
        },
      ];
    } catch (e) {
      print('Error loading chats: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'KIURA Secure Messenger',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white70),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white70),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : ListView.builder(
              itemCount: _chats.length,
              itemBuilder: (context, index) {
                final chat = _chats[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: const Color(0xFF3B82F6),
                          child: Text(
                            chat['name'][0],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (chat['is_online'] == true)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF1E293B), width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(
                      chat['name'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        chat['last_message'] ?? '',
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          chat['time'] ?? '',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                        const SizedBox(height: 6),
                        if ((chat['unread_count'] ?? 0) > 0)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF3B82F6),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${chat['unread_count']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatRoomScreen(
                            chatId: chat['id'] ?? 'chat_default',
                            recipientId: chat['recipient_id'] ?? 'user_default',
                            recipientName: chat['name'] ?? 'مستخدم',
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF3B82F6),
        child: const Icon(Icons.chat, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const StatusesScreen()),
          );
        },
      ),
    );
  }
}
