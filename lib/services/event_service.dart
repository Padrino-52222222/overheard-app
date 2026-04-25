import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/event_model.dart';

class EventService {
  static final _db = FirebaseFirestore.instance;

  static const List<String> _istanbulAvrupa = [
    'Arnavutköy', 'Avcılar', 'Bağcılar', 'Bahçelievler', 'Bakırköy',
    'Başakşehir', 'Bayrampaşa', 'Beşiktaş', 'Beylikdüzü', 'Beyoğlu',
    'Büyükçekmece', 'Çatalca', 'Esenler', 'Esenyurt', 'Eyüpsultan',
    'Fatih', 'Gaziosmanpaşa', 'Güngören', 'Kağıthane', 'Küçükçekmece',
    'Sarıyer', 'Silivri', 'Sultangazi', 'Şişli', 'Zeytinburnu',
  ];

  static const List<String> _istanbulAnadolu = [
    'Adalar', 'Ataşehir', 'Beykoz', 'Çekmeköy', 'Kadıköy',
    'Kartal', 'Maltepe', 'Pendik', 'Sancaktepe', 'Sultanbeyli',
    'Şile', 'Tuzla', 'Ümraniye', 'Üsküdar',
  ];

  static const List<String> cities = [
    'İstanbul Avrupa',
    'İstanbul Anadolu',
    'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Aksaray', 'Amasya',
    'Ankara', 'Antalya', 'Ardahan', 'Artvin', 'Aydın', 'Balıkesir',
    'Bartın', 'Batman', 'Bayburt', 'Bilecik', 'Bingöl', 'Bitlis',
    'Bolu', 'Burdur', 'Bursa', 'Çanakkale', 'Çankırı', 'Çorum',
    'Denizli', 'Diyarbakır', 'Düzce', 'Edirne', 'Elazığ', 'Erzincan',
    'Erzurum', 'Eskişehir', 'Gaziantep', 'Giresun', 'Gümüşhane',
    'Hakkari', 'Hatay', 'Iğdır', 'Isparta', 'İzmir', 'Kahramanmaraş',
    'Karabük', 'Karaman', 'Kars', 'Kastamonu', 'Kayseri', 'Kilis',
    'Kırıkkale', 'Kırklareli', 'Kırşehir', 'Kocaeli', 'Konya', 'Kütahya',
    'Malatya', 'Manisa', 'Mardin', 'Mersin', 'Muğla', 'Muş',
    'Nevşehir', 'Niğde', 'Ordu', 'Osmaniye', 'Rize', 'Sakarya',
    'Samsun', 'Siirt', 'Sinop', 'Sivas', 'Şanlıurfa', 'Şırnak',
    'Tekirdağ', 'Tokat', 'Trabzon', 'Tunceli', 'Uşak', 'Van',
    'Yalova', 'Yozgat', 'Zonguldak',
  ];

  // İnternetten güvenilir saat al
  static Future<DateTime> getInternetTime() async {
    try {
      final res = await http
          .get(Uri.parse(
              'http://worldtimeapi.org/api/timezone/Europe/Istanbul'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return DateTime.parse(data['datetime']);
      }
    } catch (_) {}
    return DateTime.now(); // fallback
  }

  // Kullanıcının şehrini al
  static Future<String?> getUserCity() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (marks.isNotEmpty) {
        final p = marks.first;
        final sub = p.subLocality ?? '';
        final loc = p.locality ?? '';
        final admin = p.administrativeArea ?? '';

        if (admin.contains('İstanbul') || admin.contains('Istanbul')) {
          for (final d in _istanbulAvrupa) {
            if (sub.contains(d) || loc.contains(d)) return 'İstanbul Avrupa';
          }
          for (final d in _istanbulAnadolu) {
            if (sub.contains(d) || loc.contains(d)) return 'İstanbul Anadolu';
          }
          // Boğaz'ın batısı Avrupa, doğusu Anadolu (lon ~29.0)
          return pos.longitude < 29.0 ? 'İstanbul Avrupa' : 'İstanbul Anadolu';
        }

        if (admin.isNotEmpty) return admin;
        if (loc.isNotEmpty) return loc;
      }
    } catch (_) {}
    return null;
  }

  // Kullanıcı etkinlikte paylaşım yapabilir mi?
  static Future<Map<String, dynamic>> canUserPost(EventModel event) async {
    final now = await getInternetTime();
    if (now.isBefore(event.startDateTime) || now.isAfter(event.endDateTime)) {
      return {'canPost': false, 'reason': 'Etkinlik şu an aktif değil.'};
    }

    final userCity = await getUserCity();
    if (userCity == null) {
      return {'canPost': false, 'reason': 'Konum alınamadı, lütfen izin ver.'};
    }

    final e = event.city.toLowerCase().trim();
    final u = userCity.toLowerCase().trim();
    if (e != u && !e.contains(u) && !u.contains(e)) {
      return {
        'canPost': false,
        'reason':
            'Bu etkinlik ${event.city} için. Şu an $userCity konumundasın.',
      };
    }

    return {'canPost': true, 'reason': ''};
  }

  // Etkinlik oluştur
  static Future<void> createEvent(EventModel event) async {
    await _db.collection('events').add(event.toMap());
  }

  // Etkinlikleri stream olarak getir
  static Stream<List<EventModel>> eventsStream() {
    return _db
        .collection('events')
        .orderBy('startDateTime', descending: false)
        .snapshots()
        .map((s) => s.docs.map(EventModel.fromDoc).toList());
  }

  // Katılımı toggle et
  static Future<void> toggleAttendance(String eventId, String uid) async {
    final ref = _db.collection('events').doc(eventId);
    final doc = await ref.get();
    final data = doc.data() as Map<String, dynamic>;
    final list = List<String>.from(data['attendees'] ?? []);
    list.contains(uid) ? list.remove(uid) : list.add(uid);
    await ref.update({'attendees': list});
  }

  // Etkinliğe post at
  static Future<void> createEventPost({
    required String eventId,
    required String text,
    required String username,
    required String uid,
  }) async {
    await _db
        .collection('events')
        .doc(eventId)
        .collection('posts')
        .add({
      'text': text,
      'username': username,
      'uid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Etkinlik postlarını stream olarak getir
  static Stream<QuerySnapshot> eventPostsStream(String eventId) {
    return _db
        .collection('events')
        .doc(eventId)
        .collection('posts')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }
}