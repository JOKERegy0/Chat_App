import 'package:flutter/material.dart';
import 'package:kiura/services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final AuthService _authService = AuthService();

  // حالة الشاشة: false = إنشاء حساب، true = تسجيل دخول
  bool _isLoginMode = false;

  // طريقة التسجيل في حالة إنشاء الحساب ('username', 'email', 'phone')
  String _selectedMethod = 'username';

  // الـ Controllers للحقول
  final _usernameController = TextEditingController();
  final _identifierController = TextEditingController(); // للإيميل أو الهاتف أو اليوزرنيم في الدخول
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  // دالة تنفيذ العملية (تسجيل أو دخول)
  Future<void> _handleSubmit() async {
    setState(() => _isLoading = true);
    try {
      final password = _passwordController.text.trim();
      final username = _usernameController.text.trim();
      final identifier = _identifierController.text.trim();

      if (_isLoginMode) {
        // وضع تسجيل الدخول
        if (identifier.contains('@') || identifier.contains(RegExp(r'^[0-9+]+$'))) {
          await _authService.signInDirect(emailOrPhone: identifier, password: password);
        } else {
          await _authService.signInWithUsername(username: identifier, password: password);
        }
        _showToast('تم تسجيل الدخول بنجاح! 🚀', Colors.green);
        // TODO: التنقل لشاشة الشات الرئيسية
      } else {
        // وضع إنشاء حساب جديد
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
      }
    } catch (e) {
      _showToast('خطأ: $e', Colors.redAccent);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // تسجيل الدخول بـ Facebook
  Future<void> _handleFacebookLogin() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithFacebook();
    } catch (e) {
      _showToast('خطأ في فيسبوك: $e', Colors.redAccent);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showToast(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // خلفية داكنة احترافية (Dark Slate)
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // شعار التطبيق أو الهوية البصرية
                const Text(
                  'KIURA',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF38BDF8), // لون سماوي مميز
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLoginMode ? 'مرحباً بك مجدداً في عالم المحادثات الآمنة' : 'انضم إلينا وابدأ التواصل بلا حدود',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 32),

                // اختيار طريقة التسجيل (تظهر فقط في وضع إنشاء الحساب)
                if (!_isLoginMode) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildMethodTab('يوزرنيم فقط', 'username'),
                      const SizedBox(width: 8),
                      _buildMethodTab('إيميل', 'email'),
                      const SizedBox(width: 8),
                      _buildMethodTab('هاتف', 'phone'),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // حقل اسم المستخدم (إجباري في التسجيل باليوزرنيم/الإيميل، اختياري للهاتف، ومخفي في الدخول لو هيدخل بالإيميل المباشر)
                if (!_isLoginMode && _selectedMethod != 'phone') ...[
                  _buildTextField(
                    controller: _usernameController,
                    label: 'اسم المستخدم (Username)',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                ] else if (!_isLoginMode && _selectedMethod == 'phone') ...[
                  _buildTextField(
                    controller: _usernameController,
                    label: 'اسم المستخدم (اختياري)',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                ],

                // حقل البريد/الهاتف/اليوزرنيم (حسب الوضع)
                _buildTextField(
                  controller: _identifierController,
                  label: _isLoginMode 
                      ? 'اسم المستخدم أو البريد أو الهاتف' 
                      : (_selectedMethod == 'email' ? 'البريد الإلكتروني' : (_selectedMethod == 'phone' ? 'رقم الهاتف' : 'اسم المستخدم')),
                  icon: _isLoginMode ? Icons.account_circle_outlined : (_selectedMethod == 'email' ? Icons.email_outlined : Icons.phone_outlined),
                ),
                const SizedBox(height: 16),

                // حقل كلمة المرور
                _buildTextField(
                  controller: _passwordController,
                  label: 'كلمة المرور',
                  icon: Icons.lock_outline,
                  isPassword: true,
                ),
                const SizedBox(height: 24),

                // زر التنفيذ الأساسي
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _isLoginMode ? 'تسجيل الدخول' : 'إنشاء الحساب',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 16),

                // فاصل أو
                const Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white24)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('أو', style: TextStyle(color: Colors.white54)),
                    ),
                    Expanded(child: Divider(color: Colors.white24)),
                  ],
                ),
                const SizedBox(height: 16),

                // زر تسجيل الدخول بـ Facebook
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleFacebookLogin,
                  icon: const Icon(Icons.facebook, color: Colors.blueAccent),
                  label: const Text('المتابعة باستخدام فيسبوك', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),

                // زر التبديل بين الدخول وإنشاء حساب
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isLoginMode ? 'ليس لديك حساب؟' : 'لديك حساب بالفعل؟',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLoginMode = !_isLoginMode;
                        });
                      },
                      child: Text(
                        _isLoginMode ? 'إنشاء حساب جديد' : 'تسجيل الدخول',
                        style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // تصميم تبويبات اختيار طريقة التسجيل
  Widget _buildMethodTab(String title, String method) {
    bool isSelected = _selectedMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMethod = method),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? const Color(0xFF38BDF8) : Colors.transparent),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // تصميم حقول الإدخال الموحدة
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: Color(0xFF38BDF8)),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
        ),
      ),
    );
  }
}
