import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationTriggerService {
  static final _db = FirebaseFirestore.instance;

  static Future<void> sendToUser({
    required String toUid,
    required String title,
    required String body,
    String type = 'general',
    Map<String, dynamic> extra = const {},
  }) async {
    try {
      await _db.collection('notifications').add({
        'toUid': toUid,
        'title': title,
        'body': body,
        'type': type,
        'extra': extra,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (_) {}
  }

  static Future<void> sendFriendRequestNotif({
    required String toUid,
    required String fromUid,
    required String fromUsername,
  }) async {
    await sendToUser(
      toUid: toUid,
      title: '🤝 Arkadaşlık İsteği',
      body: '@$fromUsername sana arkadaşlık isteği gönderdi',
      type: 'friendRequest',
      extra: {'fromUid': fromUid, 'fromUsername': fromUsername},
    );
  }

  static Future<void> sendFriendAcceptedNotif({
    required String toUid,
    required String fromUsername,
  }) async {
    await sendToUser(
      toUid: toUid,
      title: '🎉 Arkadaşlık Kabul Edildi',
      body: '@$fromUsername arkadaşlık isteğini kabul etti',
      type: 'friendAccepted',
      extra: {},
    );
  }

  static Future<void> sendLikeNotif({
    required String toUid,
    required String fromUsername,
    required String postText,
    required String postId,
    required double postLat,
    required double postLng,
  }) async {
    final short =
        postText.length > 25 ? '${postText.substring(0, 25)}...' : postText;
    await sendToUser(
      toUid: toUid,
      title: '❤️ Beğeni',
      body: '@$fromUsername gönderini beğendi: "$short"',
      type: 'like',
      extra: {
        'postId': postId,
        'postLat': postLat,
        'postLng': postLng,
      },
    );
  }

  static Future<void> markAllRead(String uid) async {
    try {
      final query = await _db
          .collection('notifications')
          .where('toUid', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .get();
      final batch = _db.batch();
      for (final doc in query.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  static Stream<QuerySnapshot> notificationsStream(String uid) {
    return _db
        .collection('notifications')
        .where('toUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  static Stream<int> unreadCountStream(String uid) {
    return _db
        .collection('notifications')
        .where('toUid', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }
}