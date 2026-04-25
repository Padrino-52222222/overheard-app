import 'package:HeardOver/models/event_model.dart';
import 'package:HeardOver/services/auth_service.dart';
import 'package:HeardOver/services/event_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EventDetailScreen extends StatefulWidget {
  final EventModel event;
  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _username = 'anonim';
  String _uid = '';
  bool _checkingPost = false;
  bool _canPost = false;
  String _cannotReason = '';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    if (widget.event.isActive) _checkCanPost();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final p = await AuthService.getUserProfile();
    if (p != null && mounted) {
      setState(() {
        _username = p['username'] ?? 'anonim';
        _uid = p['uid'] ?? '';
      });
    }
  }

  Future<void> _checkCanPost() async {
    setState(() => _checkingPost = true);
    final result = await EventService.canUserPost(widget.event);
    if (mounted) {
      setState(() {
        _canPost = result['canPost'] as bool;
        _cannotReason = result['reason'] as String;
        _checkingPost = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    try {
      await EventService.createEventPost(
        eventId: widget.event.id,
        text: text,
        username: _username,
        uid: _uid,
      );
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return 'şimdi';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inSeconds < 5) return 'şimdi';
    if (diff.inSeconds < 60) return '${diff.inSeconds}sn';
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk';
    return '${diff.inHours}sa';
  }

  String _fmtDate(DateTime d) =>
      DateFormat('d MMM yyyy HH:mm', 'tr_TR').format(d);

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withOpacity(0.07),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      e.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Etkinlik Bilgi Kartı ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: e.isActive
                        ? [
                            const Color(0xFF4CAF50).withOpacity(0.08),
                            const Color(0xFF4CAF50).withOpacity(0.02),
                          ]
                        : e.isUpcoming
                            ? [
                                const Color(0xFFFFD700).withOpacity(0.08),
                                const Color(0xFFFF8C00).withOpacity(0.02),
                              ]
                            : [
                                Colors.white.withOpacity(0.04),
                                Colors.white.withOpacity(0.01),
                              ],
                    ),
                  border: Border.all(
                    color: e.isActive
                        ? const Color(0xFF4CAF50).withOpacity(0.2)
                        : e.isUpcoming
                            ? const Color(0xFFFFD700).withOpacity(0.2)
                            : Colors.white.withOpacity(0.06),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: (e.isActive
                                    ? const Color(0xFF4CAF50)
                                    : e.isUpcoming
                                        ? const Color(0xFFFFD700)
                                        : Colors.white38)
                                .withOpacity(0.12),
                          ),
                          child: Text(
                            e.isActive
                                ? '🟢 AKTİF'
                                : e.isUpcoming
                                    ? '🔵 YAKLAŞAN'
                                    : '⚫ SONA ERDİ',
                            style: TextStyle(
                              color: e.isActive
                                  ? const Color(0xFF4CAF50)
                                  : e.isUpcoming
                                      ? const Color(0xFFFFD700)
                                      : Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '@${e.creatorUsername}',
                          style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (e.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        e.description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _infoRow(Icons.location_on_rounded, e.city),
                    const SizedBox(height: 6),
                    _infoRow(Icons.play_circle_outline_rounded,
                        'Başlangıç: ${_fmtDate(e.startDateTime)}'),
                    const SizedBox(height: 6),
                    _infoRow(Icons.stop_circle_outlined,
                        'Bitiş: ${_fmtDate(e.endDateTime)}'),
                    const SizedBox(height: 6),
                    _infoRow(Icons.people_rounded,
                        '${e.attendees.length} kişi katılıyor'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Divider ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.forum_rounded,
                      color: Color(0xFFFFD700), size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    'Etkinlik Paylaşımları',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.white.withOpacity(0.07),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Postlar ──
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: EventService.eventPostsStream(e.id),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFFFD700), strokeWidth: 2),
                    );
                  }

                  final docs = snap.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('👂',
                              style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 10),
                          Text(
                            e.isActive
                                ? 'İlk paylaşımı sen yap!'
                                : 'Henüz paylaşım yapılmadı',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.25),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollCtrl.hasClients) {
                      _scrollCtrl.animateTo(
                        _scrollCtrl.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      );
                    }
                  });

                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    itemCount: docs.length,
                    itemBuilder: (ctx, i) {
                      final d = docs[i].data() as Map<String, dynamic>;
                      final isMe = d['uid'] == _uid;
                      return Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft:
                                  Radius.circular(isMe ? 16 : 4),
                              bottomRight:
                                  Radius.circular(isMe ? 4 : 16),
                            ),
                            gradient: isMe
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF72246C),
                                      Color(0xFF9B30FF),
                                    ],
                                  )
                                : null,
                            color:
                                isMe ? null : const Color(0xFF1A1A2E),
                          ),
                          child: Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '@${d['username'] ?? 'anonim'}',
                                    style: TextStyle(
                                      color: isMe
                                          ? const Color(0xFFCCAAFF)
                                          : const Color(0xFFDAAA00),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _timeAgo(d['createdAt'] as Timestamp?),
                                    style: const TextStyle(
                                      color: Color(0xFF666666),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                d['text'] ?? '',
                                style: const TextStyle(
                                  color: Color(0xFFE8E8E8),
                                  fontSize: 14,
                                  height: 1.3,
                                ),
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

            // ── Input / Kilitli mesaj ──
            _buildInputArea(e),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(EventModel e) {
    if (e.isPast) {
      return _lockedBanner(
          Icons.lock_clock_rounded, 'Bu etkinlik sona erdi');
    }

    if (e.isUpcoming) {
      return _lockedBanner(
          Icons.schedule_rounded, 'Etkinlik başladığında paylaşım yapabilirsin');
    }

    // Aktif etkinlik
    if (_checkingPost) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: const Color(0xFF0A0A0F),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFFFFD700)),
            ),
            SizedBox(width: 10),
            Text('Konum ve saat kontrol ediliyor...',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      );
    }

    if (!_canPost) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.red.shade900.withOpacity(0.15),
          border: Border.all(color: Colors.red.shade700.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.location_off_rounded,
                color: Colors.red.shade400, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _cannotReason,
                style: TextStyle(
                    color: Colors.red.shade300,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    // Paylaşım yapabilir
    return Container(
      padding: const EdgeInsets.only(
          left: 16, right: 16, top: 10, bottom: 16),
      color: const Color(0xFF0A0A0F),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: const Color(0xFF1A1A2E),
              ),
              child: TextField(
                controller: _msgCtrl,
                maxLength: 200,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Ne duydun? Paylaş...',
                  hintStyle:
                      TextStyle(color: Color(0xFF444444), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  counterText: '',
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 46, height: 46,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                ),
              ),
              child: _sending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lockedBanner(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      color: const Color(0xFF0A0A0F),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white24, size: 16),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(color: Colors.white24, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white38),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}