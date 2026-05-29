import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Reads API configuration from `.env` (see `.env.example`).
class EnvConfig {
  static const _defaultBaseUrl = 'https://livora-hostel-hub-1.onrender.com';

  static String get baseUrl {
    final value = dotenv.env['BASE_URL']?.trim();
    if (value == null || value.isEmpty) return _defaultBaseUrl;
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  static String get socketUrl {
    final value = dotenv.env['SOCKET_URL']?.trim();
    if (value == null || value.isEmpty) return baseUrl;
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }
}
