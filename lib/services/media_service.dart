import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MediaService {
  // رابط سيرفر الوسائط على Render اللي حددناه في الإعدادات
  final String _mediaServiceUrl = 'https://chat-app-iqrv.onrender.com';

  // دالة لرفع الوسائط (صور، فيديوهات، أو حالات صوتية)
  Future<String?> uploadMedia(File file, String folderName) async {
    try {
      // تجهيز طلب رفع متعدد الأجزاء (Multipart Request)
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_mediaServiceUrl/upload'),
      );

      // إضافة المجلد المستهدف (مثل: statuses أو profile_pics)
      request.fields['folder'] = folderName;

      // إضافة الملف للطلب
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      // إرسال الطلب للسيرفر
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        var data = jsonDecode(response.body);
        // إرجاع رابط الملف المرفوع مباشرة
        return data['url'] ?? data['media_url'];
      } else {
        print('فشل رفع الوسائط: ${response.body}');
        return null;
      }
    } catch (e) {
      print('حدث خطأ أثناء الاتصال بسيرفر الوسائط: $e');
      return null;
    }
  }
}
