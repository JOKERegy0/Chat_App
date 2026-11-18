import 'package:supabase_flutter/supabase_flutter.dart';

/// An error whose text can be shown to the user as is.
class KiuraAuthError implements Exception {
  final String message;
  KiuraAuthError(this.message);

  @override
  String toString() => message;
}

class AuthService {
  static const String _functionName = 'kiura-auth';
  static const String _redirectUrl = 'io.supabase.kiura://login-callback/';
  static final RegExp _usernameRegex = RegExp(r'^[A-Za-z0-9_.-]{3,20}$');

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Removes spaces and the invisible direction marks that Arabic keyboards can insert.
  static String _clean(String s) =>
      s.replaceAll(RegExp(r'[\s\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]'), '');

  // ---------- username helpers (also used by the profile screen) ----------

  bool isValidUsernameFormat(String username) => _usernameRegex.hasMatch(username);

  Future<bool> isUsernameTaken(String username) async {
    try {
      // "_" and "%" are wildcards in ILIKE, so they are escaped
      final escaped = username.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}');
      final rows = await _supabase
          .from('profiles')
          .select('username')
          .ilike('username', escaped)
          .limit(5);
      final wanted = username.toLowerCase();
      return rows.any((r) => (r['username'] as String?)?.toLowerCase() == wanted);
    } catch (_) {
      return false;
    }
  }

  // ---------- calls to the kiura-auth edge function ----------

  String _messageFor(String code) {
    switch (code) {
      case 'invalid_username':
        return 'اسم المستخدم يجب أن يكون من 3 إلى 20 خانة (حروف إنجليزية وأرقام و . _ -).';
      case 'weak_password':
        return 'كلمة المرور يجب أن تكون من 6 إلى 72 خانة.';
      case 'username_taken':
        return 'اسم المستخدم محجوز مسبقًا، اختر اسمًا آخر.';
      case 'invalid_credentials':
        return 'اسم المستخدم أو كلمة المرور غير صحيحة.';
      case 'email_not_confirmed':
        return 'يرجى تأكيد بريدك الإلكتروني أولاً من الرسالة التي وصلتك.';
      case 'rate_limited':
        return 'محاولات كثيرة. انتظر قليلاً ثم حاول مرة أخرى.';
      default:
        return 'حدث خطأ غير متوقع، حاول مرة أخرى.';
    }
  }

  Future<Map<String, dynamic>> _callAuthFunction(Map<String, dynamic> body) async {
    try {
      final res = await _supabase.functions.invoke(_functionName, body: body);
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      throw KiuraAuthError('رد غير متوقع من الخادم.');
    } on FunctionException catch (e) {
      final details = e.details;
      final code = (details is Map && details['error'] is String)
          ? details['error'] as String
          : 'unknown';
      throw KiuraAuthError(_messageFor(code));
    } on KiuraAuthError {
      rethrow;
    } catch (_) {
      throw KiuraAuthError('تعذّر الاتصال بالخادم، تأكد من الإنترنت وحاول مرة أخرى.');
    }
  }

  /// Uses the session returned by the server. Returns false if there was none.
  Future<bool> _applySession(Map<String, dynamic> data) async {
    final session = data['session'];
    if (session is Map && session['refresh_token'] is String) {
      await _supabase.auth.setSession(session['refresh_token'] as String);
      return true;
    }
    return false;
  }

  // ---------- public API ----------

  /// Username-only account: created and signed in by the server, no email needed.
  Future<void> signUpWithUsername({
    required String username,
    required String password,
  }) async {
    final name = _clean(username);
    if (!isValidUsernameFormat(name)) throw KiuraAuthError(_messageFor('invalid_username'));
    if (password.length < 6) throw KiuraAuthError(_messageFor('weak_password'));

    final data = await _callAuthFunction({
      'action': 'signup_username',
      'username': name,
      'password': password,
    });

    if (!await _applySession(data)) {
      // account exists but the server did not return a session: sign in normally
      await signIn(identifier: name, password: password);
    }
  }

  /// Real-email account: Supabase sends a confirmation email.
  /// Returns true when the user still has to confirm the email before logging in.
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    final name = _clean(username);
    if (!isValidUsernameFormat(name)) throw KiuraAuthError(_messageFor('invalid_username'));
    if (password.length < 6) throw KiuraAuthError(_messageFor('weak_password'));
    if (await isUsernameTaken(name)) throw KiuraAuthError(_messageFor('username_taken'));

    final cleanEmail = _clean(email).toLowerCase();
    if (!cleanEmail.contains('@')) {
      throw KiuraAuthError('البريد الإلكتروني غير صالح.');
    }

    try {
      final response = await _supabase.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {'username': name},
        emailRedirectTo: _redirectUrl,
      );
      return response.session == null;
    } on AuthException catch (e) {
      throw KiuraAuthError(_mapAuthMessage(e));
    }
  }

  /// Login with a username or a real email. The server finds the right account.
  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    final data = await _callAuthFunction({
      'action': 'login',
      'identifier': _clean(identifier),
      'password': password,
    });

    if (!await _applySession(data)) {
      throw KiuraAuthError(_messageFor('unknown'));
    }
  }

  String _mapAuthMessage(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('rate limit')) {
      return 'تم تجاوز عدد رسائل التأكيد المسموح. انتظر قليلاً ثم حاول مرة أخرى.';
    }
    if (m.contains('already')) return 'هذا البريد مسجل بالفعل.';
    if (m.contains('password')) return 'كلمة المرور غير مقبولة (6 خانات على الأقل).';
    if (m.contains('email') && m.contains('invalid')) {
      return 'البريد الإلكتروني غير مقبول من الخادم: ${e.message}';
    }
    return 'تعذّر إنشاء الحساب: ${e.message}';
  }
}
