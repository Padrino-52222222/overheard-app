import 'package:cloud_firestore/cloud_firestore.dart';

class FriendService {
  static final _db = FirebaseFirestore.instance;

  /// Arkadaşlık isteği gönder
  static Future<void> sendRequest({
    required String fromUid,
    required String toUid,
  }) async {
    // Zaten istek var mı kontrol et
    final existing = await _db
        .collection('friendRequests')
        .where('from', isEqualTo: fromUid)
        .where('to', isEqualTo: toUid)
        .get();
    if (existing.docs.isNotEmpty) return;

    // Zaten arkadaş mı kontrol et
    final alreadyFriend = await areFriends(fromUid, toUid);
    if (alreadyFriend) return;

    await _db.collection('friendRequests').add({
      'from': fromUid,
      'to': toUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Arkadaşlık isteği kabul et
  static Future<void> acceptRequest(String requestId, String fromUid, String toUid) async {
    // İsteği sil
    await _db.collection('friendRequests').doc(requestId).delete();

    // Her iki tarafın friends listesine ekle
    final batch = _db.batch();
    batch.set(
      _db.collection('friends').doc('${fromUid}_$toUid'),
      {'users': [fromUid, toUid], 'createdAt': FieldValue.serverTimestamp()},
    );
    batch.set(
      _db.collection('friends').doc('${toUid}_$fromUid'),
      {'users': [toUid, fromUid], 'createdAt': FieldValue.serverTimestamp()},
    );
    await batch.commit();
  }

  /// Arkadaşlık isteği reddet
  static Future<void> rejectRequest(String requestId) async {
    await _db.collection('friendRequests').doc(requestId).delete();
  }

  /// Arkadaş mı kontrol et
  static Future<bool> areFriends(String uid1, String uid2) async {
    final doc = await _db.collection('friends').doc('${uid1}_$uid2').get();
    return doc.exists;
  }

  /// Bekleyen istek var mı (ben gönderdim mi)
  static Future<String?> getPendingRequestId(String fromUid, String toUid) async {
    final query = await _db
        .collection('friendRequests')
        .where('from', isEqualTo: fromUid)
        .where('to', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .get();
    if (query.docs.isNotEmpty) return query.docs.first.id;
    return null;
  }

  /// Bana gelen istekler
  static Stream<QuerySnapshot> incomingRequests(String uid) {
    return _db
        .collection('friendRequests')
        .where('to', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  /// Arkadaş listesi (UID'ler)
  static Future<List<String>> getFriendUids(String uid) async {
    final query = await _db
        .collection('friends')
        .where('users', arrayContains: uid)
        .get();

    final uids = <String>{};
    for (final doc in query.docs) {
      final users = List<String>.from(doc['users']);
      for (final u in users) {
        if (u != uid) uids.add(u);
      }
    }
    return uids.toList();
  }

  /// Arkadaş profil bilgilerini getir
  static Future<List<Map<String, dynamic>>> getFriendsWithProfiles(String uid) async {
    final friendUids = await getFriendUids(uid);
    if (friendUids.isEmpty) return [];

    final List<Map<String, dynamic>> friends = [];
    // Firestore 'in' max 30 eleman alıyor
    for (int i = 0; i < friendUids.length; i += 30) {
      final chunk = friendUids.sublist(
          i, i + 30 > friendUids.length ? friendUids.length : i + 30);
      final query = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in query.docs) {
        friends.add({...doc.data(), 'uid': doc.id});
      }
    }
    return friends;
  }

  /// Arkadaşlığı kaldır (iki yönlü)
  static Future<void> removeFriend(String uid1, String uid2) async {
    final batch = _db.batch();
    batch.delete(_db.collection('friends').doc('${uid1}_$uid2'));
    batch.delete(_db.collection('friends').doc('${uid2}_$uid1'));
    await batch.commit();
  }
}