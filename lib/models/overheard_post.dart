class OverheardPost {
  final String id;
  final String text;
  final String authorName;
  final String city;
  final String district;
  final DateTime dateTime;
  final double latitude;
  final double longitude;
  final String? userId;
  final DateTime? vitrinUntil;

  const OverheardPost({
    required this.id,
    required this.text,
    required this.authorName,
    required this.city,
    required this.district,
    required this.dateTime,
    required this.latitude,
    required this.longitude,
    this.userId,
    this.vitrinUntil,
  });

  String get cleanUsername => authorName.replaceAll('@', '');

  String get locationLabel => '$city/$district';

  bool get isInVitrin =>
      vitrinUntil != null && vitrinUntil!.isAfter(DateTime.now());

  String get formattedDate {
    final d = dateTime;
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'authorName': authorName,
        'city': city,
        'district': district,
        'dateTime': dateTime.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'userId': userId,
        'vitrinUntil': vitrinUntil?.toIso8601String(),
      };

  factory OverheardPost.fromJson(Map<String, dynamic> json) {
    DateTime? vitrin;
    if (json['vitrinUntil'] != null && json['vitrinUntil'] is String) {
      try {
        vitrin = DateTime.parse(json['vitrinUntil']);
      } catch (_) {}
    }

    return OverheardPost(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      authorName: json['authorName'] ?? 'Anonim',
      city: json['city'] ?? '',
      district: json['district'] ?? '',
      dateTime: json['dateTime'] is String
          ? DateTime.parse(json['dateTime'])
          : DateTime.now(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      userId: json['userId'],
      vitrinUntil: vitrin,
    );
  }
}