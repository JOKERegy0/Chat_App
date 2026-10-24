import 'package:supabase_flutter/supabase_flutter.dart';

class ReportService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. تسجيل بلاغ جديد مع حفظ الآيبي والمحادثة
  Future<bool> submitReport({
    required String reportedUserId,
    required String chatEvidence,
    required String reportedUserIp,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser!.id;

      // حفظ البلاغ في قاعدة البيانات مع الأدلة
      await _supabase.from('reports').insert({
        'reporter_id': currentUserId,
        'reported_user_id': reportedUserId,
        'chat_snapshot': chatEvidence,
        'reported_ip': reportedUserIp,
        'status': 'pending',
      });

      return true;
    } catch (e) {
      print('خطأ أثناء إرسال البلاغ: $e');
      return false;
    }
  }

  // 2. نظام الإدارة لت,بيق العقوبات التدرجية في حال "ثبتت التهمة"
  Future<void> processProvenReport(String reportedUserId, String reportedIp) async {
    try {
      // جلب سجل المخالفات السابق للمستخدم
      final penaltyData = await _supabase
          .from('user_penalties')
          .select()
          .eq('user_id', reportedUserId)
          .maybeSingle();

      int currentViolations = penaltyData != null ? penaltyData['violation_count'] : 0;
      currentViolations += 1; // زيادة عدد مرات ثبوت التهمة

      DateTime now = DateTime.now();

      if (currentViolations == 1) {
        // المرحلة الأولى: حظر مؤقت لمدة 3 أيام
        DateTime banEnd = now.add(const Duration(days: 3));
        await _upsertPenalty(reportedUserId, currentViolations, banEnd, false, false);
      } 
      else if (currentViolations == 2) {
        // المرحلة الثانية: حظر لمدة شهر
        DateTime banEnd = now.add(const Duration(days: 30));
        await _upsertPenalty(reportedUserId, currentViolations, banEnd, false, false);
      } 
      else if (currentViolations == 3) {
        // المرحلة الثالثة: حظر الحساب نهائياً
        await _upsertPenalty(reportedUserId, currentViolations, null, true, false);
      } 
      else {
        // المرحلة الرابعة وما بعدها: حظر الحساب + حظر آيبي الهاتف مدى الحياة! 🚫
        await _upsertPenalty(reportedUserId, currentViolations, null, true, true);
        
        // إفادة الآيبي في جدول المحظورين نهائياً (IP Blacklist)
        await _supabase.from('ip_blacklist').insert({
          'ip_address': reportedIp,
          'reason': 'Repeated severe violations - Permanent Ban',
        });
      }
    } catch (e) {
      print('خطأ في تطبيق العقوبة: $e');
    }
  }

  // دالة مساعدة لتحديث جدول العقوبات
  Future<void> _upsertPenalty(
    String userId, 
    int count, 
    DateTime? expiresAt, 
    bool accountBanned, 
    bool ipBanned,
  ) async {
    await _supabase.from('user_penalties').upsert({
      'user_id': userId,
      'violation_count': count,
      'ban_expires_at': expiresAt?.toIso8601String(),
      'is_permanently_banned': accountBanned,
      'ip_blacklisted': ipBanned,
    });
  }
}
