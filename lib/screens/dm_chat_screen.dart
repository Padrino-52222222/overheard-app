import 'package:HeardOver/services/notification_trigger_service.dart';
import 'package:HeardOver/widgets/report_bottom.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/report_service.dart';

class DmChatScreen extends StatefulWidget {
  final String friendUid;
  final String friendUsername;
  final String? friendPhotoUrl;

  const DmChatScreen({
    super.key,
    required this.friendUid,
    required this.friendUsername,
    this.friendPhotoUrl,
  });

  @override
  State<DmChatScreen> createState() => _DmChatScreenState();
}

class _DmChatScreenState extends State<DmChatScreen> {
  final _controller = TextEditingController();
  late String _chatId;
  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    final ids = [_myUid, widget.friendUid]..sort();
    _chatId = '${ids[0]}_${ids[1]}';
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    await FirebaseFirestore.instance
        .collection('directMessages')
        .doc(_chatId)
        .collection('messages')
        .add({
      'text': text,
      'senderUid': _myUid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance
        .collection('directMessages')
        .doc(_chatId)
        .set({
      'participants': [_myUid, widget.friendUid],
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // ── DM Bildirimi ──
    try {
      final senderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_myUid)
          .get();
      final senderUsername = senderDoc.data()?['username'] ?? 'biri';
      final short = text.length > 30 ? '${text.substring(0, 30)}...' : text;
      await NotificationTriggerService.sendToUser(
        toUid: widget.friendUid,
        title: '💬 @$senderUsername',
        body: short,
        type: 'dm',
        extra: {
          'friendUid': _myUid,
          'friendUsername': senderUsername,
        },
      );
    } catch (_) {}
  }

  void _showMessageOptions(DocumentSnapshot msgDoc) {
    final data = msgDoc.data() as Map<String, dynamic>;
    final isMyMessage = data['senderUid'] == _myUid;
    final text = data['text'] ?? '';
    final senderUid = data['senderUid'] ?? '';

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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withOpacity(0.04),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Text(
                '"$text"',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),
            _optionTile(
              icon: Icons.push_pin_rounded,
              label: 'Başa Tuttur',
              color: const Color(0xFFFFD700),
              onTap: () {
                Navigator.pop(ctx);
                _pinMessage(msgDoc.id, text);
              },
            ),
            if (isMyMessage) ...[
              const SizedBox(height: 10),
              _optionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Mesajı Sil',
                color: Colors.red.shade400,
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(msgDoc);
                },
              ),
            ],
            if (!isMyMessage) ...[
              const SizedBox(height: 10),
              _optionTile(
                icon: Icons.report_rounded,
                label: 'Mesajı Bildir',
                color: Colors.red.shade400,
                onTap: () {
                  Navigator.pop(ctx);
                  ReportBottomSheet.show(
                    context: context,
                    type: ReportType.directMessage,
                    reportedId: msgDoc.id,
                    reportedUserId: senderUid,
                  );
                },
              ),
            ],
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
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(DocumentSnapshot msgDoc) async {
    try {
      await msgDoc.reference.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              const Text('Mesaj silindi', style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF72246C),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (_) {}
  }

  Future<void> _pinMessage(String messageId, String text) async {
    try {
      await FirebaseFirestore.instance
          .collection('directMessages')
          .doc(_chatId)
          .update({
        'pinnedMessage': text,
        'pinnedMessageId': messageId,
        'pinnedBy': _myUid,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Mesaj tutturuldu 📌',
              style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF72246C),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (_) {}
  }

  Future<void> _unpinMessage() async {
    try {
      await FirebaseFirestore.instance
          .collection('directMessages')
          .doc(_chatId)
          .update({
        'pinnedMessage': FieldValue.delete(),
        'pinnedMessageId': FieldValue.delete(),
        'pinnedBy': FieldValue.delete(),
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFF1A1A2E),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white54, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          colors: [Color(0xFF72246C), Color(0xFF9B30FF)]),
                    ),
                    child: ClipOval(
                      child: widget.friendPhotoUrl != null &&
                              widget.friendPhotoUrl!.isNotEmpty
                          ? Image.network(widget.friendPhotoUrl!,
                              fit: BoxFit.cover, width: 38, height: 38)
                          : Center(
                              child: Text(
                                  widget.friendUsername[0].toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('@${widget.friendUsername}',
                      style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              color: Colors.white.withOpacity(0.06),
            ),

            // Tutturulan mesaj banner
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('directMessages')
                  .doc(_chatId)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData || snap.data?.exists != true) {
                  return const SizedBox.shrink();
                }
                final chatData =
                    snap.data!.data() as Map<String, dynamic>? ?? {};
                final pinnedText = chatData['pinnedMessage'] as String?;
                if (pinnedText == null || pinnedText.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFFFD700).withOpacity(0.08),
                    border: Border.all(
                        color: const Color(0xFFFFD700).withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.push_pin_rounded,
                          color: Color(0xFFFFD700), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(pinnedText,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      GestureDetector(
                        onTap: _unpinMessage,
                        child: Icon(Icons.close_rounded,
                            color: Colors.white.withOpacity(0.3), size: 18),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Mesajlar
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('directMessages')
                    .doc(_chatId)
                    .collection('messages')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFFFFD700), strokeWidth: 2.5));
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return Center(
                      child: Text('Henüz mesaj yok\nİlk mesajı sen at! 👋',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.2),
                              fontSize: 15)),
                    );
                  }
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final msgDoc = docs[index];
                      final data = msgDoc.data() as Map<String, dynamic>;
                      final isMe = data['senderUid'] == _myUid;
                      final text = data['text'] ?? '';
                      return GestureDetector(
                        onLongPress: () => _showMessageOptions(msgDoc),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width *
                                          0.72),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: isMe
                                    ? const LinearGradient(colors: [
                                        Color(0xFF72246C),
                                        Color(0xFF9B30FF)
                                      ])
                                    : LinearGradient(colors: [
                                        Colors.white.withOpacity(0.08),
                                        Colors.white.withOpacity(0.04),
                                      ]),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft:
                                      Radius.circular(isMe ? 18 : 4),
                                  bottomRight:
                                      Radius.circular(isMe ? 4 : 18),
                                ),
                              ),
                              child: Text(text,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      height: 1.35)),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Input
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                border: Border(
                    top: BorderSide(
                        color: Colors.white.withOpacity(0.06), width: 1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Mesaj yaz...',
                          hintStyle: TextStyle(
                              color: Colors.white30, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                            colors: [Color(0xFF72246C), Color(0xFF9B30FF)]),
                      ),
                      child: const Icon(Icons.arrow_upward_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}