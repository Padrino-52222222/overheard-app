import 'package:HeardOver/screens/dm_chat_screen.dart';
import 'package:HeardOver/screens/friend_screen.dart';
import 'package:HeardOver/screens/my_post_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/notification_trigger_service.dart';

class NotificationsScreen extends StatefulWidget {
  final void Function(double lat, double lng)? onGoToMap;

  const NotificationsScreen({super.key, this.onGoToMap});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      NotificationTriggerService.markAllRead(_myUid);
    });
  }

  Future<void> _handleTap(Map<String, dynamic> data) async {
    final type = data['type'] as String? ?? 'general';
    final extra = Map<String, dynamic>.from(data['extra'] ?? {});

    switch (type) {
      case 'friendRequest':
      case 'friendAccepted':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FriendsScreen()),
        );
        break;

      case 'dm':
        final friendUid = extra['friendUid'] as String?;
        final friendUsername =
            extra['friendUsername'] as String? ?? 'anonim';
        if (friendUid != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(friendUid)
              .get();
          final photoUrl = userDoc.data()?['photoUrl'] as String?;
          if (mounted) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => DmChatScreen(
                friendUid: friendUid,
                friendUsername: friendUsername,
                friendPhotoUrl: photoUrl,
              ),
            ));
          }
        }
        break;

      case 'like':
      case 'milestoneLike':
      case 'vitrinExpired':
      case 'friendPost':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MyPostsScreen()),
        );
        if (type == 'like' || type == 'milestoneLike') {
          final lat = (extra['postLat'] as num?)?.toDouble();
          final lng = (extra['postLng'] as num?)?.toDouble();
          if (lat != null && lng != null && widget.onGoToMap != null) {
            widget.onGoToMap!(lat, lng);
          }
        }
        break;

      default:
        break;
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'friendRequest':
        return Icons.person_add_rounded;
      case 'friendAccepted':
        return Icons.people_rounded;
      case 'friendPost':
        return Icons.post_add_rounded;
      case 'dm':
        return Icons.chat_bubble_rounded;
      case 'like':
        return Icons.favorite_rounded;
      case 'milestoneLike':
        return Icons.star_rounded;
      case 'vitrinExpired':
        return Icons.timer_off_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'friendRequest':
        return const Color(0xFF9B30FF);
      case 'friendAccepted':
        return const Color(0xFF4CAF50);
      case 'friendPost':
        return const Color(0xFF9B30FF);
      case 'dm':
        return const Color(0xFF1E88E5);
      case 'like':
        return const Color(0xFFE91E63);
      case 'milestoneLike':
        return const Color(0xFFFFD700);
      case 'vitrinExpired':
        return const Color(0xFFFF8C00);
      default:
        return const Color(0xFFFFD700);
    }
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'Şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk önce';
    if (diff.inHours < 24) return '${diff.inHours}sa önce';
    return '${diff.inDays}g önce';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0F1A), Color(0xFF0A0A0F)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.notifications_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'Bildirimler',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () =>
                          NotificationTriggerService.markAllRead(_myUid),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white.withOpacity(0.06),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Text(
                          'Tümü okundu',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    const Color(0xFFFFD700).withOpacity(0.15),
                    Colors.transparent,
                  ]),
                ),
              ),
              const SizedBox(height: 8),

              // ── Liste ──
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: NotificationTriggerService.notificationsStream(
                      _myUid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFFFFD700), strokeWidth: 2.5),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_off_rounded,
                                color: Colors.white.withOpacity(0.1),
                                size: 64),
                            const SizedBox(height: 16),
                            Text(
                              'Henüz bildirim yok',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.2),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Arkadaşlık isteği, beğeni ve mesajlar burada görünür',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.1),
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data =
                            doc.data() as Map<String, dynamic>;
                        final type =
                            data['type'] as String? ?? 'general';
                        final title = data['title'] as String? ?? '';
                        final body = data['body'] as String? ?? '';
                        final isRead =
                            data['isRead'] as bool? ?? true;
                        final createdAt =
                            data['createdAt'] as Timestamp?;
                        final color = _colorFor(type);

                        return GestureDetector(
                          onTap: () {
                            doc.reference.update({'isRead': true});
                            _handleTap(data);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isRead
                                    ? [
                                        Colors.white.withOpacity(0.04),
                                        Colors.white.withOpacity(0.01),
                                      ]
                                    : [
                                        color.withOpacity(0.1),
                                        color.withOpacity(0.03),
                                      ],
                              ),
                              border: Border.all(
                                color: isRead
                                    ? Colors.white.withOpacity(0.05)
                                    : color.withOpacity(0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: color.withOpacity(0.15),
                                    border: Border.all(
                                        color: color.withOpacity(0.3)),
                                  ),
                                  child: Icon(_iconFor(type),
                                      color: color, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(title,
                                          style: TextStyle(
                                              color: isRead
                                                  ? Colors.white70
                                                  : Colors.white,
                                              fontSize: 14,
                                              fontWeight: isRead
                                                  ? FontWeight.w500
                                                  : FontWeight.w700)),
                                      const SizedBox(height: 3),
                                      Text(body,
                                          style: TextStyle(
                                              color: Colors.white
                                                  .withOpacity(0.4),
                                              fontSize: 12,
                                              height: 1.4),
                                          maxLines: 2,
                                          overflow:
                                              TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    Text(_timeAgo(createdAt),
                                        style: TextStyle(
                                            color: Colors.white
                                                .withOpacity(0.25),
                                            fontSize: 11)),
                                    if (!isRead) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: color,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}