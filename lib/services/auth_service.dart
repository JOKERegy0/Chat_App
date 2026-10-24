import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. التحقق من صيغة الـ Username (يحتوي على رقم أو رمز مميز)
  bool isValidUsernameFormat(String username) {
    RegExp regex = RegExp(r'^(?=.*[0-9_.])[a-zA-Z0-9_.]{3,20}$');
    return regex.hasMatch(username);
  }

  // 2. التحقق هل الـ Username مستخدم قبل كده في قاعدة البيانات ولا لأ
  Future<bool> isUsernameTaken(String username) async {
    try {
      final response = await _supabase
          .from('users')
          .select('id')
          .eq('username', username)
          .maybeSingle();

      return response != null; // لو طلع فيه نتيجة يبقى الاسم مأخوذ فعلاً
    } catch (e) {
      print('خطأ في فحص اسم المستخدم: $e');
      return false;
    }
  }
}



  // 1. تسجيل الدخول بواسطة Google
  Future<bool> signInWithGoogle() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.kiura://login-callback/', // رابط التوجيه للتطبيق
      );
      return true;
    } catch (e) {
      print("❌ خطأ في تسجيل دخول جوجل: $e");
      return false;
    }
  }

  // 2. تسجيل الدخول بواسطة Facebook
  Future<bool> signInWithFacebook() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: 'io.supabase.kiura://login-callback/',
      );
      return true;
    } catch (e) {
      print("❌ خطأ في تسجيل دخول فيسبوك: $e");
      return false;
    }
  }

  // 3. تسجيل الدخول برقم الهاتف (إرسال رمز التحقق OTP)
  Future<bool> signInWithPhone(String phoneNumber) async {
    try {
      await _supabase.auth.signInWithPhone(
        phoneNumber,
      );
      print("📱 تم إرسال رمز التحقق إلى الرقم: $phoneNumber");
      return true;
    } catch (e) {
      print("❌ خطأ في إرسال رمز الهاتف: $e");
      return false;
    }
  }

  // التحقق من الرمز المدخل للهاتف
  Future<bool> verifyPhoneOTP(String phoneNumber, String otpToken) async {
    try {
      final response = await _supabase.auth.verifyOTP(
        phone: phoneNumber,
        token: otpToken,
        type: OtpType.sms,
      );
      return response.session != null;
    } catch (e) {
      print("❌ خطأ في التحقق من الرمز: $e");
      return false;
    }
  }
}
