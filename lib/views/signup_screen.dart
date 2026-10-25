import 'package:flutter/material.dart';
import 'services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  String _selectedAuthMethod = 'email';
  bool _isLoading = false;

  void _submitRegistration() async {
    setState(() {
      _isLoading = true;
    });

    var result = await _authService.registerUser(
      authMethod: _selectedAuthMethod,
      password: _passwordController.text.trim(),
      email: _selectedAuthMethod == 'email' ? _emailController.text.trim() : null,
      phone: _selectedAuthMethod == 'phone' ? _phoneController.text.trim() : null,
      username: _usernameController.text.trim(),
    );

    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']),
        backgroundColor: result['success'] ? Colors.green : Colors.red,
      ),
    );

    if (result['success']) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatsListScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء حساب جديد - KIURA')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            DropdownButton<String>(
              value: _selectedAuthMethod,
              items: const [
                DropdownMenuItem(value: 'email', child: Text('التسجيل بالبريد الإلكتروني')),
                DropdownMenuItem(value: 'phone', child: Text('التسجيل برقم الهاتف')),
                DropdownMenuItem(value: 'username', child: Text('التسجيل باسم المستخدم')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedAuthMethod = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            if (_selectedAuthMethod == 'email')
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
              ),
            if (_selectedAuthMethod == 'phone')
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'رقم الهاتف'),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'كلمة المرور'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: _selectedAuthMethod == 'phone'
                    ? 'اسم المستخدم (اختياري)'
                    : 'اسم المستخدم (إجباري - يجب أن يحتوي على رقم أو رمز _ .)',
              ),
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _submitRegistration,
                    child: const Text('تسجيل الحساب'),
                  ),
          ],
        ),
      ),
    );
  }
}
