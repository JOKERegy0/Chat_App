import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_config.dart';

class MediaService {
  // دالة لرفع الوسائط مع تمرير الوجهة (مجموعة، قناة، مجتمع، شات) ومعرف المرسل عبر التوكن
  Future?> uploadMedia({
    required File file,
    required String targetType, // group, channel, community, chat
    required String targetId,
    required String authToken,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.mediaService}/api/v1/media/upload'),
      );

      // إضافة هيدر المصادقة (JWT Token)
      request.headers['Authorization'] = 'Bearer $authToken';

      // تحديد الوجهة والهدف بدقة لكي يتعرف السيرفر على الصلاحيات
      request.fields['target_type'] = targetType;
      request.fields['target_id'] = targetId;

      // إضافة الملف للطلب
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      var data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('📁 تم رفع الملف بنجاح داخل $targetType ($targetId)');
        return data; // يرجع رابط الملف وتفاصيل الرفع
      } else {
        print('❌ فشل رفع الوسائط: ${data['detail'] ?? response.body}');
        return null;
      }
    } catch (e) {
      print('❌ حدث خطأ أثناء الاتصال بسيرفر الوسائط: $e');
      return null;
    }
  }
}
