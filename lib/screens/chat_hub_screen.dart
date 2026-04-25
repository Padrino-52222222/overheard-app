import 'package:HeardOver/screens/chat_screen.dart';
import 'package:HeardOver/screens/dm_screen.dart';
import 'package:flutter/material.dart';

class ChatHubScreen extends StatefulWidget {
  const ChatHubScreen({super.key});

  @override
  State<ChatHubScreen> createState() => _ChatHubScreenState();
}

class _ChatHubScreenState extends State<ChatHubScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0A0F),
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 12),

          // ── Header ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.forum_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                const Text(
                  'Sohbet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Toggle Butonlar (Sliding) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0xFF12121F),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.07),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final buttonWidth = constraints.maxWidth / 2;
                    return Stack(
                      children: [
                        // ── Kayan sarı arka plan ──
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          left: _tabIndex == 0 ? 0 : buttonWidth,
                          top: 0,
                          bottom: 0,
                          width: buttonWidth,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                              ),
                            ),
                          ),
                        ),

                        // ── Buton yazıları ──
                        Row(
                          children: [
                            _tabButton(0, Icons.forum_rounded, 'Genel Sohbet'),
                            _tabButton(1, Icons.mail_rounded, 'Sohbetlerim'),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── Divider ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              height: 1,
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
          ),

          // ── İçerik ──
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: const [
                ChatScreen(showHeader: false),
                DmScreen(showHeader: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(int index, IconData icon, String label) {
    final isSelected = _tabIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: SizedBox(
          height: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  icon,
                  key: ValueKey('$index-$isSelected'),
                  size: 15,
                  color: isSelected ? Colors.white : Colors.white38,
                ),
              ),
              const SizedBox(width: 6),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white38,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}