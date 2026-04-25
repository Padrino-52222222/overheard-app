import 'package:HeardOver/models/event_model.dart';
import 'package:HeardOver/services/auth_service.dart';
import 'package:HeardOver/services/event_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _selectedCity;
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  bool _loading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  DateTime? get _startDateTime {
    if (_startDate == null || _startTime == null) return null;
    return DateTime(
      _startDate!.year, _startDate!.month, _startDate!.day,
      _startTime!.hour, _startTime!.minute,
    );
  }

  DateTime? get _endDateTime {
    if (_endDate == null || _endTime == null) return null;
    return DateTime(
      _endDate!.year, _endDate!.month, _endDate!.day,
      _endTime!.hour, _endTime!.minute,
    );
  }

  bool get _isValid =>
      _titleCtrl.text.trim().isNotEmpty &&
      _selectedCity != null &&
      _startDateTime != null &&
      _endDateTime != null &&
      _endDateTime!.isAfter(_startDateTime!);

  Future<void> _pickStartDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: _datePickerTheme,
    );
    if (d != null) setState(() => _startDate = d);
  }

  Future<void> _pickStartTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
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
    if (t != null) setState(() => _startTime = t);
  }

  Future<void> _pickEndDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: _datePickerTheme,
    );
    if (d != null) setState(() => _endDate = d);
  }

  Future<void> _pickEndTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
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
    if (t != null) setState(() => _endTime = t);
  }

  Widget _datePickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD700),
          onPrimary: Colors.black,
          surface: Color(0xFF12121F),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF12121F),
        ),
      ),
      child: child!,
    );
  }

  void _showCityPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
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
              const Text(
                'Şehir Seç',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: EventService.cities.length,
                  itemBuilder: (_, i) {
                    final city = EventService.cities[i];
                    final isIstanbul = city.startsWith('İstanbul');
                    final isSel = _selectedCity == city;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedCity = city);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
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
                                ? const Color(0xFFFFD700)
                                    .withOpacity(0.2)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_city_rounded,
                              size: 16,
                              color: isSel
                                  ? Colors.white
                                  : isIstanbul
                                      ? const Color(0xFFFFD700)
                                      : Colors.white38,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              city,
                              style: TextStyle(
                                color: isSel
                                    ? Colors.white
                                    : isIstanbul
                                        ? const Color(0xFFFFD700)
                                        : Colors.white70,
                                fontSize: 15,
                                fontWeight: isIstanbul || isSel
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            if (isSel) ...[
                              const Spacer(),
                              const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 18),
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

  Future<void> _create() async {
    if (!_isValid) return;
    setState(() => _loading = true);

    try {
      final profile = await AuthService.getUserProfile();
      final uid = profile?['uid'] ?? '';
      final username = profile?['username'] ?? 'anonim';

      final event = EventModel(
        id: '',
        creatorUid: uid,
        creatorUsername: username,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        city: _selectedCity!,
        startDateTime: _startDateTime!,
        endDateTime: _endDateTime!,
        attendees: [],
        createdAt: Timestamp.now(),
      );

      await EventService.createEvent(event);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Etkinlik oluşturuldu! 🎉'),
            ]),
            backgroundColor: const Color(0xFF72246C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtDate(DateTime? d) => d == null
      ? 'Tarih seç'
      : DateFormat('d MMM yyyy', 'tr_TR').format(d);

  String _fmtTime(TimeOfDay? t) => t == null
      ? 'Saat seç'
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withOpacity(0.07),
                      ),
                      child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Etkinlik Oluştur',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Etkinlik Başlığı'),
                    const SizedBox(height: 8),
                    _textField(
                      controller: _titleCtrl,
                      hint: 'Etkinliğe bir isim ver...',
                      maxLength: 60,
                    ),

                    const SizedBox(height: 20),

                    _label('Açıklama'),
                    const SizedBox(height: 8),
                    _textField(
                      controller: _descCtrl,
                      hint: 'Etkinlik hakkında kısa bir açıklama...',
                      maxLines: 3,
                      maxLength: 200,
                    ),

                    const SizedBox(height: 20),

                    _label('Şehir'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _showCityPicker,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: const Color(0xFF12121F),
                          border: Border.all(
                            color: _selectedCity != null
                                ? const Color(0xFFFFD700)
                                    .withOpacity(0.3)
                                : Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_city_rounded,
                              size: 18,
                              color: _selectedCity != null
                                  ? const Color(0xFFFFD700)
                                  : Colors.white38,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _selectedCity ?? 'Şehir seç...',
                              style: TextStyle(
                                color: _selectedCity != null
                                    ? Colors.white
                                    : Colors.white38,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white38,
                                size: 20),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    _label('Başlangıç'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _pickerTile(
                            icon: Icons.calendar_today_rounded,
                            text: _fmtDate(_startDate),
                            hasValue: _startDate != null,
                            onTap: _pickStartDate,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _pickerTile(
                            icon: Icons.access_time_rounded,
                            text: _fmtTime(_startTime),
                            hasValue: _startTime != null,
                            onTap: _pickStartTime,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    _label('Bitiş'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _pickerTile(
                            icon: Icons.calendar_today_rounded,
                            text: _fmtDate(_endDate),
                            hasValue: _endDate != null,
                            onTap: _pickEndDate,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _pickerTile(
                            icon: Icons.access_time_rounded,
                            text: _fmtTime(_endTime),
                            hasValue: _endTime != null,
                            onTap: _pickEndTime,
                          ),
                        ),
                      ],
                    ),

                    if (_startDateTime != null &&
                        _endDateTime != null &&
                        !_endDateTime!.isAfter(_startDateTime!)) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.warning_rounded,
                              color: Colors.red.shade400, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Bitiş tarihi başlangıçtan sonra olmalı',
                            style: TextStyle(
                                color: Colors.red.shade400,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 32),

                    GestureDetector(
                      onTap: _isValid && !_loading ? _create : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: _isValid
                              ? const LinearGradient(colors: [
                                  Color(0xFFFFD700),
                                  Color(0xFFFF8C00)
                                ])
                              : null,
                          color: _isValid
                              ? null
                              : Colors.white.withOpacity(0.05),
                          boxShadow: _isValid
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFFFD700)
                                        .withOpacity(0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white),
                                )
                              : Text(
                                  'Etkinliği Oluştur',
                                  style: TextStyle(
                                    color: _isValid
                                        ? Colors.white
                                        : Colors.white24,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFFFFD700),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF12121F),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              color: Color(0xFF444444), fontSize: 15),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          counterStyle: const TextStyle(
              color: Color(0xFF444444), fontSize: 11),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _pickerTile({
    required IconData icon,
    required String text,
    required bool hasValue,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFF12121F),
          border: Border.all(
            color: hasValue
                ? const Color(0xFFFFD700).withOpacity(0.3)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 15,
                color: hasValue
                    ? const Color(0xFFFFD700)
                    : Colors.white38),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: hasValue ? Colors.white : Colors.white38,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}