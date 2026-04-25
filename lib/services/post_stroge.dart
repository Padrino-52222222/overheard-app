import 'package:HeardOver/models/overheard_post.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_trigger_service.dart';

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

    // Arkadaşlara bildirim gönder
    if (post.userId != null && post.userId!.isNotEmpty) {
      await _notifyFriends(post);
    }
  }

  /// Post sahibinin tüm arkadaşlarına yeni paylaşım bildirimi gönderir.
  static Future<void> _notifyFriends(OverheardPost post) async {
    try {
      final friendDocs = await _db
          .collection('friends')
          .where('users', arrayContains: post.userId)
          .get();

      final friendUids = <String>{};
      for (final doc in friendDocs.docs) {
        final users = List<String>.from(doc['users'] ?? []);
        for (final u in users) {
          if (u != post.userId) friendUids.add(u);
        }
      }

      // authorName'de '@' ön eki olabilir, temizle
      final cleanName = post.authorName.startsWith('@')
          ? post.authorName.substring(1)
          : post.authorName;

      for (final friendUid in friendUids) {
        await NotificationTriggerService.sendFriendPostNotif(
          toUid: friendUid,
          fromUsername: cleanName,
          postId: post.id,
          postText: post.text,
        );
      }
    } catch (_) {}
  }

  /// Vitrini dolmuş gönderiler için bildirim gönderir.
  /// Uygulama açılışında ve ana ekran yüklenirken çağrılır.
  static Future<void> checkVitrinExpiry() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || myUid.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final notifiedIds =
          prefs.getStringList('vitrin_notified_$myUid') ?? [];

      final now = DateTime.now();
      final snap = await _db
          .collection(_collection)
          .where('userId', isEqualTo: myUid)
          .get();

      final updatedIds = List<String>.from(notifiedIds);

      for (final doc in snap.docs) {
        final data = doc.data();
        final vitrinUntilStr = data['vitrinUntil'] as String?;
        if (vitrinUntilStr == null) continue;

        DateTime? vitrinUntil;
        try {
          vitrinUntil = DateTime.parse(vitrinUntilStr);
        } catch (_) {
          continue;
        }

        // Süresi dolmuş VE daha önce bildirim gönderilmemiş
        if (vitrinUntil.isBefore(now) && !notifiedIds.contains(doc.id)) {
          final postText = data['text'] as String? ?? '';
          await NotificationTriggerService.sendVitrinExpiredNotif(
            toUid: myUid,
            postId: doc.id,
            postText: postText,
          );
          updatedIds.add(doc.id);
        }
      }

      await prefs.setStringList('vitrin_notified_$myUid', updatedIds);
    } catch (_) {}
  }

  static Future<List<OverheardPost>> loadPosts() async {
    final snapshot = await _db
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => _fromDoc(doc)).toList();
  }

  static Stream<List<OverheardPost>> postsStream() {
    return _db
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => _fromDoc(doc)).toList());
  }

  static OverheardPost _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
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
  }
}