import 'dart:convert';
import 'package:crypto/crypto.dart';

class SecureStorageManager {
  // محاكاة لخزنة مشفرة محلية لحفظ بيانات الحسابات والرموز السرية
  static final Map<String, String> _encryptedVault = {};

  /// تشفير وحفظ بيانات الحساب الحساسة محلياً
  static void saveSecureCredential(String key, String value) {
    // تطبيق طبقة تجزئة وتشفير إضافية قبل تخزين البيانات محلياً
    final bytes = utf8.encode(value);
    final encryptedValue = sha256.convert(bytes).toString();
    
    _encryptedVault[key] = encryptedValue;
  }

  /// استرجاع البيانات المشفرة بأمان
  static String? getSecureCredential(String key) {
    return _encryptedVault[key];
  }

  /// مسح كافة البيانات الحساسة عند تسجيل الخروج أو كشف التلاعب
  static void wipeSecureData() {
    _encryptedVault.clear();
    print("Secure vault wiped successfully.");
  }
}