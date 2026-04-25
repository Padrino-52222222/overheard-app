import 'package:flutter/material.dart';
import '../services/report_service.dart';

/// Her yerden tek satırla çağır:
///
/// ```dart
/// ReportBottomSheet.show(
///   context: context,
///   type: ReportType.post,
///   reportedId: postId,
///   reportedUserId: userId,
/// );
/// ```
class ReportBottomSheet {
  static Future<void> show({
    required BuildContext context,
    required ReportType type,
    required String reportedId,
    String? reportedUserId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReportSheet(
        type: type,
        reportedId: reportedId,
        reportedUserId: reportedUserId,
      ),
    );
  }
}

class _ReportSheet extends StatefulWidget {
  final ReportType type;
  final String reportedId;
  final String? reportedUserId;

  const _ReportSheet({
    required this.type,
    required this.reportedId,
    this.reportedUserId,
  });

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReasonData? _selectedReason;
  final _noteController = TextEditingController();
  bool _isSending = false;
  _SheetPage _page = _SheetPage.selectReason;

  String get _typeLabel {
    switch (widget.type) {
      case ReportType.post:
        return 'Gönderiyi';
      case ReportType.user:
        return 'Kullanıcıyı';
      case ReportType.message:
        return 'Mesajı';
      case ReportType.directMessage:
        return 'Mesajı';
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) return;

    setState(() => _isSending = true);
    try {
      await ReportService.submitReport(
        type: widget.type,
        reason: _selectedReason!.reason,
        reportedId: widget.reportedId,
        reportedUserId: widget.reportedUserId,
        extraNote: _noteController.text.trim(),
      );

      if (mounted) {
        setState(() => _page = _SheetPage.success);
        // 2 saniye sonra kapat
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } on ReportException catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        _showError(e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        _showError('Bir hata oluştu, tekrar dene');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF12121F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
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

          // Sayfa içeriği
          if (_page == _SheetPage.selectReason) _buildReasonPage(),
          if (_page == _SheetPage.addNote) _buildNotePage(),
          if (_page == _SheetPage.success) _buildSuccessPage(),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  Sayfa 1 — Neden seçimi
  // ══════════════════════════════════════
  Widget _buildReasonPage() {
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Başlık
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.shade700.withOpacity(0.12),
              border:
                  Border.all(color: Colors.red.shade700.withOpacity(0.25), width: 2),
            ),
            child: Icon(Icons.flag_rounded, color: Colors.red.shade400, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            '$_typeLabel Bildir',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Neden bildirmek istiyorsun?',
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),

          // Neden listesi
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: ReportService.reasons.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = ReportService.reasons[index];
                final isSelected = _selectedReason?.reason == item.reason;

                return GestureDetector(
                  onTap: () => setState(() => _selectedReason = item),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: isSelected
                          ? Colors.red.shade700.withOpacity(0.12)
                          : Colors.white.withOpacity(0.04),
                      border: Border.all(
                        color: isSelected
                            ? Colors.red.shade400.withOpacity(0.5)
                            : Colors.white.withOpacity(0.06),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(item.icon, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.red.shade300
                                      : Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.description,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.3),
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle_rounded,
                              color: Colors.red.shade400, size: 22)
                        else
                          Icon(Icons.circle_outlined,
                              color: Colors.white.withOpacity(0.1), size: 22),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Devam butonu
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: GestureDetector(
              onTap: _selectedReason == null
                  ? null
                  : () => setState(() => _page = _SheetPage.addNote),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: _selectedReason != null
                      ? LinearGradient(
                          colors: [Colors.red.shade600, Colors.red.shade900])
                      : null,
                  color: _selectedReason == null
                      ? Colors.white.withOpacity(0.04)
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Devam Et',
                    style: TextStyle(
                      color: _selectedReason != null
                          ? Colors.white
                          : Colors.white.withOpacity(0.2),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  Sayfa 2 — Ek not + gönder
  // ══════════════════════════════════════
  Widget _buildNotePage() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Geri butonu + başlık
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _page = _SheetPage.selectReason),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white54, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Ek Açıklama',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'İsteğe bağlı — durumu daha iyi anlamamız için detay ekle.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),

          // Seçilen neden özeti
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.red.shade700.withOpacity(0.08),
              border: Border.all(color: Colors.red.shade700.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Text(_selectedReason!.icon,
                    style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Text(
                  _selectedReason!.title,
                  style: TextStyle(
                    color: Colors.red.shade300,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Not alanı
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withOpacity(0.04),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: TextField(
              controller: _noteController,
              maxLines: 4,
              maxLength: 300,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, height: 1.5),
              decoration: InputDecoration(
                hintText: 'Ne olduğunu kısaca açıkla... (isteğe bağlı)',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.15),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                counterStyle: TextStyle(
                  color: Colors.white.withOpacity(0.2),
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Gönder butonu
          GestureDetector(
            onTap: _isSending ? null : _submit,
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: _isSending
                    ? null
                    : LinearGradient(
                        colors: [Colors.red.shade600, Colors.red.shade900]),
                color: _isSending ? Colors.white.withOpacity(0.06) : null,
              ),
              child: Center(
                child: _isSending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.redAccent))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('Bildirimi Gönder',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  Sayfa 3 — Başarılı
  // ══════════════════════════════════════
  Widget _buildSuccessPage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4CAF50).withOpacity(0.12),
              border: Border.all(
                  color: const Color(0xFF4CAF50).withOpacity(0.3), width: 2),
            ),
            child: const Icon(Icons.check_rounded,
                color: Color(0xFF4CAF50), size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'Bildirim Gönderildi',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bildirimini aldık, en kısa sürede inceleyeceğiz.\nTeşekkürler! 🙏',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

enum _SheetPage { selectReason, addNote, success }