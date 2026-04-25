import 'package:HeardOver/models/event_model.dart';
import 'package:HeardOver/screens/create_event_secreen.dart';
import 'package:HeardOver/screens/event_detail_screen.dart';
import 'package:HeardOver/services/event_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  int _tabIndex = 0;
  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  String? _filterCity;
  DateTime? _filterDate;
  TimeOfDay? _filterTimeFrom;
  TimeOfDay? _filterTimeTo;
  bool _filterOpen = false;

  List<EventModel> _applyFilters(List<EventModel> all) {
    List<EventModel> list;
    switch (_tabIndex) {
      case 0:
        list = all.where((e) => e.isActive).toList();
        break;
      case 1:
        list = all.where((e) => e.isUpcoming).toList();
        break;
      case 2:
        list = all.where((e) => e.isPast).toList();
        break;
      default:
        list = all;
    }

    if (_filterCity != null) {
      list = list
          .where((e) =>
              e.city.toLowerCase() == _filterCity!.toLowerCase())
          .toList();
    }

    if (_filterDate != null) {
      list = list.where((e) {
        final d = _filterDate!;
        final dayStart = DateTime(d.year, d.month, d.day);
        final dayEnd = dayStart.add(const Duration(days: 1));
        return e.startDateTime.isBefore(dayEnd) &&
            e.endDateTime.isAfter(dayStart);
      }).toList();
    }

    if (_filterTimeFrom != null) {
      list = list.where((e) {
        final s = e.startDateTime;
        final f = _filterTimeFrom!;
        return s.hour > f.hour ||
            (s.hour == f.hour && s.minute >= f.minute);
      }).toList();
    }

    if (_filterTimeTo != null) {
      list = list.where((e) {
        final s = e.startDateTime;
        final t = _filterTimeTo!;
        return s.hour < t.hour ||
            (s.hour == t.hour && s.minute <= t.minute);
      }).toList();
    }

    return list;
  }

  bool get _hasActiveFilter =>
      _filterCity != null ||
      _filterDate != null ||
      _filterTimeFrom != null ||
      _filterTimeTo != null;

  void _clearFilters() => setState(() {
        _filterCity = null;
        _filterDate = null;
        _filterTimeFrom = null;
        _filterTimeTo = null;
      });

  String _formatDate(DateTime dt) =>
      DateFormat('d MMM HH:mm', 'tr_TR').format(dt);

  String _countdownText(EventModel e) {
    if (e.isActive) return 'Aktif';
    if (e.isPast) return 'Sona erdi';
    final diff = e.timeUntilStart;
    if (diff.inDays > 0) return '${diff.inDays} gün sonra';
    if (diff.inHours > 0) return '${diff.inHours} saat sonra';
    return '${diff.inMinutes} dk sonra';
  }

  Color _statusColor(EventModel e) {
    if (e.isActive) return const Color(0xFF4CAF50);
    if (e.isPast) return Colors.white24;
    return const Color(0xFF1E88E5);
  }

  Future<void> _pickFilterDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFFFD700),
            onPrimary: Colors.black,
            surface: Color(0xFF12121F),
          ),
          dialogTheme:
              const DialogThemeData(backgroundColor: Color(0xFF12121F)),
        ),
        child: child!,
      ),
    );
    if (d != null) setState(() => _filterDate = d);
  }

  Future<void> _pickFilterTime(bool isFrom) async {
    final t = await showTimePicker(
      context: context,
      initialTime:
          (isFrom ? _filterTimeFrom : _filterTimeTo) ?? TimeOfDay.now(),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFFD700),
              onPrimary: Colors.black,
              surface: Color(0xFF12121F),
            ),
            dialogTheme: const DialogThemeData(
                backgroundColor: Color(0xFF12121F)),
          ),
          child: child!,
        ),
      ),
    );
    if (t != null) {
      setState(() {
        if (isFrom) {
          _filterTimeFrom = t;
        } else {
          _filterTimeTo = t;
        }
      });
    }
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _showCityFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F0F1A),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Şehir Filtrele',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (_filterCity != null)
                GestureDetector(
                  onTap: () {
                    setState(() => _filterCity = null);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.red.withOpacity(0.08),
                      border:
                          Border.all(color: Colors.red.withOpacity(0.2)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.clear_rounded,
                            color: Colors.redAccent, size: 14),
                        SizedBox(width: 6),
                        Text('Şehir filtresini temizle',
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: EventService.cities.length,
                  itemBuilder: (_, i) {
                    final city = EventService.cities[i];
                    final isIstanbul = city.startsWith('İstanbul');
                    final isSel = _filterCity == city;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _filterCity = city);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: isSel
                              ? const LinearGradient(colors: [
                                  Color(0xFFFFD700),
                                  Color(0xFFFF8C00)
                                ])
                              : null,
                          color: isSel
                              ? null
                              : Colors.white.withOpacity(0.05),
                          border: Border.all(
                            color: isIstanbul && !isSel
                                ? const Color(0xFFFFD700).withOpacity(0.2)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_city_rounded,
                                size: 15,
                                color: isSel
                                    ? Colors.white
                                    : isIstanbul
                                        ? const Color(0xFFFFD700)
                                        : Colors.white38),
                            const SizedBox(width: 10),
                            Text(city,
                                style: TextStyle(
                                  color: isSel
                                      ? Colors.white
                                      : isIstanbul
                                          ? const Color(0xFFFFD700)
                                          : Colors.white70,
                                  fontSize: 14,
                                  fontWeight: isIstanbul || isSel
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                )),
                            if (isSel) ...[
                              const Spacer(),
                              const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 16),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
                        colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.event_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                const Text('Etkinlikler',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                const Spacer(),
                // Filtre butonu
                GestureDetector(
                  onTap: () =>
                      setState(() => _filterOpen = !_filterOpen),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: _hasActiveFilter
                          ? const LinearGradient(colors: [
                              Color(0xFFFFD700),
                              Color(0xFFFF8C00)
                            ])
                          : null,
                      color: _hasActiveFilter
                          ? null
                          : Colors.white.withOpacity(0.07),
                      border: Border.all(
                        color: _hasActiveFilter
                            ? Colors.transparent
                            : Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _hasActiveFilter
                              ? Icons.filter_alt_rounded
                              : Icons.filter_alt_outlined,
                          color: _hasActiveFilter
                              ? Colors.white
                              : Colors.white54,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text('Filtre',
                            style: TextStyle(
                              color: _hasActiveFilter
                                  ? Colors.white
                                  : Colors.white54,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            )),
                        if (_hasActiveFilter) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: _clearFilters,
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 14),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Oluştur butonu
                GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CreateEventScreen())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add_rounded,
                            color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text('Oluştur',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Filtre Paneli ──
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child:
                _filterOpen ? _buildFilterPanel() : const SizedBox.shrink(),
          ),

          const SizedBox(height: 14),

          // ── Sekmeler ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF12121F),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.07)),
                ),
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    final w = constraints.maxWidth / 3;
                    return Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          left: _tabIndex * w,
                          top: 0,
                          bottom: 0,
                          width: w,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [
                                Color(0xFFFFD700),
                                Color(0xFFFF8C00)
                              ]),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            _tab(0, 'Aktif'),
                            _tab(1, 'Yaklaşan'),
                            _tab(2, 'Geçmiş'),
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent,
                  const Color(0xFFFFD700).withOpacity(0.15),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          // Aktif filtre chip'leri
          if (_hasActiveFilter)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_filterCity != null)
                      _filterChip(Icons.location_city_rounded, _filterCity!,
                          () => setState(() => _filterCity = null)),
                    if (_filterDate != null)
                      _filterChip(
                          Icons.calendar_today_rounded,
                          DateFormat('d MMM yyyy', 'tr_TR')
                              .format(_filterDate!),
                          () => setState(() => _filterDate = null)),
                    if (_filterTimeFrom != null)
                      _filterChip(
                          Icons.access_time_rounded,
                          'Dan: ${_fmtTime(_filterTimeFrom!)}',
                          () => setState(() => _filterTimeFrom = null)),
                    if (_filterTimeTo != null)
                      _filterChip(
                          Icons.access_time_rounded,
                          'De: ${_fmtTime(_filterTimeTo!)}',
                          () => setState(() => _filterTimeTo = null)),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 4),

          // ── Liste ──
          Expanded(
            child: StreamBuilder<List<EventModel>>(
              stream: EventService.eventsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFFFD700), strokeWidth: 2.5),
                  );
                }

                final all = snapshot.data ?? [];
                final events = _applyFilters(all);

                if (events.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_hasActiveFilter ? '🔍' : '🎯',
                            style: const TextStyle(fontSize: 52)),
                        const SizedBox(height: 12),
                        Text(
                          _hasActiveFilter
                              ? 'Filtreye uygun etkinlik bulunamadı'
                              : _tabIndex == 0
                                  ? 'Şu an aktif etkinlik yok'
                                  : _tabIndex == 1
                                      ? 'Yaklaşan etkinlik yok'
                                      : 'Geçmiş etkinlik yok',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.25),
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
                        ),
                        if (_hasActiveFilter) ...[
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: _clearFilters,
                            child: const Text('Filtreleri temizle',
                                style: TextStyle(
                                    color: Color(0xFFFFD700),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  itemCount: events.length,
                  itemBuilder: (ctx, i) => _EventCard(
                    event: events[i],
                    myUid: _myUid,
                    statusText: _countdownText(events[i]),
                    statusColor: _statusColor(events[i]),
                    formatDate: _formatDate,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              EventDetailScreen(event: events[i])),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF0F0F1A),
        border: Border.all(
            color: const Color(0xFFFFD700).withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _filterLabel('Şehir'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showCityFilter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF12121F),
                border: Border.all(
                  color: _filterCity != null
                      ? const Color(0xFFFFD700).withOpacity(0.4)
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_city_rounded,
                      size: 16,
                      color: _filterCity != null
                          ? const Color(0xFFFFD700)
                          : Colors.white38),
                  const SizedBox(width: 10),
                  Text(_filterCity ?? 'Tüm şehirler',
                      style: TextStyle(
                          color: _filterCity != null
                              ? Colors.white
                              : Colors.white38,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.white38, size: 18),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          _filterLabel('Tarih'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickFilterDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF12121F),
                border: Border.all(
                  color: _filterDate != null
                      ? const Color(0xFFFFD700).withOpacity(0.4)
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 16,
                      color: _filterDate != null
                          ? const Color(0xFFFFD700)
                          : Colors.white38),
                  const SizedBox(width: 10),
                  Text(
                    _filterDate != null
                        ? DateFormat('d MMMM yyyy', 'tr_TR')
                            .format(_filterDate!)
                        : 'Tüm tarihler',
                    style: TextStyle(
                        color: _filterDate != null
                            ? Colors.white
                            : Colors.white38,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  if (_filterDate != null)
                    GestureDetector(
                      onTap: () => setState(() => _filterDate = null),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white38, size: 16),
                    )
                  else
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.white38, size: 18),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          _filterLabel('Saat Aralığı'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickFilterTime(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF12121F),
                      border: Border.all(
                        color: _filterTimeFrom != null
                            ? const Color(0xFFFFD700).withOpacity(0.4)
                            : Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 15,
                            color: _filterTimeFrom != null
                                ? const Color(0xFFFFD700)
                                : Colors.white38),
                        const SizedBox(width: 8),
                        Text(
                          _filterTimeFrom != null
                              ? _fmtTime(_filterTimeFrom!)
                              : 'Başlangıç',
                          style: TextStyle(
                              color: _filterTimeFrom != null
                                  ? Colors.white
                                  : Colors.white38,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ),
                        if (_filterTimeFrom != null) ...[
                          const Spacer(),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _filterTimeFrom = null),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white38, size: 14),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('—',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 16)),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickFilterTime(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF12121F),
                      border: Border.all(
                        color: _filterTimeTo != null
                            ? const Color(0xFFFFD700).withOpacity(0.4)
                            : Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 15,
                            color: _filterTimeTo != null
                                ? const Color(0xFFFFD700)
                                : Colors.white38),
                        const SizedBox(width: 8),
                        Text(
                          _filterTimeTo != null
                              ? _fmtTime(_filterTimeTo!)
                              : 'Bitiş',
                          style: TextStyle(
                              color: _filterTimeTo != null
                                  ? Colors.white
                                  : Colors.white38,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ),
                        if (_filterTimeTo != null) ...[
                          const Spacer(),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _filterTimeTo = null),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white38, size: 14),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (_hasActiveFilter)
            GestureDetector(
              onTap: () {
                _clearFilters();
                setState(() => _filterOpen = false);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.red.withOpacity(0.07),
                  border:
                      Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.clear_all_rounded,
                        color: Colors.redAccent, size: 16),
                    SizedBox(width: 6),
                    Text('Tüm Filtreleri Temizle',
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFFFFD700),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      );

  Widget _filterChip(
      IconData icon, String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded,
                size: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _tab(int index, String label) {
    final sel = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: SizedBox(
          height: double.infinity,
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: sel ? Colors.white : Colors.white38,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════
//  Event Card
// ════════════════════════════════════
class _EventCard extends StatefulWidget {
  final EventModel event;
  final String myUid;
  final String statusText;
  final Color statusColor;
  final String Function(DateTime) formatDate;
  final VoidCallback onTap;

  const _EventCard({
    required this.event,
    required this.myUid,
    required this.statusText,
    required this.statusColor,
    required this.formatDate,
    required this.onTap,
  });

  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard> {
  bool _loading = false;
  bool get _attending => widget.event.attendees.contains(widget.myUid);

  Future<void> _toggle() async {
    setState(() => _loading = true);
    await EventService.toggleAttendance(widget.event.id, widget.myUid);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final isPast = e.isPast;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isPast
                ? [
                    Colors.white.withOpacity(0.04),
                    Colors.white.withOpacity(0.02),
                  ]
                : [
                    Colors.white.withOpacity(0.07),
                    Colors.white.withOpacity(0.03),
                  ],
          ),
          border: Border.all(
            color: isPast
                ? Colors.white.withOpacity(0.06)
                : widget.statusColor.withOpacity(0.25),
          ),
          boxShadow: isPast
              ? []
              : [
                  BoxShadow(
                    color: widget.statusColor.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: widget.statusColor.withOpacity(0.12),
                          ),
                          child: Text(widget.statusText,
                              style: TextStyle(
                                  color: widget.statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(height: 8),
                        Text(e.title,
                            style: TextStyle(
                                color: isPast
                                    ? Colors.white54
                                    : Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3)),
                        const SizedBox(height: 4),
                        Text('@${e.creatorUsername}',
                            style: const TextStyle(
                                color: Color(0xFFFFD700),
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if (!isPast)
                    GestureDetector(
                      onTap: _loading ? null : _toggle,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: _attending
                              ? const LinearGradient(colors: [
                                  Color(0xFFFFD700),
                                  Color(0xFFFF8C00)
                                ])
                              : null,
                          color: _attending
                              ? null
                              : Colors.white.withOpacity(0.07),
                          border: Border.all(
                            color: _attending
                                ? Colors.transparent
                                : Colors.white.withOpacity(0.12),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _attending
                                        ? Icons.check_rounded
                                        : Icons.add_rounded,
                                    size: 14,
                                    color: _attending
                                        ? Colors.white
                                        : Colors.white54,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _attending ? 'Katılıyorum' : 'Katıl',
                                    style: TextStyle(
                                        color: _attending
                                            ? Colors.white
                                            : Colors.white54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  Icon(Icons.location_on_rounded,
                      size: 13,
                      color: Colors.white.withOpacity(0.35)),
                  const SizedBox(width: 4),
                  Text(e.city,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(width: 12),
                  Icon(Icons.schedule_rounded,
                      size: 13,
                      color: Colors.white.withOpacity(0.35)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${widget.formatDate(e.startDateTime)} → ${widget.formatDate(e.endDateTime)}',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.people_rounded,
                      size: 13,
                      color: Colors.white.withOpacity(0.35)),
                  const SizedBox(width: 4),
                  Text('${e.attendees.length}',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}