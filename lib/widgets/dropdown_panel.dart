import 'package:HeardOver/services/notifications_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeDropdownPanel extends StatefulWidget {
  final VoidCallback onClose;

  const HomeDropdownPanel({super.key, required this.onClose});

  @override
  State<HomeDropdownPanel> createState() => _HomeDropdownPanelState();
}

class _HomeDropdownPanelState extends State<HomeDropdownPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  bool _nearbyEnabled = true;
  bool _likesEnabled = true;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.06),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

    _animCtrl.forward();
    _loadSettings();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final nearby = await NotificationService.isNearbyPostsEnabled();
    final likes = await NotificationService.isLikesEnabled();
    if (mounted) {
      setState(() {
        _nearbyEnabled = nearby;
        _likesEnabled = likes;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: const Color(0xFF0F0F1A),
            border: Border.all(
              color: const Color(0xFFFFD700).withOpacity(0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [
                          Color(0xFFFFD700),
                          Color(0xFFFF8C00),
                        ]),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('🦦', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Menü',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.07),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.1)),
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white54, size: 16),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Divider ──
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    const Color(0xFFFFD700).withOpacity(0.15),
                    Colors.transparent,
                  ]),
                ),
              ),

              // ── İçerik ──
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Bildirim Ayarları ──
                    _sectionHeader('🔔 Bildirim Ayarları'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.white.withOpacity(0.04),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.07)),
                      ),
                      child: Column(
                        children: [
                          _toggleTile(
                            emoji: '📍',
                            title: 'Yakın Çevre Paylaşımları',
                            subtitle:
                                'Harita bölgendeki yeni paylaşımlar',
                            value: _nearbyEnabled,
                            onChanged: (val) async {
                              await NotificationService.setNearbyPosts(
                                  val);
                              setState(() => _nearbyEnabled = val);
                            },
                          ),
                          Divider(
                            height: 1,
                            color: Colors.white.withOpacity(0.06),
                            indent: 14,
                            endIndent: 14,
                          ),
                          _toggleTile(
                            emoji: '❤️',
                            title: 'Beğeni Bildirimleri',
                            subtitle: 'Paylaşımlarına gelen tepkiler',
                            value: _likesEnabled,
                            onChanged: (val) async {
                              await NotificationService.setLikes(val);
                              setState(() => _likesEnabled = val);
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Yardım ve Destek ──
                    _sectionHeader('❓ Yardım ve Destek'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse(
                          'mailto:heardover.destek@gmail.com'
                          '?subject=HeardOver%20Destek'
                          '&body=Merhaba%20HeardOver%20ekibi%2C%0A%0A',
                        );
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: Colors.white.withOpacity(0.04),
                          border: Border.all(
                            color:
                                const Color(0xFFFFD700).withOpacity(0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(colors: [
                                  Color(0xFFFFD700),
                                  Color(0xFFFF8C00),
                                ]),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFD700)
                                        .withOpacity(0.3),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.mail_rounded,
                                  color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Destek & Geri Bildirim',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'heardover.destek@gmail.com',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withOpacity(0.4),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded,
                                color: Colors.white.withOpacity(0.25),
                                size: 14),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Center(
                      child: Text(
                        'HeardOver v1.0.0',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.12),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFFFFD700),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      );

  Widget _toggleTile({
    required String emoji,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFFFD700),
            activeTrackColor:
                const Color(0xFFFFD700).withOpacity(0.3),
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white.withOpacity(0.1),
          ),
        ],
      ),
    );
  }
}