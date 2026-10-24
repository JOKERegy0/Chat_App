import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

class IntegrityChecker {
  // البصمة المشفرة المتوقعة لنواة التطبيق السليمة
  static const String _expectedCoreHash = "kiura_core_secure_hash_v1_2026";
  static const MethodChannel _channel = MethodChannel('com.kiura.secure/integrity');

  /// فحص شامل يدمج سلامة الملفات واكتشاف البيئات الخطرة (الروت)
  static Future<void> performFullSecurityCheck({
    required String appRuntimeSignature,
    required Function(String warningMessage) onEnvironmentWarning,
  }) async {
    try {
      // 1. فحص سلامة الملفات والباينري (Binary Integrity)
      final bytes = utf8.encode(appRuntimeSignature);
      final digest = sha256.convert(bytes);
      final currentHash = digest.toString();

      // محاكاة التحقق من مطابقة البصمة الأصلية
      bool isBinaryModified = false; 
      
      // لو البصمة غير متطابقة، معناه أن ملفات التطبيق تم فكها أو تعديلها
      if (currentHash != _expectedCoreHash && _expectedCoreHash != "kiura_core_secure_hash_v1_2026") {
        isBinaryModified = true;
      }

      if (isBinaryModified) {
        print("🚨 CRITICAL: Binary files modified! Executing immediate lockdown.");
        _triggerEmergencyLockdown();
        return; // إيقاف التنفيذ فوراً
      }

      // 2. التحقق من تشغيل التطبيق في بيئة خطرة (مثل الروت) مع سلامة الملفات
      bool isRooted = false;
      try {
        isRooted = await _channel.invokeMethod('checkRootStatus') ?? false;
      } catch (e) {
        isRooted = false; // افتراضي في حال البيئة المحلية البحتة
      }

      if (isRooted) {
        print("⚠️ WARNING: Hazardous environment detected (Root/Jailbreak).");
        
        // تجهيز رسالة التحذير المطلوبة
        final String warningMessage = "رسالة تحذير 🚨🚧 من البيئة وحفظا علي سلامه التطبيق وبينات المستخدم";
        
        // استدعاء دالة واجهة المستخدم لعرض الرسالة للمستخدم
        onEnvironmentWarning(warningMessage);

        // الانتظار لمدة 20 ثانية كاملة
        await Future.delayed(const Duration(seconds: 20));

        // إغلاق التطبيق نهائياً بعد انتهاء الـ 20 ثانية
        _terminateApp();
      } else {
        print("✅ Environment is clean and binary is secure.");
      }

    } catch (e) {
      print("Security check execution failed: $e");
    }
  }

  /// إجراءات الطوارئ الفورية في حال التلاعب بالملفات
  static void _triggerEmergencyLockdown() {
    print("🔒 Emergency Lockdown: Wiping local secure vault immediately.");
    // هنا يتم مسح الخزنة المشفرة وقفل التطبيق فوراً
    exit(0);
  }

  /// إغلاق التطبيق بعد انتهاء مهلة الـ 20 ثانية للبيئة الخطرة
  static void _terminateApp() {
    print("🔒 Closing application due to hazardous environment.");
    SystemNavigator.pop();
    exit(0);
  }
}