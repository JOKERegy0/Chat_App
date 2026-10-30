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
  List _chats = [];
  List _filteredChats = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadChats();
    _searchController.addListener(_filterChats);
  }

  Future<void> _loadChats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      setState(() {
        _chats = [];
        _filteredChats = _chats;
      });
    } catch (e) {
      print('Error loading chats: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _filterChats() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredChats = _chats.where((chat) {
        final name = chat['name']?.toLowerCase() ?? '';
        return name.contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'بحث في المحادثات والحسابات...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
                : _filteredChats.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد محادثات حالياً.\nاضغط على زر الإضافة لبدء محادثة جديدة!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredChats.length,
                        itemBuilder: (context, index) {
                          final chat = _filteredChats[index];
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                radius: 26,
                                backgroundColor: const Color(0xFF3B82F6),
                                child: Text(
                                  chat['name'] != null && chat['name'].isNotEmpty ? chat['name'][0] : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                chat['name'] ?? 'مستخدم',
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF3B82F6),
        child: const Icon(Icons.person_add, color: Colors.white),
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
