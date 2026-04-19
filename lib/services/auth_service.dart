import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Future<UserCredential> register({
    required String email,
    required String password,
    required String username,
  }) async {
    final usernameDoc =
        await _db.collection('usernames').doc(username.toLowerCase()).get();
    if (usernameDoc.exists) {
      throw AuthException(
        code: 'username-taken',
        message: 'Bu kullanıcı adı zaten alınmış',
      );
    }

    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    await _db.collection('users').doc(cred.user!.uid).set({
      'uid': cred.user!.uid,
      'email': email.trim(),
      'username': username.toLowerCase(),
      'displayName': '',
      'age': 0,
      'city': '',
      'gender': '',
      'fullName': '',
      'photoUrl': '',
      'onboardingCompleted': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('usernames').doc(username.toLowerCase()).set({
      'uid': cred.user!.uid,
    });

    return cred;
  }

  static Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<void> logout() async {
    await _auth.signOut();
  }

  static Future<Map<String, dynamic>?> getUserProfile() async {
    final user = currentUser;
    if (user == null) return null;
    final doc = await _db.collection('users').doc(user.uid).get();
    return doc.data();
  }

  static Future<void> updateOnboarding({
    String? fullName,
    int? age,
    String? city,
    String? gender,
    String? photoUrl,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final Map<String, dynamic> data = {
      'onboardingCompleted': true,
    };

    if (fullName != null && fullName.isNotEmpty) data['fullName'] = fullName;
    if (age != null && age > 0) data['age'] = age;
    if (city != null && city.isNotEmpty) data['city'] = city;
    if (gender != null && gender.isNotEmpty) data['gender'] = gender;
    if (photoUrl != null) data['photoUrl'] = photoUrl;

    await _db.collection('users').doc(user.uid).update(data);
  }

  static Future<bool> isOnboardingCompleted() async {
    final profile = await getUserProfile();
    if (profile == null) return false;
    return profile['onboardingCompleted'] == true;
  }

  static Future<String> getUsername() async {
    final profile = await getUserProfile();
    if (profile == null) return 'anonim';
    return profile['username'] ?? 'anonim';
  }

  static Future<void> updateField(String field, dynamic value) async {
    final user = currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).update({field: value});
  }

  /// Hesabı tamamen sil — Firestore verileri + Storage + Auth
  static Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) return;

    final uid = user.uid;

    // 1) Username dokümanını sil
    final profile = await getUserProfile();
    if (profile != null) {
      final username = profile['username'] as String?;
      if (username != null && username.isNotEmpty) {
        await _db.collection('usernames').doc(username).delete();
      }
    }

    // 2) Kullanıcının postlarını sil
    final posts = await _db.collection('posts').where('userId', isEqualTo: uid).get();
    for (final doc in posts.docs) {
      // Reaksiyonlarını da sil
      final postId = doc.data()['id'] as String? ?? doc.id;
      await _db.collection('postReactions').doc(postId).delete();
      await doc.reference.delete();
    }

    // 3) Arkadaşlık dokümanlarını sil
    final friends = await _db.collection('friends').where('users', arrayContains: uid).get();
    for (final doc in friends.docs) {
      await doc.reference.delete();
    }

    // 4) Arkadaşlık isteklerini sil
    final reqFrom = await _db.collection('friendRequests').where('from', isEqualTo: uid).get();
    for (final doc in reqFrom.docs) {
      await doc.reference.delete();
    }
    final reqTo = await _db.collection('friendRequests').where('to', isEqualTo: uid).get();
    for (final doc in reqTo.docs) {
      await doc.reference.delete();
    }

    // 5) Profil fotoğrafını sil
    try {
      await FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('$uid.jpg')
          .delete();
    } catch (_) {}

    // 6) Firestore user dokümanını sil
    await _db.collection('users').doc(uid).delete();

    // 7) Firebase Auth hesabını sil
    await user.delete();
  }
}

class AuthException implements Exception {
  final String code;
  final String message;
  AuthException({required this.code, required this.message});

  @override
  String toString() => message;
}