import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/overheard_post.dart';
import 'tappable_username.dart';
import 'reaction_buttons.dart';

class MapMarkerPopup extends StatelessWidget {
  final OverheardPost post;
  final VoidCallback onClose;

  const MapMarkerPopup({
    super.key,
    required this.post,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100,
      left: 20,
      right: 20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.2),
                  Colors.white.withOpacity(0.08),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.amber.withOpacity(0.5), width: 1),
                      ),
                      child: const Text(
                        '👂 Duyuldu',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onClose,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white70, size: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  post.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        color: Colors.white70, size: 14),
                    const SizedBox(width: 6),
                    TappableUsername(
                      username: post.authorName,
                      userId: post.userId,
                      fontSize: 13,
                      color: const Color(0xFFFFD700),
                      fontWeight: FontWeight.w600,
                    ),
                    const Spacer(),
                    const Icon(Icons.location_on,
                        color: Colors.yellowAccent, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      post.locationLabel,
                      style: const TextStyle(
                        color: Colors.yellowAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        color: Colors.white54, size: 13),
                    const SizedBox(width: 6),
                    Text(
                      post.formattedDate,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    ReactionButtons(postId: post.id),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}