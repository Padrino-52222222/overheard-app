import 'dart:async';
import 'package:flutter/material.dart';
import '../models/overheard_post.dart';
import 'overheard_card.dart';

class VitrinSlider extends StatefulWidget {
  final List<OverheardPost> posts;

  const VitrinSlider({super.key, required this.posts});

  @override
  State<VitrinSlider> createState() => _VitrinSliderState();
}

class _VitrinSliderState extends State<VitrinSlider> {
  late final ScrollController _scrollController;
  Timer? _autoTimer;
  Timer? _resumeTimer;
  bool _userScrolling = false;

  static const double _scrollStep = 0.8;
  static const Duration _tickInterval = Duration(milliseconds: 20);
  static const Duration _resumeDelay = Duration(milliseconds: 2500);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll());
  }

  void _startAutoScroll() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(_tickInterval, (_) {
      if (!_scrollController.hasClients || _userScrolling) return;
      final max = _scrollController.position.maxScrollExtent;
      final current = _scrollController.offset;
      if (current >= max) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.jumpTo(current + _scrollStep);
      }
    });
  }

  void _onScrollStart() {
    _userScrolling = true;
    _resumeTimer?.cancel();
  }

  void _onScrollEnd() {
    _resumeTimer?.cancel();
    _resumeTimer = Timer(_resumeDelay, () {
      if (mounted) {
        _userScrolling = false;
      }
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _resumeTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification &&
              notification.dragDetails != null) {
            _onScrollStart();
          } else if (notification is ScrollEndNotification) {
            _onScrollEnd();
          }
          return false;
        },
        child: ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: 10000,
          itemBuilder: (context, index) {
            final post = widget.posts[index % widget.posts.length];
            return OverheardCard(post: post);
          },
        ),
      ),
    );
  }
}