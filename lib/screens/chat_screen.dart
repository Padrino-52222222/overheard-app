import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class ChatScreen extends StatefulWidget {
  final bool showHeader; // ← EKLE

  const ChatScreen({super.key, this.showHeader = true}); // ← GÜNCELLE

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final ValueNotifier<bool> _canSend = ValueNotifier(true);
  final ValueNotifier<int> _cooldownSeconds = ValueNotifier(0);

  Timer? _cooldownTimer;
  Timer? _cleanupTimer;
  String _username = 'anonim';
  String _uid = '';

  static const int _cooldownDuration = 8;
  static const int _messageLifetime = 30;

  late final Stream<QuerySnapshot> _chatStream;

  @override
  void initState() {
    super.initState();
    _chatStream = _db
        .collection('globalChat')
        .orderBy('createdAt', descending: false)
        .snapshots();
    _loadUserInfo();
    _startCleanupTimer();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    _cooldownTimer?.cancel();
    _cleanupTimer?.cancel();
    _canSend.dispose();
    _cooldownSeconds.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final profile = await AuthService.getUserProfile();
    if (profile != null && mounted) {
      setState(() {
        _username = profile['username'] ?? 'anonim';
        _uid = profile['uid'] ?? '';
      });
    }
  }

  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final cutoff = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(seconds: _messageLifetime)),
      );
      try {
        final oldMessages = await _db
            .collection('globalChat')
            .where('createdAt', isLessThan: cutoff)
            .get();
        for (final doc in oldMessages.docs) {
          await doc.reference.delete();
        }
      } catch (_) {}
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || !_canSend.value) return;

    _msgController.clear();

    try {
      await _db.collection('globalChat').add({
        'text': text,
        'username': _username,
        'uid': _uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Mesaj gönderilemedi'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    _canSend.value = false;
    _cooldownSeconds.value = _cooldownDuration;

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _cooldownSeconds.value--;
      if (_cooldownSeconds.value <= 0) {
        _canSend.value = true;
        timer.cancel();
      }
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _timeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'şimdi';
    final diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inSeconds < 5) return 'şimdi';
    if (diff.inSeconds < 60) return '${diff.inSeconds}sn';
    return '${diff.inMinutes}dk';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0A0F),
      child: Column(
        children: [
          // ── Sadece standalone modda header göster ──
          if (widget.showHeader) ...[
            SizedBox(height: MediaQuery.of(context).padding.top + 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
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
                    child: const Icon(Icons.forum_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Genel Sohbet',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Mesajlar ${_messageLifetime}sn sonra silinir',
                            style: const TextStyle(
                              color: Color(0xFF555555),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                height: 1,
                color: const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
          ],
          // ────────────────────────────────────

          // ── Mesajlar ──
          Expanded(
            // ... mevcut StreamBuilder kodu aynen kalır (satır 231'den itibaren)(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFFFFD700),
                      ),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('💬', style: TextStyle(fontSize: 48)),
                        SizedBox(height: 12),
                        Text(
                          'Henüz mesaj yok\nİlk mesajı sen gönder!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF555555),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final msgUid = data['uid'] ?? '';
                    final isMe = msgUid == _uid;
                    final username = data['username'] ?? 'anonim';
                    final text = data['text'] ?? '';
                    final createdAt = data['createdAt'] as Timestamp?;

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 16),
                          ),
                          gradient: isMe
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF72246C),
                                    Color(0xFF9B30FF),
                                  ],
                                )
                              : null,
                          color: isMe ? null : const Color(0xFF1A1A2E),
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
                                  '@$username',
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
                                  _timeAgo(createdAt),
                                  style: const TextStyle(
                                    color: Color(0xFF666666),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              text,
                              style: const TextStyle(
                                color: Color(0xFFE8E8E8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
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

          // ── Input ──
          ValueListenableBuilder<bool>(
            valueListenable: _canSend,
            builder: (context, canSend, _) {
              return ValueListenableBuilder<int>(
                valueListenable: _cooldownSeconds,
                builder: (context, seconds, _) {
                  return Container(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 12,
                      bottom: 90,
                    ),
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
                              controller: _msgController,
                              maxLength: 150,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: canSend
                                    ? 'Mesajın...'
                                    : 'Bekle... $seconds saniye',
                                hintStyle: const TextStyle(
                                  color: Color(0xFF444444),
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                counterText: '',
                              ),
                              enabled: canSend,
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: canSend ? _sendMessage : null,
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: canSend
                                  ? const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFFFFD700),
                                        Color(0xFFFF8C00),
                                      ],
                                    )
                                  : null,
                              color: canSend ? null : const Color(0xFF1A1A2E),
                            ),
                            child: Center(
                              child: canSend
                                  ? const Icon(Icons.send_rounded,
                                      color: Colors.white, size: 20)
                                  : Text(
                                      '$seconds',
                                      style: const TextStyle(
                                        color: Color(0xFF555555),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
