import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_config.dart';

class MediaService {
  // دالة لرفع الوسائط تتوافق مع استدعاء statuses_screen (تستقبل الملف واسم المجلد بمعاملات موضعية)
  Future<String?> uploadMedia(File file, String folderName) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.mediaService}/api/v1/media/upload'),
      );

      // تحديد المجلد أو الوجهة
      request.fields['folder'] = folderName;
      request.fields['target_type'] = folderName;
      request.fields['target_id'] = 'general';

      // إضافة الملف للطلب
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      var data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('📁 تم رفع الملف بنجاح');
        // إرجاع رابط الملف المرفوع بأي صيغة يرجعها السيرفر
        return data['file_url'] ?? data['url'] ?? data['media_url'];
      } else {
        print('❌ فشل رفع الوسائط: ${data['detail'] ?? response.body}');
        return null;
      }
    } catch (e) {
      print('❌ خطأ أثناء الاتصال بسيرفر الوسائط: $e');
      return null;
    }
  }
}
