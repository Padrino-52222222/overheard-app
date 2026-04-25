import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationTriggerService {
  static final _db = FirebaseFirestore.instance;

  // ── Temel gönderici ──
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

  // ── Arkadaşlık İsteği ──
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

  // ── Arkadaşlık Kabul ──
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

  // ── Arkadaş Paylaşım Bildirimi ──
  static Future<void> sendFriendPostNotif({
    required String toUid,
    required String fromUsername,
    required String postId,
    required String postText,
  }) async {
    final short =
        postText.length > 40 ? '${postText.substring(0, 40)}...' : postText;
    await sendToUser(
      toUid: toUid,
      title: '📢 @$fromUsername yeni paylaşım yaptı',
      body: '"$short"',
      type: 'friendPost',
      extra: {'postId': postId, 'fromUsername': fromUsername},
    );
  }

  // ── Normal Beğeni ──
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

  // ── Milestone Beğeni (100 / 1K / 10K / 100K / 1M) ──
  static Future<void> sendMilestoneLikeNotif({
    required String toUid,
    required String postId,
    required String postText,
    required int milestone,
  }) async {
    final short =
        postText.length > 30 ? '${postText.substring(0, 30)}...' : postText;
    final String milestoneStr;
    if (milestone >= 1000000) {
      milestoneStr = '${(milestone / 1000000).toStringAsFixed(0)}M';
    } else if (milestone >= 1000) {
      milestoneStr = '${(milestone / 1000).toStringAsFixed(0)}B';
    } else {
      milestoneStr = '$milestone';
    }
    await sendToUser(
      toUid: toUid,
      title: '🌟 $milestoneStr Beğeni Milestone!',
      body: '"$short" gönderinig $milestoneStr beğeniye ulaştı!',
      type: 'milestoneLike',
      extra: {'postId': postId, 'milestone': milestone},
    );
  }

  // ── Vitrin Süresi Doldu ──
  static Future<void> sendVitrinExpiredNotif({
    required String toUid,
    required String postId,
    required String postText,
  }) async {
    final short =
        postText.length > 40 ? '${postText.substring(0, 40)}...' : postText;
    await sendToUser(
      toUid: toUid,
      title: '⏰ Vitrin Süresi Doldu',
      body: '"$short" vitrindeki süresi sona erdi',
      type: 'vitrinExpired',
      extra: {'postId': postId},
    );
  }

  // ── DM Bildirimi (spam korumalı: 30sn içinde aynı kişiden geldi mi kontrol) ──
  static Future<void> sendDmNotif({
    required String toUid,
    required String fromUid,
    required String fromUsername,
    required String messageText,
  }) async {
    try {
      final cutoff = Timestamp.fromDate(
          DateTime.now().subtract(const Duration(seconds: 30)));
      final existing = await _db
          .collection('notifications')
          .where('toUid', isEqualTo: toUid)
          .where('type', isEqualTo: 'dm')
          .where('isRead', isEqualTo: false)
          .where('createdAt', isGreaterThan: cutoff)
          .get();

      final alreadyHas = existing.docs.any((doc) {
        final extra = doc.data()['extra'] as Map<String, dynamic>? ?? {};
        return extra['friendUid'] == fromUid;
      });

      if (alreadyHas) return;
    } catch (_) {}

    final short =
        messageText.length > 30 ? '${messageText.substring(0, 30)}...' : messageText;
    await sendToUser(
      toUid: toUid,
      title: '💬 @$fromUsername',
      body: short,
      type: 'dm',
      extra: {'friendUid': fromUid, 'friendUsername': fromUsername},
    );
  }

  // ── Tümünü okundu işaretle ──
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

  // ── Stream (bildirim ekranı için) ──
  static Stream<QuerySnapshot> notificationsStream(String uid) {
    return _db
        .collection('notifications')
        .where('toUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  // ── Okunmamış sayısı stream'i ──
  static Stream<int> unreadCountStream(String uid) {
    if (uid.isEmpty) return Stream.value(0);
    return _db
        .collection('notifications')
        .where('toUid', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }
}