import 'package:HeardOver/services/reaction_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReactionButtons extends StatefulWidget {
  final String postId;

  const ReactionButtons({super.key, required this.postId});

  @override
  State<ReactionButtons> createState() => _ReactionButtonsState();
}

class _ReactionButtonsState extends State<ReactionButtons> {
  int _likes = 0;
  int _dislikes = 0;
  bool _liked = false;
  bool _disliked = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReactions();
  }

  Future<void> _loadReactions() async {
    try {
      final data = await ReactionService.getReactions(widget.postId);
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (mounted) {
        setState(() {
          _likes = data['likes'];
          _dislikes = data['dislikes'];
          _liked = (data['likedBy'] as List).contains(uid);
          _disliked = (data['dislikedBy'] as List).contains(uid);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _react(String type) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final data = await ReactionService.toggleReaction(
        postId: widget.postId,
        uid: uid,
        type: type,
      );
      if (mounted) {
        setState(() {
          _likes = data['likes'];
          _dislikes = data['dislikes'];
          _liked = (data['likedBy'] as List).contains(uid);
          _disliked = (data['dislikedBy'] as List).contains(uid);
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 28);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Like
        GestureDetector(
          onTap: () => _react('like'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: _liked
                  ? const Color(0xFF4CAF50).withOpacity(0.15)
                  : Colors.white.withOpacity(0.06),
              border: Border.all(
                color: _liked
                    ? const Color(0xFF4CAF50).withOpacity(0.4)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _liked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                  size: 14,
                  color: _liked
                      ? const Color(0xFF4CAF50)
                      : Colors.white38,
                ),
                if (_likes > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    ReactionService.formatCount(_likes),
                    style: TextStyle(
                      color: _liked
                          ? const Color(0xFF4CAF50)
                          : Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Dislike
        GestureDetector(
          onTap: () => _react('dislike'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: _disliked
                  ? const Color(0xFFE53935).withOpacity(0.15)
                  : Colors.white.withOpacity(0.06),
              border: Border.all(
                color: _disliked
                    ? const Color(0xFFE53935).withOpacity(0.4)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _disliked ? Icons.thumb_down_rounded : Icons.thumb_down_outlined,
                  size: 14,
                  color: _disliked
                      ? const Color(0xFFE53935)
                      : Colors.white38,
                ),
                if (_dislikes > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    ReactionService.formatCount(_dislikes),
                    style: TextStyle(
                      color: _disliked
                          ? const Color(0xFFE53935)
                          : Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}