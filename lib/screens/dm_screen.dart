import 'package:HeardOver/screens/dm_chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DmScreen extends StatefulWidget {
  const DmScreen({super.key});

  @override
  State<DmScreen> createState() => _DmScreenState();
}

class _DmScreenState extends State<DmScreen> {
  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Color _avatarColor(String username) {
    final colors = [
      const Color(0xFF72246C),
      const Color(0xFF1E88E5),
      const Color(0xFFE53935),
      const Color(0xFF43A047),
      const Color(0xFFFF8F00),
      const Color(0xFF8E24AA),
      const Color(0xFF00ACC1),
    ];
    return colors[username.hashCode.abs() % colors.length];
  }

  // ── Sohbet Sil ──
  Future<void> _deleteConversation(String chatId) async {
    try {
      // Alt koleksiyondaki mesajları sil
      final messages = await FirebaseFirestore.instance
          .collection('directMessages')
          .doc(chatId)
          .collection('messages')
          .get();
      for (final doc in messages.docs) {
        await doc.reference.delete();
      }
      // Ana dokümanı sil
      await FirebaseFirestore.instance
          .collection('directMessages')
          .doc(chatId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Sohbet silindi',
                style: TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF72246C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // ── Başa Tuttur / Kaldır ──
  Future<void> _togglePin(String chatId, bool currentlyPinned) async {
    try {
      await FirebaseFirestore.instance
          .collection('directMessages')
          .doc(chatId)
          .update({
        'pinnedBy_$_myUid': !currentlyPinned,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentlyPinned ? 'Tutturma kaldırıldı' : 'Sohbet başa tutturuldu 📌',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF72246C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (_) {}
  }

  // ── Sessize Al / Aç ──
  Future<void> _toggleMute(String chatId, bool currentlyMuted) async {
    try {
      await FirebaseFirestore.instance
          .collection('directMessages')
          .doc(chatId)
          .update({
        'mutedBy_$_myUid': !currentlyMuted,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentlyMuted ? 'Sessiz mod kapatıldı 🔔' : 'Sohbet sessize alındı 🔇',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF72246C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (_) {}
  }

  // ── Basılı tut menüsü ──
  void _showChatOptions(String chatId, String username, bool isPinned, bool isMuted) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF12121F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '@$username',
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),

            // Başa Tuttur
            _optionTile(
              icon: isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
              label: isPinned ? 'Tutturmayı Kaldır' : 'Başa Tuttur',
              color: const Color(0xFFFFD700),
              onTap: () {
                Navigator.pop(ctx);
                _togglePin(chatId, isPinned);
              },
            ),
            const SizedBox(height: 10),

            // Sessize Al
            _optionTile(
              icon: isMuted ? Icons.notifications_rounded : Icons.notifications_off_rounded,
              label: isMuted ? 'Sessizden Çıkar' : 'Sessize Al',
              color: const Color(0xFF1E88E5),
              onTap: () {
                Navigator.pop(ctx);
                _toggleMute(chatId, isMuted);
              },
            ),
            const SizedBox(height: 10),

            // Sohbeti Sil
            _optionTile(
              icon: Icons.delete_forever_rounded,
              label: 'Sohbeti Sil',
              color: Colors.red.shade400,
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteConversationConfirm(chatId, username);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _optionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: color.withOpacity(0.08),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConversationConfirm(String chatId, String username) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF12121F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.shade700.withOpacity(0.15),
                border: Border.all(color: Colors.red.shade700.withOpacity(0.3), width: 2),
              ),
              child: Icon(Icons.delete_forever_rounded, color: Colors.red.shade400, size: 30),
            ),
            const SizedBox(height: 16),
            const Text('Sohbeti Sil',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(
              '@$username ile olan tüm mesajlar\nkalıcı olarak silinecek.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.white.withOpacity(0.06),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: const Center(
                        child: Text('Vazgeç',
                            style: TextStyle(color: Colors.white54, fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _deleteConversation(chatId);
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(colors: [Colors.red.shade700, Colors.red.shade900]),
                      ),
                      child: const Center(
                        child: Text('Evet, Sil',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
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
                      child: const Icon(Icons.mail_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'Mesajlar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      const Color(0xFFFFD700).withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── DM Listesi ──
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('directMessages')
                      .where('participants', arrayContains: _myUid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFFFFD700), strokeWidth: 2.5),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Bir hata oluştu',
                            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14)),
                      );
                    }

                    var docs = snapshot.data?.docs ?? [];

                    // Pinned olanları başa, sonra lastMessageAt'e göre sırala
                    docs.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aPinned = aData['pinnedBy_$_myUid'] == true;
                      final bPinned = bData['pinnedBy_$_myUid'] == true;
                      if (aPinned && !bPinned) return -1;
                      if (!aPinned && bPinned) return 1;
                      final aTime = aData['lastMessageAt'] as Timestamp?;
                      final bTime = bData['lastMessageAt'] as Timestamp?;
                      if (aTime == null && bTime == null) return 0;
                      if (aTime == null) return 1;
                      if (bTime == null) return -1;
                      return bTime.compareTo(aTime);
                    });

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded,
                                color: Colors.white.withOpacity(0.1), size: 64),
                            const SizedBox(height: 16),
                            Text('Henüz mesajın yok',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.2),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text('Arkadaş ekle ve sohbete başla! 💬',
                                style: TextStyle(color: Colors.white.withOpacity(0.12), fontSize: 13)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final chatDoc = docs[index];
                        final data = chatDoc.data() as Map<String, dynamic>;
                        final chatId = chatDoc.id;
                        final participants = List<String>.from(data['participants'] ?? []);
                        final lastMessage = data['lastMessage'] as String? ?? '';
                        final lastMessageAt = data['lastMessageAt'] as Timestamp?;
                        final isPinned = data['pinnedBy_$_myUid'] == true;
                        final isMuted = data['mutedBy_$_myUid'] == true;

                        final friendUid = participants.firstWhere(
                          (uid) => uid != _myUid,
                          orElse: () => '',
                        );
                        if (friendUid.isEmpty) return const SizedBox.shrink();

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(friendUid)
                              .get(),
                          builder: (context, userSnap) {
                            if (!userSnap.hasData || userSnap.data?.exists != true) {
                              return const SizedBox.shrink();
                            }

                            final userData = userSnap.data!.data() as Map<String, dynamic>;
                            final username = userData['username'] as String? ?? 'anonim';
                            final photoUrl = userData['photoUrl'] as String?;
                            final color = _avatarColor(username);

                            String timeText = '';
                            if (lastMessageAt != null) {
                              final dt = lastMessageAt.toDate();
                              final now = DateTime.now();
                              final diff = now.difference(dt);
                              if (diff.inMinutes < 1) {
                                timeText = 'Şimdi';
                              } else if (diff.inMinutes < 60) {
                                timeText = '${diff.inMinutes}dk';
                              } else if (diff.inHours < 24) {
                                timeText = '${diff.inHours}sa';
                              } else {
                                timeText =
                                    '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}';
                              }
                            }

                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => DmChatScreen(
                                      friendUid: friendUid,
                                      friendUsername: username,
                                      friendPhotoUrl: photoUrl,
                                    ),
                                  ),
                                );
                              },
                              onLongPress: () {
                                _showChatOptions(chatId, username, isPinned, isMuted);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: isPinned
                                        ? [
                                            const Color(0xFFFFD700).withOpacity(0.08),
                                            const Color(0xFFFF8C00).withOpacity(0.03),
                                          ]
                                        : [
                                            Colors.white.withOpacity(0.06),
                                            Colors.white.withOpacity(0.02),
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isPinned
                                        ? const Color(0xFFFFD700).withOpacity(0.2)
                                        : Colors.white.withOpacity(0.06),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Avatar
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(color: color.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3)),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: photoUrl != null && photoUrl.isNotEmpty
                                            ? Image.network(photoUrl, fit: BoxFit.cover, width: 52, height: 52,
                                                errorBuilder: (_, __, ___) => CircleAvatar(
                                                    radius: 26,
                                                    backgroundColor: color,
                                                    child: Text(username[0].toUpperCase(),
                                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))))
                                            : CircleAvatar(
                                                radius: 26,
                                                backgroundColor: color,
                                                child: Text(username[0].toUpperCase(),
                                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text('@$username',
                                                  style: const TextStyle(
                                                      color: Color(0xFFFFD700),
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 15,
                                                      letterSpacing: -0.2)),
                                              if (isPinned) ...[
                                                const SizedBox(width: 6),
                                                const Icon(Icons.push_pin_rounded, color: Color(0xFFFFD700), size: 14),
                                              ],
                                              if (isMuted) ...[
                                                const SizedBox(width: 4),
                                                Icon(Icons.notifications_off_rounded, color: Colors.white.withOpacity(0.3), size: 14),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(lastMessage,
                                              style: TextStyle(
                                                  color: Colors.white.withOpacity(0.45),
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w400,
                                                  height: 1.3),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    if (timeText.isNotEmpty)
                                      Text(timeText,
                                          style: TextStyle(
                                              color: Colors.white.withOpacity(0.25),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            );
                          },
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