import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  String? _errorMessage;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // 🆕 Sözleşme & KVKK
  bool _kullaniciSozlesmesiOnay = false;
  bool _kvkkOnay = false;
  bool _kullaniciSozlesmesiAcildi = false;
  bool _kvkkAcildi = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    // 🆕 Sözleşme kontrolleri
    if (!_kullaniciSozlesmesiOnay || !_kvkkOnay) {
      setState(() {
        _errorMessage =
            'Devam etmek için Kullanıcı Sözleşmesi ve KVKK metnini onaylamalısın.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.register(
        email: _emailController.text,
        password: _passwordController.text,
        username: _usernameController.text,
      );
      if (mounted) Navigator.of(context).pop();
    } on fb.FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _mapError(e.code));
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Bu email zaten kayıtlı';
      case 'weak-password':
        return 'Şifre çok zayıf, en az 6 karakter olmalı';
      case 'invalid-email':
        return 'Geçersiz email adresi';
      case 'username-taken':
        return 'Bu kullanıcı adı zaten alınmış';
      default:
        return 'Kayıt olunamadı ($code)';
    }
  }

  // 🆕 Sözleşme metni göster — en alta inmeden kapatılmasın
  void _showAgreementSheet({
    required String title,
    required String content,
    required VoidCallback onAccepted,
  }) {
    bool reachedBottom = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF0F0F1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                // Başlık
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withOpacity(0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.description_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (!reachedBottom)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Onaylamak için metni sonuna kadar oku ↓',
                      style: TextStyle(
                        color: Colors.amber.withOpacity(0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                // Metin
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollEndNotification) {
                        final metrics = notification.metrics;
                        if (metrics.pixels >= metrics.maxScrollExtent - 30) {
                          if (!reachedBottom) {
                            setSheetState(() => reachedBottom = true);
                          }
                        }
                      }
                      return false;
                    },
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          content,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 13,
                            height: 1.7,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Butonlar
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Row(
                    children: [
                      // Kapat
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: Colors.white.withOpacity(0.06),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.08)),
                            ),
                            child: const Center(
                              child: Text('Kapat',
                                  style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Onayla
                      Expanded(
                        child: GestureDetector(
                          onTap: reachedBottom
                              ? () {
                                  Navigator.pop(ctx);
                                  onAccepted();
                                }
                              : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: reachedBottom
                                  ? const LinearGradient(colors: [
                                      Color(0xFFFFD700),
                                      Color(0xFFFF8C00)
                                    ])
                                  : null,
                              color: reachedBottom
                                  ? null
                                  : Colors.white.withOpacity(0.04),
                            ),
                            child: Center(
                              child: Text(
                                'Okudum, Onaylıyorum',
                                style: TextStyle(
                                  color: reachedBottom
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.15),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 🆕 Sözleşme checkbox widget
  Widget _agreementCheckbox({
    required String label,
    required bool checked,
    required bool opened,
    required VoidCallback onTap,
    required VoidCallback onTextTap,
  }) {
    return GestureDetector(
      onTap: () {
        if (!opened) {
          // İlk kez açmalı
          onTextTap();
        } else {
          onTap();
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: checked
              ? const Color(0xFF4CAF50).withOpacity(0.08)
              : Colors.white.withOpacity(0.04),
          border: Border.all(
            color: checked
                ? const Color(0xFF4CAF50).withOpacity(0.25)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                gradient: checked
                    ? const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)])
                    : null,
                color: checked ? null : Colors.white.withOpacity(0.06),
                border: Border.all(
                  color: checked
                      ? const Color(0xFF4CAF50)
                      : Colors.white.withOpacity(0.15),
                  width: 1.5,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 12),
            // Metin (tıklanınca açılır)
            Expanded(
              child: GestureDetector(
                onTap: onTextTap,
                child: Text(
                  label,
                  style: TextStyle(
                    color: checked
                        ? const Color(0xFF4CAF50)
                        : Colors.white.withOpacity(0.5),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: checked
                        ? const Color(0xFF4CAF50).withOpacity(0.4)
                        : Colors.white.withOpacity(0.2),
                  ),
                ),
              ),
            ),
            if (!opened)
              Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.15), size: 14),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0A0F),
              Color(0xFF0F0F1A),
              Color(0xFF0A0A0F),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),

                        // ── Logo ──
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color.fromARGB(255, 255, 0, 179)
                                    .withOpacity(0.3),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text('👂', style: TextStyle(fontSize: 34)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Aramıza Katıl',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Birkaç bilgi ile hemen başla',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // ── Error ──
                        if (_errorMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline_rounded,
                                    color: Colors.red.shade300, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: Colors.red.shade300,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // ── Email ──
                        _GlassInput(
                          controller: _emailController,
                          hint: 'Email adresin',
                          icon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Email gerekli';
                            if (!v.contains('@')) return 'Geçerli email gir';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // ── Kullanıcı Adı ──
                        _GlassInput(
                          controller: _usernameController,
                          hint: 'Kullanıcı adı',
                          icon: Icons.alternate_email_rounded,
                          maxLength: 20,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Kullanıcı adı gerekli';
                            }
                            if (v.length < 3) return 'En az 3 karakter';
                            if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(v)) {
                              return 'Sadece harf, rakam, . ve _ kullan';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // ── Şifre ──
                        _GlassInput(
                          controller: _passwordController,
                          hint: 'Şifre (en az 6 karakter)',
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscure1,
                          suffixIcon: GestureDetector(
                            onTap: () => setState(() => _obscure1 = !_obscure1),
                            child: Icon(
                              _obscure1
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.white24,
                              size: 20,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Şifre gerekli';
                            if (v.length < 6) return 'En az 6 karakter';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // ── Şifre Tekrar ──
                        _GlassInput(
                          controller: _confirmController,
                          hint: 'Şifre tekrar',
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscure2,
                          suffixIcon: GestureDetector(
                            onTap: () => setState(() => _obscure2 = !_obscure2),
                            child: Icon(
                              _obscure2
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.white24,
                              size: 20,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Şifre tekrarı gerekli';
                            }
                            if (v != _passwordController.text) {
                              return 'Şifreler eşleşmiyor';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // ══════════════════════════════════════
                        // 🆕 Kullanıcı Sözleşmesi & KVKK
                        // ══════════════════════════════════════
                        _agreementCheckbox(
                          label:
                              'Kullanıcı Sözleşmesi\'ni okudum, kabul ediyorum',
                          checked: _kullaniciSozlesmesiOnay,
                          opened: _kullaniciSozlesmesiAcildi,
                          onTap: () {
                            setState(() => _kullaniciSozlesmesiOnay =
                                !_kullaniciSozlesmesiOnay);
                          },
                          onTextTap: () {
                            _showAgreementSheet(
                              title: 'Kullanıcı Sözleşmesi',
                              content: _kullaniciSozlesmesiMetni,
                              onAccepted: () {
                                setState(() {
                                  _kullaniciSozlesmesiAcildi = true;
                                  _kullaniciSozlesmesiOnay = true;
                                });
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        _agreementCheckbox(
                          label:
                              'KVKK Aydınlatma Metni\'ni okudum, kabul ediyorum',
                          checked: _kvkkOnay,
                          opened: _kvkkAcildi,
                          onTap: () {
                            setState(() => _kvkkOnay = !_kvkkOnay);
                          },
                          onTextTap: () {
                            _showAgreementSheet(
                              title: 'KVKK Aydınlatma Metni',
                              content: _kvkkMetni,
                              onAccepted: () {
                                setState(() {
                                  _kvkkAcildi = true;
                                  _kvkkOnay = true;
                                });
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // ── Kayıt Butonu ──
                        _GradientButton(
                          text: 'Kayıt Ol',
                          isLoading: _isLoading,
                          onTap: _register,
                          colors: const [Color(0xFFFFD700), Color(0xFFFF8C00)],
                        ),
                        const SizedBox(height: 24),

                        // ── Giriş yap ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Zaten hesabın var mı? ',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 14,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Text(
                                'Giriş Yap',
                                style: TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // 🆕 Sözleşme Metinleri
  // ══════════════════════════════════════
  static const String _kullaniciSozlesmesiMetni = '''
HEARDO​VER KULLANICI SÖZLEŞMESİ

Son Güncelleme: 19 Nisan 2026

1. TARAFLAR
Bu sözleşme, HeardOver mobil uygulamasını ("Uygulama") kullanan siz ("Kullanıcı") ile HeardOver ekibi ("Şirket") arasında akdedilmiştir.

2. HİZMETİN TANIMI
HeardOver, kullanıcıların konum bazlı olarak kendi oluşturdukları metin içeriklerini paylaşabildiği, diğer kullanıcılarla etkileşime geçebildiği bir sosyal platformdur.

3. HESAP VE GÜVENLİK
• Kayıt olmak için geçerli bir e-posta adresi gereklidir.
• Hesap güvenliğinden kullanıcı sorumludur.
• 13 yaş altındaki kişilerin uygulamayı kullanması yasaktır.

4. KULLANIM KURALLARI
Kullanıcılar aşağıdaki kurallara uymayı kabul eder:

• Hakaret, iftira, tehdit, nefret söylemi veya ayrımcılık içeren içerik paylaşmamak  
• Kişisel verileri (telefon numarası, adres, kimlik bilgileri vb.) izinsiz paylaşmamak  
• Özel hayatın gizliliğini ihlal eden içerikler paylaşmamak  
• Suç teşkil eden veya suç teşvik eden içerik paylaşmamak  
• Müstehcen, cinsel veya aşırı şiddet içeren içerikler paylaşmamak  
• Sahte hesap oluşturmamak veya başkasını taklit etmemek  
• Uygulamanın teknik altyapısına zarar verecek girişimlerde bulunmamak  

5. İÇERİK SORUMLULUĞU
• Kullanıcılar paylaştıkları tüm içeriklerden tamamen kendileri sorumludur.  
• HeardOver, kullanıcı içeriklerini önceden kontrol etmekle yükümlü değildir.  

Ancak HeardOver:  
• Kullanıcı bildirimleri (report sistemi)  
• Otomatik tespit sistemleri  
• Yasal bildirimler  

doğrultusunda içerikleri inceleyebilir, kaldırabilir ve kullanıcı hesaplarına yaptırım uygulayabilir.

6. MODERASYON VE YAPTIRIMLAR
HeardOver aşağıdaki durumlarda müdahale edebilir:

• İçerik silme  
• Geçici hesap kısıtlama  
• Kalıcı hesap kapatma  

7. MESAJLAŞMA VE İÇERİK SÜRELERİ
• Toplu sohbet mesajları geçici olup yaklaşık 30 saniye içerisinde silinebilir  
• Kullanıcılar arası özel mesajlaşma (DM) hizmeti sağlanır  
• Bu içeriklerin sorumluluğu kullanıcıya aittir  

8. FİKRİ MÜLKİYET
• HeardOver uygulamasına ait tüm haklar HeardOver ekibine aittir  
• Kullanıcılar, paylaştıkları içeriklerin uygulama içinde görüntülenmesine izin verir  

9. SORUMLULUK SINIRI
HeardOver:

• Kullanıcılar arasında gerçekleşen etkileşimlerden  
• Kullanıcı içeriklerinden  
• Üçüncü taraf davranışlarından  

doğrudan sorumlu değildir.

Ancak yasal yükümlülükler kapsamında gerekli aksiyonları alma hakkını saklı tutar.

10. HESAP KAPATMA
• Kullanıcılar istedikleri zaman hesaplarını silebilir  
• HeardOver, sözleşme ihlali durumunda hesapları askıya alma veya kapatma hakkına sahiptir  

11. DEĞİŞİKLİKLER
Bu sözleşme HeardOver tarafından güncellenebilir. Güncellemeler uygulama içinde yayınlanır.

12. UYGULANACAK HUKUK
Bu sözleşme Türkiye Cumhuriyeti yasalarına tabidir.

Bu sözleşmeyi kabul ederek tüm şartları okuduğunuzu ve kabul ettiğinizi beyan etmiş olursunuz.
''';

  static const String _kvkkMetni = '''
HEARDO​VER KİŞİSEL VERİLERİN KORUNMASI AYDINLATMA METNİ

Son Güncelleme: 19 Nisan 2026

6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") uyarınca, HeardOver olarak kişisel verilerinizin güvenliğine önem veriyoruz.

1. VERİ SORUMLUSU
HeardOver, KVKK kapsamında veri sorumlusu olarak hareket eder.

2. İŞLENEN VERİLER
Uygulama kapsamında aşağıdaki veriler işlenebilir:

• Hesap bilgileri (kullanıcı adı, e-posta adresi)  
• Profil bilgileri (profil fotoğrafı vb.)  
• Konum verisi (kullanıcı izni ile)  
• Kullanıcı içerikleri (paylaşımlar, mesajlar)  
• Kullanım verileri ve teknik log kayıtları  

3. VERİLERİN İŞLENME AMAÇLARI
Kişisel verileriniz:

• Hizmet sunulması  
• Mesajlaşma ve sosyal özelliklerin sağlanması  
• Güvenlik ve kötüye kullanımın önlenmesi  
• Uygulamanın geliştirilmesi  
• Yasal yükümlülüklerin yerine getirilmesi  

amaçlarıyla işlenir.

4. VERİLERİN AKTARILMASI
Kişisel veriler:

• Firebase (Google) gibi altyapı sağlayıcılarla  
• Yasal zorunluluk halinde yetkili kamu kurumlarıyla  

paylaşılabilir.

Veriler, hizmet altyapısı kapsamında yurt dışında bulunan sunucularda işlenebilir.

5. VERİ SAKLAMA
Kişisel veriler:

• Hesap aktif olduğu sürece saklanır  
• Hesap silme talebi sonrası, yasal yükümlülükler saklı kalmak kaydıyla silinir, yok edilir veya anonim hale getirilir  

6. VERİ GÜVENLİĞİ
Verilerinizin korunması için:

• Şifreli bağlantı (HTTPS)  
• Yetkilendirme sistemleri  
• Teknik ve idari güvenlik önlemleri  

uygulanmaktadır.

7. KULLANICI HAKLARI
KVKK kapsamında kullanıcılar:

• Verilerine erişme  
• Düzeltme talep etme  
• Silinmesini isteme  
• İşlenmeye itiraz etme  

haklarına sahiptir.

8. İLETİŞİM
Talepleriniz için:  
📧 heardover.destek@gmail.com  

Başvurularınız 30 gün içinde yanıtlanır.

9. DEĞİŞİKLİKLER
Bu metin güncellenebilir. Güncellemeler uygulama içinde yayınlanır.

Bu metni kabul ederek kişisel verilerinizin yukarıdaki şekilde işlenmesini kabul etmiş olursunuz.
''';
}

// ══════════════════════════════════════
//  Glassmorphism Input
// ═══════════════════��══════════════════
class _GlassInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int? maxLength;

  const _GlassInput({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.03),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            maxLength: maxLength,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.2),
                fontSize: 15,
              ),
              prefixIcon: Icon(icon, color: Colors.white24, size: 20),
              suffixIcon: suffixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: suffixIcon,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              counterText: '',
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════
//  Gradient Buton
// ══════════════════════════════════════
class _GradientButton extends StatelessWidget {
  final String text;
  final bool isLoading;
  final VoidCallback onTap;
  final List<Color> colors;

  const _GradientButton({
    required this.text,
    required this.isLoading,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.first.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }
}
