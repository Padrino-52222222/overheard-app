import 'dart:ui';
import 'package:HeardOver/models/overheard_post.dart';
import 'package:HeardOver/services/post_stroge.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';


class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  bool _isLocating = true;
  Position? _currentPosition;
  String _city = '';
  String _district = '';
  String _username = 'anonim';
  String _uid = '';
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  static const int _maxChars = 100;
  static const int _minChars = 3;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _getLocation();
    _loadUserInfo();
    _textController.addListener(() => setState(() {}));
  }

  Future<void> _loadUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _uid = user.uid;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && mounted) {
          setState(() {
            _username = doc.data()?['username'] ?? 'anonim';
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _getLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      String city = 'Bilinmiyor';
      String district = 'Bilinmiyor';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          city = place.administrativeArea ?? place.locality ?? 'Bilinmiyor';
          district = place.subAdministrativeArea ??
              place.subLocality ??
              place.locality ??
              'Bilinmiyor';
          if (city == district && place.locality != null) {
            district = place.locality!;
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _city = city;
          _district = district;
          _isLocating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLocating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Konum alınamadı, tekrar dene'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  int get _charCount => _textController.text.length;
  bool get _isValid =>
      _charCount >= _minChars &&
      _charCount <= _maxChars &&
      _currentPosition != null;

  Color get _counterColor {
    if (_charCount > _maxChars) return Colors.red;
    if (_charCount > 120) return Colors.orange;
    if (_charCount >= _minChars) return const Color(0xFF4CAF50);
    return Colors.white24;
  }

  String get _displayInitial {
    if (_username.isNotEmpty && _username != 'anonim') {
      return _username[0].toUpperCase();
    }
    return '?';
  }

  Future<void> _submitPost() async {
    if (!_isValid || _isLoading) return;

    setState(() => _isLoading = true);

    final post = OverheardPost(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: _textController.text.trim(),
      authorName: '@$_username',
      city: _city,
      district: _district,
      dateTime: DateTime.now(),
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      userId: _uid,
    );

    await PostStorage.savePost(post);

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.of(context).pop(post);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0F0F1A),
                Color(0xFF0A0A0F),
                Color(0xFF0A0A0F),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white54, size: 20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.hearing_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Yeni Overheard',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _isValid ? _submitPost : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: _isValid
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF72246C),
                                      Color(0xFF9B30FF),
                                    ],
                                  )
                                : null,
                            color:
                                _isValid ? null : Colors.white.withOpacity(0.06),
                            boxShadow: _isValid
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF9B30FF)
                                          .withOpacity(0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Paylaş',
                                  style: TextStyle(
                                    color:
                                        _isValid ? Colors.white : Colors.white24,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
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

                // ── Metin Alanı ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF72246C),
                                    Color(0xFF9B30FF),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF72246C)
                                        .withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(_displayInitial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    )),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '@$_username',
                                    style: const TextStyle(
                                      color: Color(0xFFFFD700),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      if (_isLocating) ...[
                                        SizedBox(
                                          width: 10,
                                          height: 10,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                            color: const Color(0xFFFFD700)
                                                .withOpacity(0.6),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Konum alınıyor...',
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.3),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ] else if (_currentPosition != null) ...[
                                        Icon(Icons.location_on_rounded,
                                            color: const Color(0xFFFFD700)
                                                .withOpacity(0.7),
                                            size: 13),
                                        const SizedBox(width: 3),
                                        Flexible(
                                          child: Text(
                                            '$_city / $_district',
                                            style: TextStyle(
                                              color: const Color(0xFF4CAF50)
                                                  .withOpacity(0.8),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ] else ...[
                                        Icon(Icons.location_off_outlined,
                                            color:
                                                Colors.red.withOpacity(0.6),
                                            size: 13),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Konum alınamadı',
                                          style: TextStyle(
                                            color:
                                                Colors.red.withOpacity(0.6),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        Text(
                          '"',
                          style: TextStyle(
                            color: const Color(0xFFFFD700).withOpacity(0.25),
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            height: 0.8,
                          ),
                        ),

                        Expanded(
                          child: TextField(
                            controller: _textController,
                            focusNode: _focusNode,
                            autofocus: true,
                            maxLines: null,
                            maxLength: _maxChars,
                            buildCounter: (context,
                                    {required currentLength,
                                    required isFocused,
                                    maxLength}) =>
                                null,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Ne duydun? Buraya yaz...',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.15),
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Alt Bilgi Barı ──
                ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withOpacity(0.06),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _isLocating
                                ? null
                                : () {
                                    setState(() => _isLocating = true);
                                    _getLocation();
                                  },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.06),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isLocating
                                        ? Icons.my_location_rounded
                                        : _currentPosition != null
                                            ? Icons.location_on_rounded
                                            : Icons.location_off_outlined,
                                    color: _currentPosition != null
                                        ? const Color(0xFFFFD700)
                                        : Colors.white30,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isLocating
                                        ? 'Konum...'
                                        : _currentPosition != null
                                            ? '$_city/$_district'
                                            : 'Konum yok',
                                    style: TextStyle(
                                      color: _currentPosition != null
                                          ? Colors.white54
                                          : Colors.white24,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const Spacer(),

                          if (_charCount > 0 && _charCount < _minChars)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Text(
                                'Min $_minChars karakter',
                                style: TextStyle(
                                  color: Colors.orange.withOpacity(0.6),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _counterColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _counterColor.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '$_charCount/$_maxChars',
                              style: TextStyle(
                                color: _counterColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}