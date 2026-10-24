import 'package:flutter/material.dart';
import 'media_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class StatusesScreen extends StatefulWidget {
  const StatusesScreen({super.key});

  @override
  State<StatusesScreen> createState() => _statusesScreenState();
}

class _statusesScreenState extends State<StatusesScreen> {
  final MediaService _mediaService = MediaService();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  // دالة لاختيار ورفع حالة جديدة
  Future<void> _uploadNewStatus() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() {
      _isUploading = true;
    });

    File file = File(image.path);
    // رفع الحالة لسيرفر الوسائط على Render في مجلد 'statuses'
    String? mediaUrl = await _mediaService.uploadMedia(file, 'statuses');

    setState(() {
      _isUploading = false;
    });

    if (mediaUrl != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفع الحالة بنجاح! 📸')),
      );
      // هنا ممكن تحفظ رابط الحالة في قاعدة بيانات Supabase لو حابب
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل رفع الحالة، حاول مرة أخرى.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الحالات اليومية - KIURA', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
      ),
      body: _isUploading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('جاري رفع الحالة...'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // زر إضافة حالة جديدة
                ListTile(
                  leading: Stack(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.person, color: Colors.white, size: 30),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.blueAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                  title: const Text('حالتك', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('اضغط لإضافة تحديث حالتك اليومية'),
                  onTap: _uploadNewStatus,
                ),
                const Divider(height: 30),
                const Text(
                  'حالات الأصدقاء',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                // قائمة الحالات الواردة (مكان عرض حالات الأصدقاء)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 0, // هترتبط بقاعدة البيانات لاحقاً
                  itemBuilder: (context, index) {
                    return const ListTile(
                      leading: CircleAvatar(radius: 28, backgroundColor: Colors.blue),
                      title: Text('اسم الصديق'),
                      subtitle: Text('منذ ساعتين'),
                    );
                  },
                ),
              ],
            ),
    );
  }
}
