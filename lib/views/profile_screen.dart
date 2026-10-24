import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final _supabase = Supabase.instance.client;
  
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;
  String _currentEmailOrPhone = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // جلب بيانات المستخدم الحالية
  Future<void> _loadUserData() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      setState(() {
        _currentEmailOrPhone = user.email ?? user.phone ?? 'مستخدم كيورا';
      });
    }
  }

  // تحديث اسم المستخدم مع تطبيق قواعد الصيغة وعدم التكرار
  Future<void> _updateUsername() async {
    String newUsername = _usernameController.text.trim();

    if (newUsername.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اسم المستخدم لا يمكن أن يكون فارغاً')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // 1. التحقق من صيغة الـ Username عبر AuthService
    if (!_authService.isValidUsernameFormat(newUsername)) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اسم المستخدم يجب أن يحتوي على رقم أو رمز مميز (_ أو .) وبطول من 3 لـ 20 خانة.')),
      );
      return;
    }

    // 2. التحقق من عدم تكرار الـ Username في قاعدة البيانات
    bool isTaken = await _authService.isUsernameTaken(newUsername);
    if (isTaken) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('عذراً، هذا الاسم مستخدم مسبقاً، اختر اسماً آخر.')),
      );
      return;
    }

    // 3. حفظ التعديل في جدول users
    try {
      final userId = _supabase.auth.currentUser!.id;
      await _supabase.from('users').update({
        'username': newUsername,
      }).eq('id', userId);

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث اسم المستخدم بنجاح! 🎉')),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء التحديث: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي والإعدادات - KIURA'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.person, size: 50, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                _currentEmailOrPhone,
                style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'تعديل اسم المستخدم (Username)',
                hintText: 'يجب أن يحتوي على رقم أو _ أو .',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _updateUsername,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    child: const Text('حفظ التغييرات', style: TextStyle(color: Colors.white)),
                  ),
          ],
        ),
      ),
    );
  }
}
