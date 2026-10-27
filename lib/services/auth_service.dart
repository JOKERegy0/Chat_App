import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. التحقق من صيغة الـ Username
  bool isValidUsernameFormat(String username) {
    final regex = RegExp(r'^(?=.*[0-9_.])[a-zA-Z0-9_.]{3,20}$');
    return regex.hasMatch(username);
  }

  // 2. التحقق مما إذا كان الـ Username محجوزاً مسبقاً
  Future<bool> isUsernameTaken(String username) async {
    try {
      final response = await _supabase
          .from('users')
          .select('id')
          .eq('username', username)
          .maybeSingle();

      return response != null; // لو لقينا نتيجة يبقى الاسم محجوز
    } catch (e) {
      print('خطأ أثناء فحص اسم المستخدم: $e');
      return false;
    }
  }

  // دالة مساعدة للتحقق من اسم المستخدم حسب القاعدة
  Future<void> _validateUsernameIfNeeded(String? username, {required bool isMandatory}) async {
    if (isMandatory || (username != null && username.isNotEmpty)) {
      if (username == null || username.trim().isEmpty) {
        throw 'اسم المستخدم إجباري لهذه الطريقة';
      }
      if (!isValidUsernameFormat(username)) {
        throw 'صيغة اسم المستخدم غير صحيحة (يجب أن يحتوي على أرقام أو رموز مثل . أو _ وبطول من 3 لـ 20 خانة)';
      }
      bool taken = await isUsernameTaken(username);
      if (taken) {
        throw 'اسم المستخدم محجوز مسبقاً، اختر اسمآ آخر';
      }
    }
  }

  // 3. التسجيل الأساسي (باسم المستخدم وكلمة المرور فقط بدون إيميل حقيقي)
  Future<void> signUpWithUsernameOnly({
    required String username,
    required String password,
  }) async {
    try {
      await _validateUsernameIfNeeded(username, isMandatory: true);

      // توليد بريد إلكتروني داخلي وهمي ليتوافق مع قاعدة بيانات Supabase Auth
      final String syntheticEmail = '${username.toLowerCase().trim()}@kiura.internal';

      final response = await _supabase.auth.signUp(
        email: syntheticEmail,
        password: password,
        data: {
          'username': username,
        },
      );

      print('تم التسجيل باليوزرنيم بنجاح: ${response.user?.id}');
    } catch (e) {
      print('خطأ أثناء التسجيل باليوزرنيم: $e');
      rethrow;
    }
  }

  // 4. التسجيل بالبريد الإلكتروني (اسم المستخدم إجباري)
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      await _validateUsernameIfNeeded(username, isMandatory: true);

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
        },
      );

      print('تم التسجيل بالبريد بنجاح: ${response.user?.id}');
    } catch (e) {
      print('خطأ أثناء التسجيل بالبريد: $e');
      rethrow;
    }
  }

  // 5. التسجيل برقم الهاتف (اسم المستخدم اختياري)
  Future<void> signUpWithPhone({
    required String phone,
    required String password,
    String? username,
  }) async {
    try {
      await _validateUsernameIfNeeded(username, isMandatory: false);

      final response = await _supabase.auth.signUp(
        phone: phone,
        password: password,
        data: username != null && username.isNotEmpty ? {'username': username} : {},
      );

      print('تم التسجيل بالهاتف بنجاح: ${response.user?.id}');
    } catch (e) {
      print('خطأ أثناء التسجيل بالهاتف: $e');
      rethrow;
    }
  }

  // 6. تسجيل الدخول الشامل باستخدام اسم المستخدم (يدعم اليوزرنيم، الإيميل، أو الهاتف المسجلين)
  Future<AuthResponse> signInWithUsername({
    required String username,
    required String password,
  }) async {
    try {
      // البحث عن بيانات المستخدم المرتبطة بهذا اليوزرنيم في جدول public.users
      final userData = await _supabase
          .from('users')
          .select('email, phone')
          .eq('username', username)
          .maybeSingle();

      if (userData == null) {
        throw 'اسم المستخدم غير موجود';
      }

      final String? email = userData['email'];
      final String? phone = userData['phone'];

      // استخدام البريد (سواء حقيقي أو البريد الداخلي الوهمي للـ يوزرنيم) أو الهاتف لتسجيل الدخول
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        phone: phone,
        password: password,
      );

      print('تم تسجيل الدخول بنجاح: ${response.user?.id}');
      return response;
    } catch (e) {
      print('خطأ أثناء تسجيل الدخول: $e');
      rethrow;
    }
  }

  // 7. تسجيل الدخول المباشر بالإيميل أو الهاتف التقليدي
  Future<AuthResponse> signInDirect({
    required String emailOrPhone,
    required String password,
  }) async {
    try {
      final isEmail = emailOrPhone.contains('@');
      final response = await _supabase.auth.signInWithPassword(
        email: isEmail ? emailOrPhone : null,
        phone: !isEmail ? emailOrPhone : null,
        password: password,
      );
      
      return response;
    } catch (e) {
      print('خطأ أثناء تسجيل الدخول المباشر: $e');
      rethrow;
    }
  }

  // 8. تسجيل الدخول عبر Facebook (OAuth)
  Future<bool> signInWithFacebook() async {
    try {
      final bool response = await _supabase.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: 'io.supabase.kiura://login-callback/',
      );
      
      return response;
    } catch (e) {
      print('خطأ أثناء تسجيل الدخول بـ Facebook: $e');
      rethrow;
    }
  }
}
