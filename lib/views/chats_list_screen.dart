import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_room_screen.dart';
import 'profile_screen.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  List> _allUsers = [];
  List> _filteredUsers = [];
  bool _isLoading = false;
  String _errorMessage = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      
      // جلب الحسابات مباشرة من جدول profiles
      final response = await Supabase.instance.client
          .from('profiles')
          .select();

      setState(() {
        if (response is List) {
          // استثناء المستخدم الحالي من القائمة الظاهرة للبحث
          _allUsers = List>.from(response);
          _filteredUsers = _allUsers.where((user) => user['id'] != currentUserId).toList();
        } else {
          _allUsers = [];
          _filteredUsers = [];
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'خطأ في جلب الحسابات: $e';
      });
      print('Error fetching users: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    setState(() {
      _filteredUsers = _allUsers.where((user) {
        if (user['id'] == currentUserId) return false;
        final username = (user['username'] ?? '').toString().toLowerCase();
        final email = (user['email'] ?? '').toString().toLowerCase();
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
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
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
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Text(
                          _allUsers.isEmpty 
                              ? 'لا توجد حسابات مسجلة في قاعدة البيانات حالياً.'
                              : 'لا توجد نتائج مطابقة لبحثك.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white54, fontSize: 14),
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
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  'انقر للبدء في مراسلة آمنة 🔒',
                                  style: TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ),
                              trailing: const Icon(Icons.chat_bubble_outline, color: Color(0xFF3B82F6)),
                              onTap: () {
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
        onPressed: _fetchUsers,
      ),
    );
  }
}
