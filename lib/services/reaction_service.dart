import 'package:cloud_firestore/cloud_firestore.dart';

class ReactionService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<Map<String, dynamic>> toggleReaction({
    required String postId,
    required String uid,
    required String type,
  }) async {
    final postRef = _db.collection('postReactions').doc(postId);

    return _db.runTransaction((transaction) async {
      final postDoc = await transaction.get(postRef);

      if (!postDoc.exists) {
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
        } else {
          likedBy.add(uid);
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