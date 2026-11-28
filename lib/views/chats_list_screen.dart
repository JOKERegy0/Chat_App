import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/database/db_helper.dart';
import '../services/chat_service.dart';
import 'chat_room_screen.dart';
import 'profile_screen.dart';
import 'statuses_screen.dart'; // شاشة الحالات الموجودة لديك

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  List _searchResults = [];
  bool _isLoading = false;
  String _errorMessage = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  int _searchSeq = 0;
  StreamSubscription<Map<String, dynamic>>? _incomingSub;
  StreamSubscription<String>? _changesSub;
  Timer? _refreshTimer;

  // the conversations saved on this phone (shown when the search box is empty)
  List<Map<String, dynamic>> _conversations = [];
  final Map<String, String> _peerNames = {};
  bool _loadingConversations = true;
  bool _fetchingNames = false;
  Timer? _snackTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);

    // one connection for the whole app, started as soon as the user is logged in
    ChatService.instance.start();
    _incomingSub = ChatService.instance.incomingMessages.listen(_onIncomingMessage);

    _loadConversations();
    _changesSub = ChatService.instance.changes.listen((_) => _scheduleRefresh());
  }

  String _peerIdOf(String chatId) => chatId.startsWith('chat_') ? chatId.substring(5) : '';

  // many events can arrive together (a batch of queued messages): refresh once
  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 250), _loadConversations);
  }

  Future<void> _loadConversations() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;

    final rows = await DatabaseHelper.instance.getConversations(myId);
    final list = rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();

    // names remembered on this phone: the list can show up at once, even offline
    if (_peerNames.isEmpty) {
      _peerNames.addAll(await DatabaseHelper.instance.getPeerNames());
    }

    if (!mounted) return;
    setState(() {
      _conversations = list;
      _loadingConversations = false;
    });

    _fetchMissingNames(list); // in the background, the list does not wait for it
  }

  Future<void> _fetchMissingNames(List<Map<String, dynamic>> list) async {
    if (_fetchingNames) return;
    final missing = list
        .map((c) => _peerIdOf(c['chat_id'] as String))
        .where((id) => id.isNotEmpty && !_peerNames.containsKey(id))
        .toSet()
        .toList();
    if (missing.isEmpty) return;

    _fetchingNames = true;
    try {
      final names = await Future.wait(missing.map(ChatService.instance.lookupUsername));
      var changed = false;
      for (var i = 0; i < missing.length; i++) {
        if (names[i] == 'مستخدم KIURA') continue; // offline: try again next time
        _peerNames[missing[i]] = names[i];
        await DatabaseHelper.instance.savePeerName(missing[i], names[i]);
        changed = true;
      }
      if (changed && mounted) setState(() {});
    } finally {
      _fetchingNames = false;
    }
  }

  String _formatChatTime(dynamic timestamp) {
    final parsed = DateTime.tryParse(timestamp?.toString() ?? '');
    if (parsed == null) return '';
    final t = parsed.toLocal();
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    return '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}';
  }

  void _openChat(String userId, String username) {
    _snackTimer?.cancel();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatRoomScreen(
          chatId: 'chat_$userId',
          recipientId: userId,
          recipientName: username,
        ),
      ),
    ).then((_) => _loadConversations());
  }

  // a message arrived while this screen is on top: tell the user who sent it
  Future<void> _onIncomingMessage(Map<String, dynamic> msg) async {
    if (msg['chat_id'] == ChatService.instance.activeChatId) return;
    final senderId = (msg['sender_id'] as String?) ?? '';
    if (senderId.isEmpty) return;

    final name = await ChatService.instance.lookupUsername(senderId);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('رسالة جديدة من $name'),
          action: SnackBarAction(label: 'فتح', onPressed: () => _openChat(senderId, name)),
        ),
      );

    _snackTimer?.cancel();
    _snackTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    });
  }

  void _onSearchTextChanged() {
    _debounce?.cancel();
    if (_searchController.text.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
        _errorMessage = '';
      });
      return;
    }
    setState(() => _isLoading = true);
    _debounce = Timer(const Duration(milliseconds: 350), _runSearch);
  }

  // 🔍 البحث عن المستخدمين بالاسم (أسماء تبدأ بما كتبته)
  Future<void> _runSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final seq = ++_searchSeq;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final client = Supabase.instance.client;
      final myId = client.auth.currentUser?.id;
      // "_" and "%" are wildcards in ILIKE, so they are escaped
      final escaped = query.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}');

      final base = client.from('profiles').select('id, username').ilike('username', '$escaped%');
      final results = await (myId == null ? base : base.neq('id', myId)).limit(20);

      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _errorMessage = 'تعذّر البحث، تأكد من الإنترنت وحاول مرة أخرى.';
      });
    } finally {
      if (mounted && seq == _searchSeq) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _incomingSub?.cancel();
    _changesSub?.cancel();
    _refreshTimer?.cancel();
    _snackTimer?.cancel();
    _searchController.dispose();
    // this screen only exists while logged in, so closing it means logging out
    ChatService.instance.stop();
    super.dispose();
  }

  Widget _buildConversationsList() {
    if (_loadingConversations) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)));
    }
    if (_conversations.isEmpty) {
      return const Center(
        child: Text(
          '🔒 اكتب اسم المستخدم في الأعلى للبحث والبدء بمراسلة آمنة',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
      );
    }

    final myId = Supabase.instance.client.auth.currentUser?.id;
    return ListView.builder(
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final chat = _conversations[index];
        final peerId = _peerIdOf(chat['chat_id'] as String);
        final name = _peerNames[peerId] ?? 'مستخدم KIURA';
        final unread = (chat['unread'] as int?) ?? 0;
        final isMine = chat['sender_id'] == myId;
        final preview = (chat['content'] as String?) ?? '';

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF3B82F6),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                isMine ? 'أنت: $preview' : preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unread > 0 ? Colors.white : Colors.white54,
                  fontSize: 13,
                  fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatChatTime(chat['timestamp']),
                  style: TextStyle(
                    color: unread > 0 ? const Color(0xFF3B82F6) : Colors.white38,
                    fontSize: 11,
                  ),
                ),
                if (unread > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            onTap: peerId.isEmpty ? null : () => _openChat(peerId, name),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'KIURA Secure Messenger',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          // 1. زر الحالة (Statuses)
          IconButton(
            icon: const Icon(Icons.amp_stories_rounded, color: Colors.blueAccent),
            tooltip: 'الحالات والقصص',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StatusesScreen()),
              );
            },
          ),
          // 2. زر الملف الشخصي (Profile)
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white70),
            tooltip: 'الملف الشخصي',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          // 3. زر الإعدادات (Settings)
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            tooltip: 'الإعدادات',
            onPressed: () {
              // يمكنك ربطها بشاشة الإعدادات لاحقاً أو عرض رسالة
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('إعدادات KIURA قيد تطوير الحماية التامة 🔒')),
              );
            },
          ),
          // 4. زر تسجيل الخروج (Logout)
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'تسجيل الخروج',
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
                hintText: 'ابحث عن اسم المستخدم للبدء...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
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
                : _searchController.text.trim().isEmpty
                    ? _buildConversationsList()
                    : _searchResults.isEmpty
                        ? const Center(
                            child: Text(
                              'لا توجد نتائج مطابقة لبحثك.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white54, fontSize: 14),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final user = _searchResults[index];
                              final username = user['username'] ?? 'مستخدم KIURA';
                              final userId = user['id'] ?? '';
                              
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
                                    if (userId.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('خطأ: معرف المستخدم غير متوفر')),
                                      );
                                      return;
                                    }
                                    _openChat(userId, username);
                                  },
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
