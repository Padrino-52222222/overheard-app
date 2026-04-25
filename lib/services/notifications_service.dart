import 'package:shared_preferences/shared_preferences.dart';

/// Sadece bildirim tercihleri (aç/kapat) için kullanılır.
/// Tüm bildirim verisi artık NotificationTriggerService üzerinden akar.
class NotificationService {
  static Future<bool> isNearbyPostsEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('notif_nearby') ?? true;
  }

  static Future<bool> isLikesEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('notif_likes') ?? true;
  }

  static Future<void> setNearbyPosts(bool val) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('notif_nearby', val);
  }

  static Future<void> setLikes(bool val) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('notif_likes', val);
  }
}