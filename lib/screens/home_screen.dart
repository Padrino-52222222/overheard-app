import 'dart:math';
import 'package:HeardOver/models/overheard_post.dart';
import 'package:HeardOver/screens/chat_hub_screen.dart';
import 'package:HeardOver/screens/create_post.dart';
import 'package:HeardOver/screens/events_secreen.dart';
import 'package:HeardOver/screens/profile_screen.dart';
import 'package:HeardOver/services/notification_trigger_service.dart';
import 'package:HeardOver/services/post_stroge.dart';
import 'package:HeardOver/widgets/bottom_nav_bar.dart';
import 'package:HeardOver/widgets/dropdown_panel.dart';
import 'package:HeardOver/widgets/map_marker_popup.dart';
import 'package:HeardOver/widgets/notification_panel.dart';
import 'package:HeardOver/widgets/vitrin_slider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  final Position initialPosition;
  const HomeScreen({super.key, required this.initialPosition});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;
  OverheardPost? _selectedPost;
  late final MapController _mapController;
  late LatLng _center;
  List<OverheardPost> _allPosts = [];
  Map<String, String?> _userProfilePhotos = {};

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // Panel durumları — ikisi aynı anda açık olamaz
  bool _dropdownOpen = false;
  bool _notifOpen = false;

  void _toggleDropdown() {
    setState(() {
      _dropdownOpen = !_dropdownOpen;
      if (_dropdownOpen) _notifOpen = false;
    });
  }

  void _toggleNotif() {
    setState(() {
      _notifOpen = !_notifOpen;
      if (_notifOpen) _dropdownOpen = false;
    });
  }

  void _closePanels() {
    setState(() {
      _dropdownOpen = false;
      _notifOpen = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _center = LatLng(
      widget.initialPosition.latitude,
      widget.initialPosition.longitude,
    );
    _loadPosts();
    // Vitrin süresi kontrolü — uygulama açılışında çalışır
    PostStorage.checkVitrinExpiry();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    final posts = await PostStorage.loadPosts();
    await _loadProfilePhotos(posts);
    if (mounted) setState(() => _allPosts = posts);
  }

  List<OverheardPost> get _vitrinPosts {
    final now = DateTime.now();
    final v = _allPosts
        .where((p) => p.vitrinUntil != null && p.vitrinUntil!.isAfter(now))
        .toList();
    return v.isEmpty ? _allPosts : v;
  }

  Future<void> _loadProfilePhotos(List<OverheardPost> posts) async {
    final userIds = posts
        .map((p) => p.userId)
        .where((id) => id != null && id.isNotEmpty)
        .toSet();

    if (userIds.isEmpty) {
      setState(() => _userProfilePhotos = {});
      return;
    }

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId,
            whereIn: userIds.length > 30
                ? userIds.take(30).toList()
                : userIds.toList())
        .get();

    final photoMap = <String, String?>{};
    for (final doc in snap.docs) {
      photoMap[doc.id] = doc['photoUrl'] as String?;
    }
    setState(() => _userProfilePhotos = photoMap);
  }

  void _openCreateScreen() async {
    final result = await Navigator.of(context).push<OverheardPost>(
      PageRouteBuilder(
        pageBuilder: (_, a, __) => const CreatePostScreen(),
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
    if (result != null && mounted) {
      await _loadPosts();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('Overheard paylaşıldı! 🎉'),
        ]),
        backgroundColor: const Color(0xFF72246C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  List<Marker> _buildMarkers() {
    return _allPosts.map((post) {
      final photoUrl =
          (post.userId != null && _userProfilePhotos.containsKey(post.userId))
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
                    child: Image.network(photoUrl,
                        fit: BoxFit.cover,
                        width: 38,
                        height: 38,
                        errorBuilder: (_, __, ___) => const Center(
                            child:
                                Text('👂', style: TextStyle(fontSize: 20)))),
                  )
                : const Center(
                    child: Text('👂', style: TextStyle(fontSize: 20))),
          ),
        ),
      );
    }).toList();
  }

  CircleLayer _buildCircle() {
    return CircleLayer(circles: [
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
    ]);
  }

  Widget _buildMapView() {
    return Stack(
      children: [
        // ── Harita ──
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
            onTap: (_, __) {
              setState(() => _selectedPost = null);
              _closePanels();
            },
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

        // ── Üst gradient ──
        Positioned(
          top: 0, left: 0, right: 0, height: 180,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.7), Colors.transparent],
              ),
            ),
          ),
        ),

        // ── Alt gradient ──
        Positioned(
          bottom: 0, left: 0, right: 0, height: 140,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.7), Colors.transparent],
              ),
            ),
          ),
        ),

        // ── Header + Paneller ──
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                child: Row(
                  children: [
                    // ── Bildirim Zili ──
                    GestureDetector(
                      onTap: _toggleNotif,
                      child: StreamBuilder<int>(
                        stream: NotificationTriggerService.unreadCountStream(
                            _myUid),
                        builder: (ctx, snap) {
                          final count = snap.data ?? 0;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: _notifOpen
                                      ? const LinearGradient(colors: [
                                          Color(0xFFFFD700),
                                          Color(0xFFFF8C00),
                                        ])
                                      : null,
                                  color: _notifOpen
                                      ? null
                                      : Colors.white.withOpacity(0.12),
                                  border: Border.all(
                                    color: _notifOpen
                                        ? Colors.transparent
                                        : Colors.white.withOpacity(0.2),
                                  ),
                                  boxShadow: _notifOpen
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFFFFD700)
                                                .withOpacity(0.4),
                                            blurRadius: 12,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Icon(
                                  _notifOpen
                                      ? Icons.notifications_rounded
                                      : Icons.notifications_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              if (count > 0 && !_notifOpen)
                                Positioned(
                                  top: -3,
                                  right: -3,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(colors: [
                                        Color(0xFFFFD700),
                                        Color(0xFFFF8C00),
                                      ]),
                                    ),
                                    child: Center(
                                      child: Text(
                                        count > 9 ? '9+' : '$count',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(width: 10),

                    // ── Başlık ──
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

                    // ── Mirket (Dropdown) Butonu ──
                    GestureDetector(
                      onTap: _toggleDropdown,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: _dropdownOpen
                              ? const LinearGradient(colors: [
                                  Color(0xFFFFD700),
                                  Color(0xFFFF8C00),
                                ])
                              : null,
                          color: _dropdownOpen
                              ? null
                              : Colors.white.withOpacity(0.12),
                          border: Border.all(
                            color: _dropdownOpen
                                ? Colors.transparent
                                : Colors.white.withOpacity(0.2),
                          ),
                          boxShadow: _dropdownOpen
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFFFD700)
                                        .withOpacity(0.4),
                                    blurRadius: 12,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '🦦',
                            style:
                                TextStyle(fontSize: _dropdownOpen ? 18 : 16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Bildirim Paneli ──
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _notifOpen
                    ? NotificationPanel(
                        onClose: () => setState(() => _notifOpen = false),
                      )
                    : const SizedBox.shrink(),
              ),

              // ── Dropdown Paneli ──
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _dropdownOpen
                    ? HomeDropdownPanel(
                        onClose: () => setState(() => _dropdownOpen = false),
                      )
                    : const SizedBox.shrink(),
              ),

              // ── Vitrin Slider ──
              if (!_dropdownOpen && !_notifOpen && _allPosts.isNotEmpty) ...[
                const SizedBox(height: 10),
                VitrinSlider(
                  posts: _vitrinPosts.isNotEmpty ? _vitrinPosts : _allPosts,
                ),
              ],
            ],
          ),
        ),

        // ── Post Popup ──
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
              const ChatHubScreen(),
              const ProfileScreen(),
              const EventsScreen(),
            ],
          ),
          OverheardBottomNavBar(
            currentIndex: _navIndex,
            onTap: (i) {
              if (i == 2) {
                _openCreateScreen();
              } else {
                if (i == 0) _loadPosts();
                setState(() {
                  _navIndex = i;
                  _closePanels();
                });
              }
            },
          ),
        ],
      ),
    );
  }
}