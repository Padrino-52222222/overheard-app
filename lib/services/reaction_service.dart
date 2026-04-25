import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_trigger_service.dart';

class ReactionService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Milestone eşikleri
  static const List<int> _milestones = [100, 1000, 10000, 100000, 1000000];

  static Future<Map<String, dynamic>> toggleReaction({
    required String postId,
    required String uid,
    required String type,
  }) async {
    final postRef = _db.collection('postReactions').doc(postId);
    bool justLiked = false;

    final result = await _db.runTransaction((transaction) async {
      final postDoc = await transaction.get(postRef);

      if (!postDoc.exists) {
        justLiked = type == 'like';
        final data = {
          'likes': type == 'like' ? 1 : 0,
          'dislikes': type == 'dislike' ? 1 : 0,
          'likedBy': type == 'like' ? [uid] : <String>[],
          'dislikedBy': type == 'dislike' ? [uid] : <String>[],
        };
        transaction.set(postRef, data);
        return data;
      }

      final data = postDoc.data()!;
      List<String> likedBy = List<String>.from(data['likedBy'] ?? []);
      List<String> dislikedBy = List<String>.from(data['dislikedBy'] ?? []);

      if (type == 'like') {
        dislikedBy.remove(uid);
        if (likedBy.contains(uid)) {
          likedBy.remove(uid);
          justLiked = false;
        } else {
          likedBy.add(uid);
          justLiked = true;
        }
      } else {
        likedBy.remove(uid);
        if (dislikedBy.contains(uid)) {
          dislikedBy.remove(uid);
        } else {
          dislikedBy.add(uid);
        }
      }

      final updated = {
        'likes': likedBy.length,
        'dislikes': dislikedBy.length,
        'likedBy': likedBy,
        'dislikedBy': dislikedBy,
      };
      transaction.update(postRef, updated);
      return updated;
    });

    // ── Bildirim Mantığı ──
    if (type == 'like' && justLiked) {
      try {
        final newLikeCount = result['likes'] as int;
        final postDoc = await _db.collection('posts').doc(postId).get();
        final postData = postDoc.data();

        if (postData != null) {
          final postOwnerId = postData['userId'] as String?;
          final postText = postData['text'] as String? ?? '';
          final postLat = (postData['latitude'] as num?)?.toDouble() ?? 0.0;
          final postLng = (postData['longitude'] as num?)?.toDouble() ?? 0.0;

          if (postOwnerId != null && postOwnerId != uid) {
            if (_milestones.contains(newLikeCount)) {
              // Milestone bildirimi — 100 / 1K / 10K / 100K / 1M
              await NotificationTriggerService.sendMilestoneLikeNotif(
                toUid: postOwnerId,
                postId: postId,
                postText: postText,
                milestone: newLikeCount,
              );
            } else {
              // Normal beğeni bildirimi
              final senderDoc =
                  await _db.collection('users').doc(uid).get();
              final senderUsername =
                  senderDoc.data()?['username'] ?? 'biri';
              await NotificationTriggerService.sendLikeNotif(
                toUid: postOwnerId,
                fromUsername: senderUsername,
                postText: postText,
                postId: postId,
                postLat: postLat,
                postLng: postLng,
              );
            }
          }
        }
      } catch (_) {}
    }

    return result;
  }

  static Future<Map<String, dynamic>> getReactions(String postId) async {
    final doc = await _db.collection('postReactions').doc(postId).get();
    if (!doc.exists) {
      return {
        'likes': 0,
        'dislikes': 0,
        'likedBy': <String>[],
        'dislikedBy': <String>[],
      };
    }
    final data = doc.data()!;
    return {
      'likes': data['likes'] ?? 0,
      'dislikes': data['dislikes'] ?? 0,
      'likedBy': List<String>.from(data['likedBy'] ?? []),
      'dislikedBy': List<String>.from(data['dislikedBy'] ?? []),
    };
  }

  static String formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) {
      double val = count / 1000;
      String formatted = val.toStringAsFixed(1);
      if (formatted.endsWith('.0')) {
        formatted = formatted.substring(0, formatted.length - 2);
      }
      return '${formatted}B';
    }
    double val = count / 1000000;
    String formatted = val.toStringAsFixed(1);
    if (formatted.endsWith('.0')) {
      formatted = formatted.substring(0, formatted.length - 2);
    }
    return '${formatted}M';
  }
}