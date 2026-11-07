import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class CoreApiService {
  // يجب أن يتطابق هذا المفتاح تماماً مع الموجود في Cserver.js
  static const String internalServiceSecret = "KIURA_INTERNAL_SERVICE_KEY_2026";

  static Future<List<dynamic>> searchUsers({
    required String searchQuery,
    required String currentUsername,
  }) async {
    try {
      final url = '${AppConfig.coreService}/api/core/search-users';
      print('🌐 جاري إرسال البحث إلى: $url للكلمة: $searchQuery');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'x-service-secret': internalServiceSecret,
        },
        body: jsonEncode({
          'search_query': searchQuery,
          'current_user': currentUsername,
        }),
      );

      print('📥 كود الاستجابة من السيرفر: ${response.statusCode}');
      print('📥 محتوى الاستجابة: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['users'] is List) {
          return data['users'];
        }
      }
      return [];
    } catch (e) {
      print('❌ خطأ في الاتصال بالبحث: $e');
      return [];
    }
  }
}
