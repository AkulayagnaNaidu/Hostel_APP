import '../config/env_config.dart';

class ImageResolver {
  static String resolve(String img) {
    if (img.startsWith('http') || img.startsWith('data:')) return img;
    if (img.startsWith('/')) return '${EnvConfig.baseUrl}$img';
    return img;
  }
}
