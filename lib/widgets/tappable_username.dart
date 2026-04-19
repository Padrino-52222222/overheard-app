import 'package:HeardOver/screens/user_profile.dart';
import 'package:flutter/material.dart';

class TappableUsername extends StatelessWidget {
  final String username;
  final String? userId;
  final double fontSize;
  final Color color;
  final FontWeight fontWeight;

  const TappableUsername({
    super.key,
    required this.username,
    this.userId,
    this.fontSize = 13,
    this.color = const Color(0xFFFFD700),
    this.fontWeight = FontWeight.w700,
  });

  @override
  Widget build(BuildContext context) {
    final clean = username.replaceAll('@', '');
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => UserProfileScreen(
              username: clean,
              userId: userId,
            ),
          ),
        );
      },
      child: Text(
        '@$clean',
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      ),
    );
  }
}