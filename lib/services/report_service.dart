import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Raporlama türleri — post, kullanıcı, mesaj, dm mesajı
enum ReportType {
  post,
  user,
  message,
  directMessage,
}

/// Raporlama nedenleri
enum ReportReason {
  spam,
  harassment,
  hateSpeech,
  violence,
  nudity,
  fakeAccount,
  scam,
  other,
}

class ReportReasonData {
  final ReportReason reason;
  final String icon;
  final String title;
  final String description;

  const ReportReasonData({
    required this.reason,
    required this.icon,
    required this.title,
    required this.description,
  });
}

class ReportService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Tüm raporlama nedenleri — UI'da listelenecek
  static const List<ReportReasonData> reasons = [
    ReportReasonData(
      reason: ReportReason.spam,
      icon: '🚫',
      title: 'Spam',
      description: 'Tekrarlayan, anlamsız veya reklam içerikli paylaşım',
    ),
    ReportReasonData(
      reason: ReportReason.harassment,
      icon: '😤',
      title: 'Taciz / Zorbalık',
      description: 'Kişiye yönelik hakaret, tehdit veya bezdirme',
    ),
    ReportReasonData(
      reason: ReportReason.hateSpeech,
      icon: '🤬',
      title: 'Nefret Söylemi',
      description: 'Irk, din, cinsiyet veya kimliğe yönelik ayrımcılık',
    ),
    ReportReasonData(
      reason: ReportReason.violence,
      icon: '⚠️',
      title: 'Şiddet / Tehdit',
      description: 'Şiddet içeren, tehditkâr veya korkutucu içerik',
    ),
    ReportReasonData(
      reason: ReportReason.nudity,
      icon: '🔞',
      title: 'Müstehcen İçerik',
      description: 'Cinsel, çıplak veya uygunsuz görsel/metin',
    ),
    ReportReasonData(
      reason: ReportReason.fakeAccount,
      icon: '🎭',
      title: 'Sahte Hesap',
      description: 'Başka birinin kimliğine bürünme veya sahte profil',
    ),
    ReportReasonData(
      reason: ReportReason.scam,
      icon: '💸',
      title: 'Dolandırıcılık',
      description: 'Para, kişisel bilgi isteyen veya kandırmaya yönelik içerik',
    ),
    ReportReasonData(
      reason: ReportReason.other,
      icon: '📝',
      title: 'Diğer',
      description: 'Yukarıdakilerle eşleşmeyen başka bir sorun',
    ),
  ];

  /// Rapor gönder
  static Future<void> submitReport({
    required ReportType type,
    required ReportReason reason,
    required String reportedId,
    String? reportedUserId,
    String? extraNote,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Oturum açılmamış');

    // Aynı kullanıcı aynı şeyi tekrar raporlayamasın
    final existing = await _db
        .collection('reports')
        .where('reporterUid', isEqualTo: user.uid)
        .where('reportedId', isEqualTo: reportedId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw ReportException(
        code: 'already-reported',
        message: 'Bu içeriği zaten bildirmişsin',
      );
    }

    await _db.collection('reports').add({
      'reporterUid': user.uid,
      'reportedId': reportedId,
      'reportedUserId': reportedUserId ?? '',
      'type': type.name,
      'reason': reason.name,
      'extraNote': extraNote ?? '',
      'status': 'pending', // pending, reviewed, resolved, dismissed
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Belirli bir içeriğin bu kullanıcı tarafından raporlanıp raporlanmadığını kontrol et
  static Future<bool> isAlreadyReported(String reportedId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final existing = await _db
        .collection('reports')
        .where('reporterUid', isEqualTo: user.uid)
        .where('reportedId', isEqualTo: reportedId)
        .limit(1)
        .get();

    return existing.docs.isNotEmpty;
  }
}

class ReportException implements Exception {
  final String code;
  final String message;
  ReportException({required this.code, required this.message});

  @override
  String toString() => message;
}