import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_room_screen.dart';
import 'profile_screen.dart';
import 'statuses_screen.dart';
import '../core/constants/app_config.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  List> _allUsers = [];
  List> _filteredUsers = [];
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(_onSearchChanged);
  }

  // دالة لجلب المستخدمين الحقيقيين من جدول الـ Profiles في Supabase للبحث والإضافة
  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .neq('id', currentUserId ?? ''); // استثناء المستخدم الحالي من القائمة

      setState(() {
        _allUsers = List>.from(response);
        _filteredUsers = _allUsers;
      });
    } catch (e) {
      print('Error fetching users: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _allUsers.where((user) {
        final username = user['username']?.toLowerCase() ?? '';
        final email = user['email']?.toLowerCase() ?? '';
        return username.contains(query) || email.contains(query);
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
        title: Text(
          '${AppConfig.appName} Secure Messenger',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
          // شريط البحث الحقيقي عن الحسابات
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'ابحث عن اسم المستخدم أو البريد...',
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
                : _filteredUsers.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد حسابات مطابقة للبحث.\nابحث بالاسم لبدء محادثة جديدة!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          final username = user['username'] ?? user['email'] ?? 'مستخدم KIURA';
                          
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
                                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                username,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: const Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'انقر للبدء في مراسلة آمنة 🔒',
                                  style: TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ),
                              trailing: const Icon(Icons.chat_bubble_outline, color: Color(0xFF3B82F6)),
                              onTap: () {
                                // الانتقال المباشر لغرفة الشات مع المستخدم المحدد مع تمرير الـ IDs الحقيقية
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatRoomScreen(
                                      chatId: 'chat_${user['id']}',
                                      recipientId: user['id'],
                                      recipientName: username,
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
        child: const Icon(Icons.refresh, color: Colors.white),
        onPressed: _fetchUsers, // زر لتحديث قائمة المستخدمين وجلبهم من السيرفر
      ),
    );
  }
}
