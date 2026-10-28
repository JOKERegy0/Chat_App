import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kiura/services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final AuthService _authService = AuthService();

  bool _isLoginMode = false;
  String _selectedMethod = 'username'; // 'username', 'email', 'phone'

  final _usernameController = TextEditingController();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  // الانتقال الشامل لشاشة المحادثات بعد النجاح
  void _navigateToChats() {
    // استبدل ChatListScreen بشاشة المحادثات الرئيسية لديك في المشروع
    // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ChatListScreen()));
    _showToast('تم الانتقال لشاشة المحادثات بنجاح! 🚀', Colors.green);
  }

  Future<void> _handleSubmit() async {
    setState(() => _isLoading = true);
    try {
      final password = _passwordController.text.trim();
      final username = _usernameController.text.trim();
      final identifier = _identifierController.text.trim();

      if (_isLoginMode) {
        if (identifier.contains('@') || identifier.contains(RegExp(r'^[0-9+]+$'))) {
          await _authService.signInDirect(emailOrPhone: identifier, password: password);
        } else {
          await _authService.signInWithUsername(username: identifier, password: password);
        }
        _showToast('تم تسجيل الدخول بنجاح! 🚀', Colors.green);
        _navigateToChats();
      } else {
        if (_selectedMethod == 'username') {
          await _authService.signUpWithUsernameOnly(
            username: username,
            password: password,
          );
        } else if (_selectedMethod == 'email') {
          await _authService.signUpWithEmail(
            email: identifier,
            password: password,
            username: username,
          );
        } else if (_selectedMethod == 'phone') {
          await _authService.signUpWithPhone(
            phone: identifier,
            password: password,
            username: username.isEmpty ? null : username,
          );
        }
        _showToast('تم إنشاء الحساب بنجاح! أهلاً بك في KIURA ✨', Colors.green);
        _navigateToChats();
      }
    } catch (e) {
      _showToast('خطأ: $e', Colors.redAccent);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleFacebookLogin() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithFacebook();
      _navigateToChats();
    } catch (e) {
      _showToast('خطأ في فيسبوك: $e', Colors.redAccent);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showToast(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // شعار التطبيق
                  const Text(
                    'KIURA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLoginMode ? 'مرحباً بك مجدداً في عالم المحادثات الآمنة' : 'انضم إلينا وابدأ التواصل بلا حدود',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 28),

                  // تأثير الزجاج السائل (Glassmorphism Container)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // اختيار طريقة التسجيل بأيقونات حديثة
                            if (!_isLoginMode) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildGlassTab('يوزرنيم', Icons.alternate_route_rounded, 'username'),
                                  const SizedBox(width: 8),
                                  _buildGlassTab('إيميل', Icons.mark_email_unread_rounded, 'email'),
                                  const SizedBox(width: 8),
                                  _buildGlassTab('هاتف', Icons.phone_iphone_rounded, 'phone'),
                                ],
                              ),
                              const SizedBox(height: 20),
                            ],

                            // حقل اسم المستخدم
                            if (!_isLoginMode && _selectedMethod != 'phone') ...[
                              _buildGlassTextField(
                                controller: _usernameController,
                                label: 'اسم المستخدم (Username)',
                                icon: Icons.alternate_email_rounded,
                              ),
                              const SizedBox(height: 16),
                            ] else if (!_isLoginMode && _selectedMethod == 'phone') ...[
                              _buildGlassTextField(
                                controller: _usernameController,
                                label: 'اسم المستخدم (اختياري)',
                                icon: Icons.person_outline_rounded,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // حقل المعرف الأساسي (إيميل، هاتف، أو يوزرنيم)
                            _buildGlassTextField(
                              controller: _identifierController,
                              label: _isLoginMode 
                                  ? 'اسم المستخدم أو البريد أو الهاتف' 
                                  : (_selectedMethod == 'email' 
                                      ? 'البريد الإلكتروني الحقيقي' 
                                      : (_selectedMethod == 'phone' ? 'رقم الهاتف' : 'اسم المستخدم الفريد')),
                              icon: _isLoginMode 
                                  ? Icons.fingerprint_rounded 
                                  : (_selectedMethod == 'email' 
                                      ? Icons.email_outlined 
                                      : (_selectedMethod == 'phone' ? Icons.phone_outlined : Icons.alternate_email_rounded)),
                            ),
                            const SizedBox(height: 16),

                            // حقل كلمة المرور
                            _buildGlassTextField(
                              controller: _passwordController,
                              label: 'كلمة المرور الآمنة',
                              icon: Icons.lock_outline_rounded,
                              isPassword: true,
                            ),
                            const SizedBox(height: 24),

                            // زر التنفيذ الرئيسي بتدرج لون زجاجي
                            Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0284C7).withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : Text(
                                        _isLoginMode ? 'تسجيل الدخول' : 'إنشاء الحساب الان',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // فاصل أو
                  Row(
                    children: [
                      const Expanded(child: Divider(color: Colors.white24)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('أو المتابعة السريعة', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ),
                      const Expanded(child: Divider(color: Colors.white24)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // زر فيسبوك بزجاج سائل فاخر
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _handleFacebookLogin,
                        icon: const Icon(Icons.facebook_rounded, color: Color(0xFF60A5FA)),
                        label: const Text('المتابعة باستخدام فيسبوك', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.white.withOpacity(0.04),
                          side: BorderSide(color: Colors.white.withOpacity(0.15)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // زر التبديل بين الدخول وإنشاء حساب
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLoginMode ? 'ليس لديك حساب في Kiura؟' : 'لديك حساب بالفعل؟',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLoginMode = !_isLoginMode;
                          });
                        },
                        child: Text(
                          _isLoginMode ? 'انضم الآن' : 'تسجيل الدخول',
                          style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // تبويب الأيقونات والزجاج السائل لاختيار الطريقة
  Widget _buildGlassTab(String title, IconData icon, String method) {
    bool isSelected = _selectedMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMethod = method),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0284C7).withOpacity(0.8) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF38BDF8) : Colors.white.withOpacity(0.1),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.white60, size: 20),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // حقل إدخال زجاجي متطور
  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF38BDF8), size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
        ),
      ),
    );
  }
}
