import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AvatarService {
  /// Kullanılabilir preset avatar listesi
  static const List<String> presetAvatars = [
    'assets/images/bat.png',
    'assets/images/bear.png',
    'assets/images/crab.png',
    'assets/images/crow.png',
    'assets/images/eagle.png',
    'assets/images/hen.png',
    'assets/images/jellyfish.png',
    'assets/images/lion.png',
    'assets/images/monkey.png',
    'assets/images/panda.png',
    'assets/images/parrot.png',
    'assets/images/reindeer.png',
    'assets/images/snake.png',
    'assets/images/tiger.png',
    'assets/images/wolf.png',
    'assets/images/wolf2.png',

  ];

  /// Firebase Storage'daki eski profil fotoğrafını sil
  static Future<void> deleteOldPhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('${user.uid}.jpg');
      await ref.delete();
    } catch (_) {
      // Dosya yoksa veya silinemezse sessizce geç
    }
  }

  /// Asset avatar'ı byte olarak oku → Firebase Storage'a yükle → Firestore güncelle
  /// Önce eski fotoğrafı siler
  static Future<String> uploadPresetAvatar(String assetPath) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Kullanıcı bulunamadı');

    // 1) Eski fotoğrafı sil
    await deleteOldPhoto();

    // 2) Asset dosyasını byte olarak oku
    final ByteData byteData = await rootBundle.load(assetPath);
    final Uint8List bytes = byteData.buffer.asUint8List();

    // 3) Firebase Storage'a yükle
    final ref = FirebaseStorage.instance
        .ref()
        .child('profile_photos')
        .child('${user.uid}.jpg');

    await ref.putData(bytes, SettableMetadata(contentType: 'image/png'));
    final downloadUrl = await ref.getDownloadURL();

    // 4) Firestore'u güncelle
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'photoUrl': downloadUrl});

    return downloadUrl;
  }

  /// Galeri fotoğrafını File olarak al → Firebase Storage'a yükle → Firestore güncelle
  /// Önce eski fotoğrafı siler
  static Future<String> uploadGalleryPhoto(File file) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Kullanıcı bulunamadı');

    // 1) Eski fotoğrafı sil
    await deleteOldPhoto();

    // 2) Yeni fotoğrafı yükle
    final ref = FirebaseStorage.instance
        .ref()
        .child('profile_photos')
        .child('${user.uid}.jpg');

    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    final downloadUrl = await ref.getDownloadURL();

    // 3) Firestore'u güncelle
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'photoUrl': downloadUrl});

    return downloadUrl;
  }
}