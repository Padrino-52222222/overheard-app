import 'package:HeardOver/services/notification_trigger_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationPanel extends StatefulWidget {
  final VoidCallback onClose;

  const NotificationPanel({super.key, required this.onClose});

  @override
  State<NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<NotificationPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

    _animCtrl.forward();

    // Panel açılınca tümünü okundu işaretle
    Future.delayed(const Duration(milliseconds: 800), () {
      NotificationTriggerService.markAllRead(_myUid);
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inSeconds < 60) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk';
    if (diff.inHours < 24) return '${diff.inHours}sa';
    if (diff.inDays < 7) return '${diff.inDays}g';
    final d = ts.toDate();
    return '${d.day}/${d.month}';
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'friendRequest':
        return const Color(0xFF1E88E5);
      case 'friendAccepted':
        return const Color(0xFF4CAF50);
      case 'friendPost':
        return const Color(0xFF9B30FF);
      case 'dm':
        return const Color(0xFF1E88E5);
      case 'like':
        return const Color(0xFFE53935);
      case 'milestoneLike':
        return const Color(0xFFFFD700);
      case 'vitrinExpired':
        return const Color(0xFFFF8C00);
      default:
        return const Color(0xFFFFD700);
    }
  }

  String _emojiFor(String type) {
    switch (type) {
      case 'friendRequest':
        return '🤝';
      case 'friendAccepted':
        return '🎉';
      case 'friendPost':
        return '📢';
      case 'dm':
        return '💬';
      case 'like':
        return '❤️';
      case 'milestoneLike':
        return '🌟';
      case 'vitrinExpired':
        return '⏰';
      default:
        return '🔔';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: const Color(0xFF0F0F1A),
            border: Border.all(
              color: const Color(0xFFFFD700).withOpacity(0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [
                          Color(0xFFFFD700),
                          Color(0xFFFF8C00),
                        ]),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.notifications_rounded,
                          color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Bildirimler',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.07),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.1)),
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white54, size: 16),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Divider ──
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    const Color(0xFFFFD700).withOpacity(0.15),
                    Colors.transparent,
                  ]),
                ),
              ),

              // ── İçerik ──
              StreamBuilder<QuerySnapshot>(
                stream: NotificationTriggerService.notificationsStream(
                    _myUid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFFFFD700), strokeWidth: 2),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 36),
                      child: Column(
                        children: [
                          Text('🔔', style: TextStyle(fontSize: 38)),
                          SizedBox(height: 10),
                          Text(
                            'Henüz bildirim yok',
                            style: TextStyle(
                              color: Colors.white24,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 340),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      shrinkWrap: true,
                      itemCount: docs.length,
                      itemBuilder: (ctx, i) {
                        final data =
                            docs[i].data() as Map<String, dynamic>;
                        final type =
                            data['type'] as String? ?? 'general';
                        final title = data['title'] as String? ?? '';
                        final body = data['body'] as String? ?? '';
                        final createdAt = data['createdAt'] as Timestamp?;
                        final isRead = data['isRead'] as bool? ?? true;
                        final color = _colorFor(type);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: isRead
                                ? color.withOpacity(0.04)
                                : color.withOpacity(0.08),
                            border: Border.all(
                              color: isRead
                                  ? color.withOpacity(0.08)
                                  : color.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color.withOpacity(0.12),
                                ),
                                child: Center(
                                  child: Text(_emojiFor(type),
                                      style: const TextStyle(fontSize: 16)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: TextStyle(
                                        color: isRead
                                            ? Colors.white70
                                            : Colors.white,
                                        fontSize: 13,
                                        fontWeight: isRead
                                            ? FontWeight.w500
                                            : FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      body,
                                      style: TextStyle(
                                        color:
                                            Colors.white.withOpacity(0.5),
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _timeAgo(createdAt),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.25),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (!isRead) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      width: 7,
                                      height: 7,
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
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}