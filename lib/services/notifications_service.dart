import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Bildirim Tipleri ──
enum NotifType { friendRequest, friendPost, postLike }

class AppNotification {
  final String id;
  final NotifType type;
  final String title;
  final String body;
  final DateTime time;
  final String? targetId;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    this.targetId,
  });

  String get iconEmoji {
    switch (type) {
      case NotifType.friendRequest:
        return '🤝';
      case NotifType.friendPost:
        return '📢';
      case NotifType.postLike:
        return '❤️';
    }
  }
}

class NotificationService {
  static final _db = FirebaseFirestore.instance;

  // ── Ayarlar ──
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

  static Future<DateTime> getLastSeen() async {
    final p = await SharedPreferences.getInstance();
    final ms = p.getInt('notif_last_seen');
    return ms != null
        ? DateTime.fromMillisecondsSinceEpoch(ms)
        : DateTime(2020);
  }

  static Future<void> markAllSeen() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(
        'notif_last_seen', DateTime.now().millisecondsSinceEpoch);
  }

  // ── Bildirimleri Çek (Panel için) ──
  static Future<List<AppNotification>> fetchNotifications() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (myUid.isEmpty) return [];

    final List<AppNotification> notifs = [];
    final likesEnabled = await isLikesEnabled();

    // 1. Arkadaşlık İstekleri
    try {
      final reqs = await _db
          .collection('friendRequests')
          .where('toUid', isEqualTo: myUid)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      for (final doc in reqs.docs) {
        final d = doc.data();
        notifs.add(AppNotification(
          id: 'fr_${doc.id}',
          type: NotifType.friendRequest,
          title: 'Arkadaşlık İsteği',
          body: '@${d['fromUsername'] ?? 'biri'} sana arkadaşlık isteği gönderdi',
          time: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        ));
      }
    } catch (_) {}

    // 2. Arkadaşların Paylaşımları
    try {
      final friendsSnap = await _db
          .collection('friends')
          .where('userId', isEqualTo: myUid)
          .get();

      final friendUids = friendsSnap.docs
          .map((d) => d.data()['friendUid'] as String?)
          .whereType<String>()
          .toList();

      if (friendUids.isNotEmpty) {
        final cutoff = Timestamp.fromDate(
            DateTime.now().subtract(const Duration(hours: 24)));

        final batches = <List<String>>[];
        for (var i = 0; i < friendUids.length; i += 10) {
          batches.add(friendUids.sublist(
            i,
            (i + 10 > friendUids.length) ? friendUids.length : i + 10,
          ));
        }

        for (final batch in batches) {
          final posts = await _db
              .collection('posts')
              .where('userId', whereIn: batch)
              .where('createdAt', isGreaterThan: cutoff)
              .orderBy('createdAt', descending: true)
              .limit(10)
              .get();

          for (final doc in posts.docs) {
            final d = doc.data();
            notifs.add(AppNotification(
              id: 'fp_${doc.id}',
              type: NotifType.friendPost,
              title: 'Arkadaşın Paylaştı',
              body: '@${d['username'] ?? 'biri'} yeni bir overheard paylaştı',
              time: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              targetId: doc.id,
            ));
          }
        }
      }
    } catch (_) {}

    // 3. Beğeniler — TOPLU (ayar açıksa)
    if (likesEnabled) {
      try {
        final myPosts = await _db
            .collection('posts')
            .where('userId', isEqualTo: myUid)
            .orderBy('createdAt', descending: true)
            .limit(20)
            .get();

        for (final postDoc in myPosts.docs) {
          final reactionDoc = await _db
              .collection('postReactions')
              .doc(postDoc.id)
              .get();

          if (!reactionDoc.exists) continue;

          final data = reactionDoc.data() as Map<String, dynamic>;
          final reactions = data['reactions'] as Map<String, dynamic>?;
          if (reactions == null || reactions.isEmpty) continue;

          // Toplam beğeni sayısı
          int totalLikes = 0;
          String lastLikerUsername = '';
          DateTime lastLikeTime = DateTime(2020);

          for (final entry in reactions.entries) {
            if (entry.key == myUid) continue;
            totalLikes++;

            // Son beğeneni bul
            final likeData = entry.value as Map<String, dynamic>?;
            if (likeData != null) {
              final likeTime =
                  (likeData['timestamp'] as Timestamp?)?.toDate();
              final username = likeData['username'] as String? ?? '';
              if (likeTime != null && likeTime.isAfter(lastLikeTime)) {
                lastLikeTime = likeTime;
                lastLikerUsername = username;
              }
            }
          }

          if (totalLikes == 0) continue;

          final postText =
              (postDoc.data()['content'] as String?) ?? '';
          final shortText = postText.length > 25
              ? '${postText.substring(0, 25)}...'
              : postText;

          final body = totalLikes == 1
              ? '@$lastLikerUsername gönderini beğendi'
              : '@$lastLikerUsername ve ${totalLikes - 1} kişi daha gönderini beğendi';

          notifs.add(AppNotification(
            id: 'like_${postDoc.id}',
            type: NotifType.postLike,
            title: '❤️ $totalLikes beğeni${totalLikes > 1 ? '' : ''}',
            body: '$body\n"$shortText"',
            time: lastLikeTime == DateTime(2020)
                ? (postDoc.data()['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now()
                : lastLikeTime,
            targetId: postDoc.id,
          ));
        }
      } catch (_) {}
    }

    // Zamana göre sırala
    notifs.sort((a, b) => b.time.compareTo(a.time));
    return notifs;
  }

  // ── Okunmamış sayısı (friend requests) ──
  static Stream<int> unreadCountStream() {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (myUid.isEmpty) return Stream.value(0);

    return _db
        .collection('friendRequests')
        .where('toUid', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.length);
  }
}