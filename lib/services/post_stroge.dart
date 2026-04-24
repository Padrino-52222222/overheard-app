import 'package:HeardOver/models/overheard_post.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostStorage {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'posts';

  static Future<void> savePost(OverheardPost post) async {
    await _db.collection(_collection).doc(post.id).set({
      'id': post.id,
      'text': post.text,
      'authorName': post.authorName,
      'city': post.city,
      'district': post.district,
      'dateTime': post.dateTime.toIso8601String(),
      'latitude': post.latitude,
      'longitude': post.longitude,
      'userId': post.userId,
      'vitrinUntil': post.vitrinUntil?.toIso8601String(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<List<OverheardPost>> loadPosts() async {
    final snapshot = await _db
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      DateTime? vitrin;
      if (data['vitrinUntil'] != null && data['vitrinUntil'] is String) {
        try {
          vitrin = DateTime.parse(data['vitrinUntil']);
        } catch (_) {}
      }

      return OverheardPost(
        id: data['id'] ?? doc.id,
        text: data['text'] ?? '',
        authorName: data['authorName'] ?? 'Anonim',
        city: data['city'] ?? '',
        district: data['district'] ?? '',
        dateTime: data['dateTime'] is String
            ? DateTime.parse(data['dateTime'])
            : DateTime.now(),
        latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
        userId: data['userId'],
        vitrinUntil: vitrin,
      );
    }).toList();
  }

  static Stream<List<OverheardPost>> postsStream() {
    return _db
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();

        DateTime? vitrin;
        if (data['vitrinUntil'] != null && data['vitrinUntil'] is String) {
          try {
            vitrin = DateTime.parse(data['vitrinUntil']);
          } catch (_) {}
        }

        return OverheardPost(
          id: data['id'] ?? doc.id,
          text: data['text'] ?? '',
          authorName: data['authorName'] ?? 'Anonim',
          city: data['city'] ?? '',
          district: data['district'] ?? '',
          dateTime: data['dateTime'] is String
              ? DateTime.parse(data['dateTime'])
              : DateTime.now(),
          latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
          longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
          userId: data['userId'],
          vitrinUntil: vitrin,
        );
      }).toList();
    });
  }
}