import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. التحقق من صيغة الـ Username 
  // (يجب أن يحتوي على رقم أو رمز مميز مثل _ أو . وبطول من 3 لـ 20 خانة)
  bool isValidUsernameFormat(String username) {
    final regex = RegExp(r'^(?=.*[0-9_.])[a-zA-Z0-9_.]{3,20}$');
    return regex.hasMatch(username);
  }

  // 2. التحقق هل الـ Username مستخدم مسبقاً في جدول users
  Future<bool> isUsernameTaken(String username) async {
    try {
      final response = await _supabase
          .from('users')
          .select('id')
          .eq('username', username)
          .maybeSingle();
      
      return response != null; // لو لقينا نتيجة يبقى الاسم محجوز مسبقاً
    } catch (e) {
      print('خطأ أثناء فحص اسم المستخدم: $e');
      return false;
    }
  }

  // 3. دالة التسجيل والتحقق الشاملة وحفظ البيانات في قاعدة البيانات
  Future<Map<String, dynamic>> registerUser({
    required String authMethod, // 'phone', 'email', 'facebook', 'username'
    required String password,
    String? email,
    String? phone,
    String? facebookId,
    String? username,
  }) async {
    try {
      // فحص الـ Username حسب القواعد (إجباري لو مش تليفون، واختياري لو تليفون)
      if (authMethod != 'phone') {
        if (username == null || username.trim().isEmpty) {
          return {'success': false, 'message': 'عذراً، اسم المستخدم إجباري لهذه الطريقة.'};
        }
        if (!isValidUsernameFormat(username)) {
          return {'success': false, 'message': 'اسم المستخدم يجب أن يحتوي على رقم أو رمز مميز (_ أو .) وبطول من 3 لـ 20 خانة.'};
        }
        if (await isUsernameTaken(username)) {
          return {'success': false, 'message': 'عذراً، هذا الاسم مستخدم مسبقاً، اختر غيره.'};
        }
      } else {
        if (username != null && username.trim().isNotEmpty) {
          if (!isValidUsernameFormat(username)) {
            return {'success': false, 'message': 'اسم المستخدم الاختياري غير صالح.'};
          }
          if (await isUsernameTaken(username)) {
            return {'success': false, 'message': 'عذراً، هذا الاسم مستخدم مسبقاً.'};
          }
        }
      }

       // مثال صحيح لكود التسجيل في AuthService
        final response = await supabase.auth.signUp(
          email: email, // أو رقم الهاتف حسب طريقة التسجيل
            password: password,
             data: {
              'username': username, // الـ Trigger سيلتقط هذا الحقل ويحفظه في جدول users أوتوماتيكياً
          },
         );


      return {
        'success': true, 
        'message': 'تم إنشاء الحساب وحفظ البيانات في قاعدة البيانات بنجاح! 🚀'
      };

    } catch (e) {
      return {
        'success': false, 
        'message': 'حدث خطأ غير متوقع: $e'
      };
    }
  }
}

