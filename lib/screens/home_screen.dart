import 'dart:math';
import 'package:HeardOver/models/overheard_post.dart';
import 'package:HeardOver/screens/chat_screen.dart';
import 'package:HeardOver/screens/create_post.dart';
import 'package:HeardOver/screens/dm_screen.dart';
import 'package:HeardOver/screens/profile_screen.dart';
import 'package:HeardOver/services/post_stroge.dart';
import 'package:HeardOver/widgets/bottom_nav_bar.dart';
import 'package:HeardOver/widgets/map_marker_popup.dart';
import 'package:HeardOver/widgets/vitrin_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  final Position initialPosition;

  const HomeScreen({super.key, required this.initialPosition});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _navIndex = 0;
  OverheardPost? _selectedPost;
  late final MapController _mapController;
  late LatLng _center;
  List<OverheardPost> _allPosts = [];
  Map<String, String?> _userProfilePhotos = {};

  // ── Duyuru butonu animasyonları ──
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late AnimationController _rotateController;
  late Animation<double> _rotateAnim;
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _center = LatLng(
      widget.initialPosition.latitude,
      widget.initialPosition.longitude,
    );
    _loadPosts();

    // Pulse (büyüyüp küçülme)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Rotate (hafif sallanma)
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _rotateAnim = Tween<double>(begin: -0.08, end: 0.08).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.easeInOut),
    );

    // Glow (parlama)
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 0.9).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    final posts = await PostStorage.loadPosts();
    await _loadProfilePhotos(posts);
    if (mounted) {
      setState(() {
        _allPosts = posts;
      });
    }
  }

  List<OverheardPost> get _vitrinPosts {
    final now = DateTime.now();
    final vitrinOlanlar = _allPosts.where((post) {
      if (post.vitrinUntil == null) return false;
      return post.vitrinUntil!.isAfter(now);
    }).toList();

    if (vitrinOlanlar.isEmpty) return _allPosts;
    return vitrinOlanlar;
  }

  Future<void> _loadProfilePhotos(List<OverheardPost> posts) async {
    final userIds = posts.map((p) => p.userId).where((id) => id != null && id.isNotEmpty).toSet();

    if (userIds.isEmpty) {
      setState(() {
        _userProfilePhotos = {};
      });
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: userIds.length > 30 ? userIds.take(30).toList() : userIds.toList())
        .get();
    final photoMap = <String, String?>{};
    for (final doc in snapshot.docs) {
      photoMap[doc.id] = doc['photoUrl'] as String?;
    }

    if (userIds.length > 30) {
      final remaining = userIds.skip(30).toList();
      final snap2 = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: remaining)
          .get();
      for (final doc in snap2.docs) {
        photoMap[doc.id] = doc['photoUrl'] as String?;
      }
    }

    setState(() {
      _userProfilePhotos = photoMap;
    });
  }

  void _openCreateScreen() async {
    final result = await Navigator.of(context).push<OverheardPost>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const CreatePostScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );

    if (result != null && mounted) {
      await _loadPosts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Overheard paylaşıldı! 🎉'),
            ],
          ),
          backgroundColor: const Color(0xFF72246C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ══════════════════════════════════════
  //  Duyuru / Hakkımızda Sayfası
  // ══════════════════════════════════════
  void _showInfoSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F0F1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 20),
              // Header
          
              const SizedBox(height: 14),
              const Text(
                'HeardOver',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Versiyon 1.0.0',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.25),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      const Color(0xFFFFD700).withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // İçerik (kaydırılabilir)
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  children: [
                    // Hakkımızda
                    _infoSection(
                      icon: Icons.info_outline_rounded,
                      title: 'Duyuru',
                      color: const Color(0xFFFFD700),
                      content:
                          '  Merhaba değerli kullanıcımız iyi günler dileriz,'
                          'Öncelikle deneme süresinde uygulamamızı indirerek bize destek olduğunuz için Teşekkür ederiz. '
                          'Kullandığınız sürüm tüm mevcut tüm özelliklere sınırsız erişim sağlayan özel bir sürüm tüm özellikleri sınırsızca deneyebilirsin. '
                          'Gelecek zaman zarfı içerisinde uygulamamıza eklemek istediğimiz şuan geliştirme aşamasında olan pek çok özellik var bu süreç içerisinde sen de değerli fikirlerin ile bize destek olarak uygulamamız içerisinde görmek istediğin ve mevcut özellikler ile ilgili fikirlerini aşağıdaki mail adresi üzerinden bizimle paylaşırsan seviniriz. '
                          'Şimdiden Teşekkür eder HeardOver ile iyi eğlenceler dileriz.'                    ),
                    const SizedBox(height: 16),

                    // Nasıl Kullanılır
                    _infoSection(
                      icon: Icons.rocket_launch_rounded,
                      title: 'Nasıl Kullanılır?',
                      color: const Color(0xFF9B30FF),
                      content:
                          '1. Haritada çevreni keşfet 🗺️\n'
                          '2. Duyduğun ilginç şeyleri paylaş ✍️\n'
                          '3. Arkadaş ekle ve mesajlaş 💬\n'
                          '4. Karizma puanı kazan ve yüksel ⚡\n'
                          '5. Vitrinde öne çıkan gönderileri gör 🔥',
                    ),
                    const SizedBox(height: 16),

                    // Kurallar
                    _infoSection(
                      icon: Icons.shield_outlined,
                      title: 'Topluluk Kuralları',
                      color: const Color(0xFF1E88E5),
                      content:
                          '• Saygılı ol, hakaret etme\n'
                          '• Kişisel bilgi paylaşma\n'
                          '• Spam ve reklam yasaktır\n'
                          '• Uygunsuz içerik paylaşma\n'
                          '• Eğlen ve keyif al! 🎉',
                    ),
                    const SizedBox(height: 24),

                    // Geri Bildirim
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFFFD700).withOpacity(0.08),
                            const Color(0xFFFF8C00).withOpacity(0.03),
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0xFFFFD700).withOpacity(0.15),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD700).withOpacity(0.3),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.mail_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Geri Bildirim & Destek',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Bir hata buldun, önerin mi var veya\nbize ulaşmak mı istiyorsun?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () async {
                              final uri = Uri(
                                scheme: 'mailto',
                                path: 'mustafamkakadir1405@gmail.com',
                                queryParameters: {
                                  'subject': 'HeardOver Geri Bildirim',
                                  'body': 'Merhaba HeardOver ekibi,\n\n',
                                },
                              );
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFD700).withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.send_rounded, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'heardover.destek@gmail.com',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Alt yazı
                    Center(
                      child: Text(
                        'HeardOver ile Paylaş ❤️',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.15),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoSection({
    required IconData icon,
    required String title,
    required Color color,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.06),
            color.withOpacity(0.02),
          ],
        ),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: color.withOpacity(0.12),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers() {
    return _allPosts.map((post) {
      final photoUrl = (post.userId != null && _userProfilePhotos.containsKey(post.userId))
          ? _userProfilePhotos[post.userId]
          : null;

      return Marker(
        point: LatLng(post.latitude, post.longitude),
        width: 48,
        height: 48,
        child: GestureDetector(
          onTap: () => setState(() => _selectedPost = post),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.55),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: photoUrl != null && photoUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      width: 38,
                      height: 38,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text("👂", style: TextStyle(fontSize: 20)),
                      ),
                    ),
                  )
                : const Center(
                    child: Text('👂', style: TextStyle(fontSize: 20)),
                  ),
          ),
        ),
      );
    }).toList();
  }

  CircleLayer _buildCircle() {
    return CircleLayer(
      circles: [
        CircleMarker(
          point: _center,
          radius: 520,
          useRadiusInMeter: true,
          color: Colors.transparent,
          borderColor: const Color(0xFFFFD700).withOpacity(0.12),
          borderStrokeWidth: 6,
        ),
        CircleMarker(
          point: _center,
          radius: 500,
          useRadiusInMeter: true,
          color: const Color(0xFFFFD700).withOpacity(0.05),
          borderColor: const Color(0xFFFFD700).withOpacity(0.65),
          borderStrokeWidth: 2,
        ),
        CircleMarker(
          point: _center,
          radius: 480,
          useRadiusInMeter: true,
          color: Colors.transparent,
          borderColor: const Color(0xFFFFD700).withOpacity(0.18),
          borderStrokeWidth: 3,
        ),
      ],
    );
  }

  Widget _buildMapView() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: 15.5,
            minZoom: 3,
            maxZoom: 18.5,
            cameraConstraint: CameraConstraint.contain(
              bounds: LatLngBounds(
                const LatLng(-85, -180),
                const LatLng(85, 180),
              ),
            ),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: (_, __) => setState(() => _selectedPost = null),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.overheard.app',
              maxZoom: 19,
            ),
            _buildCircle(),
            MarkerLayer(markers: _buildMarkers()),
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 180,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 140,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                child: Row(
                  children: [
                    const Text(
                      'HeardOver',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    // ── Animasyonlu Duyuru Butonu ──
                    GestureDetector(
                      onTap: _showInfoSheet,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_pulseAnim, _rotateAnim, _glowAnim]),
                        builder: (context, child) {
                          return Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFFFFD700).withOpacity(_glowAnim.value * 0.5),
                                  blurRadius: 16 + (_glowAnim.value * 8),
                                  spreadRadius: _glowAnim.value * 4,
                                ),
                                BoxShadow(
                                  color: Color(0xFFFF8C00).withOpacity(_glowAnim.value * 0.3),
                                  blurRadius: 24 + (_glowAnim.value * 12),
                                  spreadRadius: _glowAnim.value * 2,
                                ),
                              ],
                            ),
                            child: Transform.scale(
                              scale: _pulseAnim.value,
                              child: Transform.rotate(
                                angle: _rotateAnim.value,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.campaign_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (_allPosts.isNotEmpty)
                VitrinSlider(
                  posts: _vitrinPosts.isNotEmpty ? _vitrinPosts : _allPosts,
                ),
            ],
          ),
        ),
        if (_selectedPost != null)
          MapMarkerPopup(
            post: _selectedPost!,
            onClose: () => setState(() => _selectedPost = null),
          ),
      ],
    );
  }

  int _stackIndex() {
    switch (_navIndex) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 3:
        return 2;
      case 4:
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Stack(
        children: [
          IndexedStack(
            index: _stackIndex(),
            children: [
              _buildMapView(),
              const ChatScreen(),
              const ProfileScreen(),
              const DmScreen(),
            ],
          ),
          OverheardBottomNavBar(
            currentIndex: _navIndex,
            onTap: (i) {
              if (i == 2) {
                _openCreateScreen();
              } else {
                if (i == 0) _loadPosts();
                setState(() => _navIndex = i);
              }
            },
          ),
        ],
      ),
    );
  }
}