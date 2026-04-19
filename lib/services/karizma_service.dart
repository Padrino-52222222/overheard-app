import 'package:cloud_firestore/cloud_firestore.dart';

class KarizmaService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Karizma puanını hesapla
  /// Her gönderi: +100
  /// Her like: +2
  /// Her dislike: -1
  /// Vitrinde olan her gönderi: +300
  static Future<int> calculateKarizma(String uid) async {
    int karizma = 0;

    try {
      // 1) Kullanıcının gönderilerini çek
      final postsSnap = await _db
          .collection('posts')
          .where('userId', isEqualTo: uid)
          .get();

      for (final doc in postsSnap.docs) {
        final data = doc.data();
        final postId = data['id'] as String? ?? doc.id;

        // Her gönderi +100
        karizma += 100;

        // Vitrinde mi?
        final vitrinStr = data['vitrinUntil'] as String?;
        if (vitrinStr != null && vitrinStr.isNotEmpty) {
          try {
            final vitrinDate = DateTime.parse(vitrinStr);
            if (vitrinDate.isAfter(DateTime.now())) {
              karizma += 300;
            }
          } catch (_) {}
        }

        // Reaksiyonları çek
        final reactionDoc =
            await _db.collection('postReactions').doc(postId).get();
        if (reactionDoc.exists) {
          final rData = reactionDoc.data()!;
          final likes = rData['likes'] as int? ?? 0;
          final dislikes = rData['dislikes'] as int? ?? 0;
          karizma += likes * 2;
          karizma -= dislikes * 1;
        }
      }

      // Negatife düşmesin
      if (karizma < 0) karizma = 0;
    } catch (_) {}

    return karizma;
  }

  /// Seviye hesapla
  static String getLevel(int karizma) {
    if (karizma >= 5000) return 'Efsane 👑';
    if (karizma >= 2500) return 'Usta 🔥';
    if (karizma >= 1000) return 'Deneyimli 💎';
    if (karizma >= 500) return 'Gezgin 🚀';
    if (karizma >= 100) return 'Acemi 🌱';
    return 'Çaylak 🐣';
  }

  /// Sonraki seviye için gereken puan
  static int getNextLevelTarget(int karizma) {
    if (karizma >= 5000) return 5000;
    if (karizma >= 2500) return 5000;
    if (karizma >= 1000) return 2500;
    if (karizma >= 500) return 1000;
    if (karizma >= 100) return 500;
    return 100;
  }

  /// Progress bar için oran (0.0 - 1.0)
  static double getProgress(int karizma) {
    final target = getNextLevelTarget(karizma);
    if (karizma >= 5000) return 1.0;
    return (karizma / target).clamp(0.0, 1.0);
  }

  /// Formatla
  static String format(int karizma) {
    if (karizma < 1000) return karizma.toString();
    if (karizma < 1000000) {
      double val = karizma / 1000;
      String formatted = val.toStringAsFixed(1);
      if (formatted.endsWith('.0')) {
        formatted = formatted.substring(0, formatted.length - 2);
      }
      return '${formatted}B';
    }
    return karizma.toString();
  }
}