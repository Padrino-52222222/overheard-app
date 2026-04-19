import 'dart:ui';
import 'package:HeardOver/services/friend_service.dart';
import 'package:HeardOver/services/karizma_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';


class UserProfileScreen extends StatefulWidget {
  final String username;
  final String? userId;

  const UserProfileScreen({
    super.key,
    required this.username,
    this.userId,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _profile;
  String? _targetUid;
  bool _isLoading = true;
  String _friendStatus = 'none'; // none, pending, friends
  bool _actionLoading = false;
  int _karizma = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      if (widget.userId != null) {
        _targetUid = widget.userId;
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();
        if (doc.exists) _profile = doc.data();
      } else {
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: widget.username)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          _profile = query.docs.first.data();
          _targetUid = query.docs.first.id;
        }
      }
      await _checkFriendStatus();
      // Karizma hesapla
      if (_targetUid != null) {
        _karizma = await KarizmaService.calculateKarizma(_targetUid!);
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _checkFriendStatus() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || _targetUid == null || myUid == _targetUid) return;

    final areFriends = await FriendService.areFriends(myUid, _targetUid!);
    if (areFriends) {
      _friendStatus = 'friends';
      return;
    }

    final pending = await FriendService.getPendingRequestId(myUid, _targetUid!);
    if (pending != null) {
      _friendStatus = 'pending';
    }
  }

  Future<void> _sendFriendRequest() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || _targetUid == null) return;

    setState(() => _actionLoading = true);
    await FriendService.sendRequest(fromUid: myUid, toUid: _targetUid!);
    if (mounted) {
      setState(() {
        _friendStatus = 'pending';
        _actionLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Arkadaşlık isteği gönderildi! 🎉',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF72246C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  String _val(String key) {
    if (_profile == null) return 'Belirtilmemiş';
    final v = _profile![key];
    if (v == null || (v is String && v.isEmpty)) return 'Belirtilmemiş';
    if (v is int && v == 0) return 'Belirtilmemiş';
    return v.toString();
  }

  bool get _isMe {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    return myUid != null && myUid == _targetUid;
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = _profile?['photoUrl'] as String?;
    final level = KarizmaService.getLevel(_karizma);
    final progress = KarizmaService.getProgress(_karizma);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFFD700),
                strokeWidth: 2.5,
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // ── Header ──
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
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
                          const SizedBox(width: 14),
                          Text(
                            '@${widget.username}',
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Profil Fotoğrafı ──
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF72246C), Color(0xFF9B30FF)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF9B30FF).withOpacity(0.4),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: photoUrl != null && photoUrl.isNotEmpty
                            ? Image.network(
                                photoUrl,
                                fit: BoxFit.cover,
                                width: 100,
                                height: 100,
                                errorBuilder: (_, __, ___) => _defaultAvatar(),
                              )
                            : _defaultAvatar(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── İsim ──
                    Text(
                      _val('fullName') != 'Belirtilmemiş'
                          ? _val('fullName')
                          : widget.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${widget.username}',
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    // ── Arkadaş Ekleme Butonu ──
                    if (!_isMe) ...[
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _friendStatus == 'none' && !_actionLoading
                                ? _sendFriendRequest
                                : null,
                            icon: Icon(
                              _friendStatus == 'friends'
                                  ? Icons.check_circle_rounded
                                  : _friendStatus == 'pending'
                                      ? Icons.hourglass_top_rounded
                                      : Icons.person_add_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            label: Text(
                              _friendStatus == 'friends'
                                  ? 'Arkadaşsınız ✓'
                                  : _friendStatus == 'pending'
                                      ? 'İstek Gönderildi'
                                      : 'Arkadaş Ekle',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _friendStatus == 'friends'
                                  ? const Color(0xFF4CAF50)
                                  : _friendStatus == 'pending'
                                      ? Colors.orange.shade700
                                      : const Color(0xFF72246C),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ── Karizma Kartı ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF1A1035),
                              Color(0xFF0F0A1F),
                            ],
                          ),
                          border: Border.all(
                            color: const Color(0xFFFFD700).withOpacity(0.15),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF1E88E5),
                                        Color(0xFF9B30FF),
                                        Color(0xFFFF8C00),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF9B30FF)
                                            .withOpacity(0.4),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.local_fire_department_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Karizma',
                                  style: TextStyle(
                                    color: Color(0xFFFFD700),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              KarizmaService.format(_karizma),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Progress bar
                            Container(
                              width: double.infinity,
                              height: 5,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                color: Colors.white.withOpacity(0.06),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: progress,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(3),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF1E88E5),
                                        Color(0xFF9B30FF),
                                        Color(0xFFFF8C00),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Seviye: $level',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.35),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Bilgi Kartları ──
                    if (_profile != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            _infoRow(Icons.person_rounded, 'İsim', _val('fullName')),
                            const SizedBox(height: 10),
                            _infoRow(Icons.cake_outlined, 'Yaş', _val('age')),
                            const SizedBox(height: 10),
                            _infoRow(Icons.location_city_rounded, 'Şehir', _val('city')),
                            const SizedBox(height: 10),
                            _infoRow(Icons.wc_rounded, 'Cinsiyet', _val('gender')),
                          ],
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Text(
                          'Kullanıcı bilgileri bulunamadı',
                          style: TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      width: 100,
      height: 100,
      color: const Color(0xFF72246C),
      child: Center(
        child: Text(
          widget.username.isNotEmpty ? widget.username[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF1A1A2E),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFF0A0A0F),
            ),
            child: Icon(icon, color: const Color(0xFF888888), size: 18),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFFE8E8E8),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}