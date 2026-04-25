import 'package:HeardOver/screens/dm_chat_screen.dart';
import 'package:HeardOver/screens/user_post_screen.dart';
import 'package:HeardOver/screens/user_profile.dart';
import 'package:HeardOver/services/friend_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';


class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _friends = [];
  bool _isLoading = true;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final friends = await FriendService.getFriendsWithProfiles(_myUid);
    if (mounted) {
      setState(() {
        _friends = friends;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFF72246C),
      const Color(0xFF1E88E5),
      const Color(0xFFE53935),
      const Color(0xFF43A047),
      const Color(0xFFFF8F00),
      const Color(0xFF8E24AA),
      const Color(0xFF00ACC1),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  // ── Arkadaşı Çıkar ──
  void _showRemoveFriendConfirm(String friendUid, String username) {
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
              child: Icon(Icons.person_remove_rounded, color: Colors.red.shade400, size: 28),
            ),
            const SizedBox(height: 16),
            const Text('Arkadaşı Çıkar',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(
              '@$username artık arkadaş listenizde\ngörünmeyecek.',
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
                            style: TextStyle(
                                color: Colors.white54, fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _removeFriend(friendUid, username);
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(colors: [Colors.red.shade700, Colors.red.shade900]),
                      ),
                      child: const Center(
                        child: Text('Çıkar',
                            style: TextStyle(
                                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
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

  Future<void> _removeFriend(String friendUid, String username) async {
    try {
      await FriendService.removeFriend(_myUid, friendUid);
      _loadFriends();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('@$username arkadaş listenden çıkarıldı',
                style: const TextStyle(color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white54, size: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text('Arkadaşlarım',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(colors: [Color(0xFF72246C), Color(0xFF9B30FF)]),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white38,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                dividerColor: Colors.transparent,
                tabs: const [Tab(text: 'Arkadaşlar'), Tab(text: 'İstekler')],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildFriendsList(), _buildRequestsList()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsList() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFFD700), strokeWidth: 2.5));
    }

    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded, color: Colors.white.withOpacity(0.1), size: 64),
            const SizedBox(height: 16),
            Text('Henüz arkadaşın yok',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.2), fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Profillere git ve arkadaş ekle! 👋',
                style: TextStyle(color: Colors.white.withOpacity(0.12), fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _friends.length,
      itemBuilder: (context, index) {
        final friend = _friends[index];
        final username = friend['username'] ?? 'anonim';
        final photoUrl = friend['photoUrl'] as String?;
        final uid = friend['uid'] ?? '';

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => UserProfileScreen(username: username, userId: uid),
            ));
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.02)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              children: [
                // Avatar + isim + çıkar butonu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: _avatarColor(username).withOpacity(0.35), blurRadius: 10),
                        ],
                      ),
                      child: ClipOval(
                        child: photoUrl != null && photoUrl.isNotEmpty
                            ? Image.network(photoUrl, fit: BoxFit.cover, width: 50, height: 50,
                                errorBuilder: (_, __, ___) => CircleAvatar(
                                    radius: 25,
                                    backgroundColor: _avatarColor(username),
                                    child: Text(username[0].toUpperCase(),
                                        style: const TextStyle(
                                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))))
                            : CircleAvatar(
                                radius: 25,
                                backgroundColor: _avatarColor(username),
                                child: Text(username[0].toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text('@$username',
                          style: const TextStyle(
                              color: Color(0xFFFFD700), fontSize: 17, fontWeight: FontWeight.w700)),
                    ),
                    // Arkadaşı Çıkar butonu
                    GestureDetector(
                      onTap: () => _showRemoveFriendConfirm(uid, username),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.red.withOpacity(0.1),
                          border: Border.all(color: Colors.red.withOpacity(0.15)),
                        ),
                        child: Icon(Icons.person_remove_rounded, color: Colors.red.shade400, size: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Butonlar
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => DmChatScreen(
                                friendUid: uid, friendUsername: username, friendPhotoUrl: photoUrl),
                          ));
                        },
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(colors: [Color(0xFF72246C), Color(0xFF9B30FF)]),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text('Mesaj',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => UserPostsScreen(userId: uid, username: username),
                          ));
                        },
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: const Color(0xFF1A1A2E),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.grid_view_rounded, color: Color(0xFFFFD700), size: 16),
                              SizedBox(width: 6),
                              Text('Gönderiler',
                                  style: TextStyle(
                                      color: Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequestsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FriendService.incomingRequests(_myUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFD700), strokeWidth: 2.5));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mail_outline_rounded, color: Colors.white.withOpacity(0.1), size: 64),
                const SizedBox(height: 16),
                Text('Bekleyen istek yok',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.2), fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final fromUid = doc['from'] as String;

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(fromUid).get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) return const SizedBox.shrink();
                final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
                final username = userData['username'] ?? 'anonim';
                final fullName = userData['fullName'] ?? username;
                final photoUrl = userData['photoUrl'] as String?;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.02)]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.12)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [Color(0xFF72246C), Color(0xFF9B30FF)]),
                        ),
                        child: ClipOval(
                          child: photoUrl != null && photoUrl.isNotEmpty
                              ? Image.network(photoUrl, fit: BoxFit.cover, width: 46, height: 46)
                              : Center(
                                  child: Text(username[0].toUpperCase(),
                                      style: const TextStyle(
                                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fullName,
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                            Text('@$username',
                                style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          await FriendService.acceptRequest(doc.id, fromUid, _myUid);
                          _loadFriends();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10), color: const Color(0xFF4CAF50)),
                          child: const Text('Kabul',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () async {
                          await FriendService.rejectRequest(doc.id);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10), color: Colors.red.shade700),
                          child: const Text('Reddet',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}