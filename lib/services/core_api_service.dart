import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class CoreApiService {
  static const String internalServiceSecret = "KIURA_INTERNAL_SERVICE_KEY_2026";

  // دالة البحث الذكي عبر السيرفر المركزي
  static Future<List<dynamic>> searchUsers({
    required String searchQuery,
    required String currentUsername,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.coreService}/api/core/search-users');
      print('🌐 جاري إرسال طلب البحث إلى: $uri للكلمة: $searchQuery');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-service-secret': internalServiceSecret,
        },
        body: jsonEncode({
          'search_query': searchQuery,
          'current_user': currentUsername,
        }),
      );

      print('📥 استجابة السيرفر (Code ${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['users'] is List) {
          return data['users'];
        }
      }
      return [];
    } catch (e) {
      print('❌ خطأ في الاتصال بنظام البحث: $e');
      return [];
    }
  }
}
