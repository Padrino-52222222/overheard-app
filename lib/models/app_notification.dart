import 'package:flutter/material.dart';
enum NotifType {
  friendRequest,
  friendPost,
  dmMessage,
  postLike,
  nearbyPost,
}

class AppNotification {
  final String id;
  final NotifType type;
  final String title;
  final String body;
  final DateTime time;
  bool isRead;
  final String? targetId;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    this.isRead = false,
    this.targetId,
  });

  IconData get icon {
    switch (type) {
      case NotifType.friendRequest:
        return Icons.person_add_rounded;
      case NotifType.friendPost:
        return Icons.post_add_rounded;
      case NotifType.dmMessage:
        return Icons.mail_rounded;
      case NotifType.postLike:
        return Icons.favorite_rounded;
      case NotifType.nearbyPost:
        return Icons.location_on_rounded;
    }
  }

  String get iconEmoji {
    switch (type) {
      case NotifType.friendRequest:
        return '🤝';
      case NotifType.friendPost:
        return '📢';
      case NotifType.dmMessage:
        return '💬';
      case NotifType.postLike:
        return '❤️';
      case NotifType.nearbyPost:
        return '📍';
    }
  }
}
