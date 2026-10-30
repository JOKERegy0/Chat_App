class AppConfig {
  static const String appName = 'KIURA';
  static const String appVersion = '1.0.0';
  
  // الروابط الأساسية وسيرفرات الـ FastAPI
  static const String serverWsUrl = 'wss://chat-app-4hax.onrender.com';
  static const String baseUrl = 'https://chat-app-4hax.onrender.com';

  static const String login = '$baseUrl/auth/login';
  static const String register = '$baseUrl/auth/register';
  static const String refreshToken = '$baseUrl/auth/refresh';
  static const String securityPulse = '$baseUrl/security/pulse';
  static const String uploadMedia = '$baseUrl/media/upload';

  // مفتاح التوقيع والأمان
  static const String developerSignatureKey = 'KIURA_SECURE_DEV_SIGNATURE_2026_JOKER';

  static Map<String, String> staticHeaders(String appVersion, String token) {
    return {
      'Content-Type': 'application/json',
      'X-App-Version': appVersion,
      'Authorization': 'Bearer $token',
    };
  }
}
