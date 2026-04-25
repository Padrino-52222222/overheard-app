import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String creatorUid;
  final String creatorUsername;
  final String title;
  final String description;
  final String city;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final List<String> attendees;
  final Timestamp createdAt;

  const EventModel({
    required this.id,
    required this.creatorUid,
    required this.creatorUsername,
    required this.title,
    required this.description,
    required this.city,
    required this.startDateTime,
    required this.endDateTime,
    required this.attendees,
    required this.createdAt,
  });

  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDateTime) && now.isBefore(endDateTime);
  }

  bool get isUpcoming => DateTime.now().isBefore(startDateTime);
  bool get isPast => DateTime.now().isAfter(endDateTime);

  Duration get timeUntilStart => startDateTime.difference(DateTime.now());

  factory EventModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return EventModel(
      id: doc.id,
      creatorUid: d['creatorUid'] ?? '',
      creatorUsername: d['creatorUsername'] ?? 'anonim',
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      city: d['city'] ?? '',
      startDateTime: (d['startDateTime'] as Timestamp).toDate(),
      endDateTime: (d['endDateTime'] as Timestamp).toDate(),
      attendees: List<String>.from(d['attendees'] ?? []),
      createdAt: d['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'creatorUid': creatorUid,
        'creatorUsername': creatorUsername,
        'title': title,
        'description': description,
        'city': city,
        'startDateTime': Timestamp.fromDate(startDateTime),
        'endDateTime': Timestamp.fromDate(endDateTime),
        'attendees': attendees,
        'createdAt': FieldValue.serverTimestamp(),
      };
}