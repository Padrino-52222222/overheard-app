import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/reaction_buttons.dart';

class UserPostsScreen extends StatelessWidget {
  final String userId;
  final String username;

  const UserPostsScreen({
    super.key,
    required this.userId,
    required this.username,
  });

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
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white54, size: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text('@$username gönderileri',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<QueryDocumentSnapshot>>(
                future: _fetchPosts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFFFFD700), strokeWidth: 2.5));
                  }

                  final docs = snapshot.data ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.article_outlined,
                              color: Colors.white.withOpacity(0.1), size: 64),
                          const SizedBox(height: 16),
                          Text('Henüz gönderi yok',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.2),
                                  fontSize: 16)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data =
                          docs[index].data() as Map<String, dynamic>;
                      final docId = docs[index].id;
                      final postId = data['id'] as String? ?? docId;
                      final text = data['text'] ?? '';
                      final city = data['city'] ?? '';
                      final district = data['district'] ?? '';
                      final dateStr = data['dateTime'] as String?;
                      DateTime? date;
                      if (dateStr != null) {
                        try {
                          date = DateTime.parse(dateStr);
                        } catch (_) {}
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.06),
                              Colors.white.withOpacity(0.02),
                            ],
                          ),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('"$text"',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    height: 1.5)),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded,
                                    color: Color(0xFFFFD700), size: 14),
                                const SizedBox(width: 4),
                                Text('$city/$district',
                                    style: const TextStyle(
                                        color: Color(0xFFFFD700),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                                const Spacer(),
                                if (date != null)
                                  Text(
                                    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 11),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ReactionButtons(postId: postId),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<QueryDocumentSnapshot>> _fetchPosts() async {
    final byUserId = await FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .get();

    if (byUserId.docs.isNotEmpty) return byUserId.docs;

    final byAuthor = await FirebaseFirestore.instance
        .collection('posts')
        .where('authorName', isEqualTo: '@$username')
        .get();

    return byAuthor.docs;
  }
}