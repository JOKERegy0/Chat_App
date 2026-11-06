import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart'; // مستودع الروابط الأساسية لديك

class CoreApiService {
  static const String internalServiceSecret = "KIURA_INTERNAL_SERVICE_KEY_2026";

  // دالة البحث الذكي عبر السيرفر المركزي
  static Future<List<dynamic>> searchUsers({
    required String searchQuery,
    required String currentUsername,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.coreService}/api/core/search-users'),
        headers: {
          'Content-Type': 'application/json',
          'x-service-secret': internalServiceSecret,
        },
        body: jsonEncode({
          'search_query': searchQuery,
          'current_user': currentUsername,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return data['users'];
      }
      return [];
    } catch (e) {
      print('خطأ في الاتصال بنظام البحث: $e');
      return [];
    }
  }
}
