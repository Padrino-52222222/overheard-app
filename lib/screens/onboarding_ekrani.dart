import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/avatar_service.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onComplete; // 🆕
  const OnboardingScreen({super.key, this.onComplete});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSaving = false;

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String? _selectedCity;
  String? _selectedGender;
  File? _selectedPhoto;
  String? _selectedPresetAvatar;

  static const int _totalSteps = 6;

  final List<String> _cities = [
    'İstanbul',
    'Ankara',
    'İzmir',
    'Bursa',
    'Antalya',
    'Adana',
    'Konya',
    'Gaziantep',
    'Mersin',
    'Diyarbakır',
    'Kayseri',
    'Eskişehir',
    'Trabzon',
    'Samsun',
    'Denizli',
    'Malatya',
    'Kocaeli',
    'Sakarya',
    'Muğla',
    'Tekirdağ',
    'Diğer',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _skipStep() {
    if (_currentPage < _totalSteps - 1) {
      _nextPage();
    } else {
      _finish();
    }
  }

  void _validateAndNext() {
    switch (_currentPage) {
      case 1:
        final name = _nameController.text.trim();
        if (name.isEmpty) {
          _showWarning(
              'İsim alanı boş. Devam etmek için bilgi girin veya atlayabilirsiniz.');
          return;
        }
        if (name.length < 2) {
          _showWarning('İsim en az 2 karakter olmalı.');
          return;
        }
        if (!RegExp(r'^[a-zA-ZçÇğĞıİöÖşŞüÜ\s]+$').hasMatch(name)) {
          _showWarning('İsim sadece harflerden oluşmalı.');
          return;
        }
        break;
      case 2:
        final ageText = _ageController.text.trim();
        if (ageText.isEmpty) {
          _showWarning(
              'Yaş alanı boş. Devam etmek için bilgi girin veya atlayabilirsiniz.');
          return;
        }
        final age = int.tryParse(ageText);
        if (age == null) {
          _showWarning('Yaş sadece rakam olmalı.');
          return;
        }
        if (age < 13 || age > 120) {
          _showWarning('Geçerli bir yaş girin (13-120).');
          return;
        }
        break;
      case 3:
        if (_selectedCity == null) {
          _showWarning(
              'Şehir seçilmedi. Devam etmek için bilgi girin veya atlayabilirsiniz.');
          return;
        }
        break;
      case 4:
        if (_selectedGender == null) {
          _showWarning(
              'Cinsiyet seçilmedi. Devam etmek için bilgi girin veya atlayabilirsiniz.');
          return;
        }
        break;
    }
    _nextPage();
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF72246C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 75,
    );
    if (picked != null) {
      setState(() {
        _selectedPhoto = File(picked.path);
        _selectedPresetAvatar = null;
      });
    }
  }

  void _selectPresetAvatar(String assetPath) {
    setState(() {
      _selectedPresetAvatar = assetPath;
      _selectedPhoto = null;
    });
  }

  Future<void> _finish() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      String? photoUrl;

      // Galeri fotoğrafı seçildiyse → Firebase'e yükle (eski silinir)
      if (_selectedPhoto != null) {
        photoUrl = await AvatarService.uploadGalleryPhoto(_selectedPhoto!);
      }
      // Preset avatar seçildiyse → Firebase'e yükle (eski silinir)
      else if (_selectedPresetAvatar != null) {
        photoUrl =
            await AvatarService.uploadPresetAvatar(_selectedPresetAvatar!);
      }

      await AuthService.updateOnboarding(
        fullName: _nameController.text.trim(),
        age: int.tryParse(_ageController.text.trim()),
        city: _selectedCity,
        gender: _selectedGender,
        photoUrl: photoUrl,
      );
    } catch (_) {}
    if (mounted) {
      setState(() => _isSaving = false);
      // 🆕 Callback varsa çağır (OnboardingGate yeniden kontrol eder)
      if (widget.onComplete != null) {
        widget.onComplete!();
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Container(
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
              // ── Progress Bar + Atla ──
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      GestureDetector(
                        onTap: _prevPage,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.08)),
                          ),
                          child: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white54, size: 18),
                        ),
                      )
                    else
                      const SizedBox(width: 38),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StepIndicator(
                        currentStep: _currentPage,
                        totalSteps: _totalSteps,
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: _skipStep,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white.withOpacity(0.06),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Text(
                          'Atla',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Sayfalar ──
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: [
                    _buildWelcomePage(),
                    _buildNamePage(),
                    _buildAgePage(),
                    _buildCityPage(),
                    _buildGenderPage(),
                    _buildPhotoPage(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.35),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Center(
              child: Text('🎉', style: TextStyle(fontSize: 48)),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Hoş Geldin!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'HeardOver\'a katıldığın için harika! 🚀\n\n'
            'Seni daha iyi tanımak istiyoruz.\n'
            'Aşağıdaki bilgileri doldurabilirsin —\n'
            'ama hiçbiri zorunlu değil!\n\n'
            'İstediğin zaman "Atla" ya basarak geçebilirsin.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 15,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 40),
          _OnboardingButton(
            text: 'Hadi Başlayalım',
            onTap: _nextPage,
            colors: const [Color(0xFF72246C), Color(0xFF9B30FF)],
          ),
        ],
      ),
    );
  }

  Widget _buildNamePage() {
    return _OnboardingPageLayout(
      emoji: '✍️',
      title: 'Adın ne?',
      subtitle:
          'İsim ve soyismini yazabilirsin.\nSadece harf, en az 2 en fazla 15 karakter.',
      child: Column(
        children: [
          _OnboardingInput(
            controller: _nameController,
            hint: 'Adın Soyadın',
            icon: Icons.person_outline_rounded,
            maxLength: 15,
            keyboardType: TextInputType.name,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                  RegExp(r'[a-zA-ZçÇğĞıİöÖşŞüÜ\s]')),
            ],
          ),
          const SizedBox(height: 28),
          _OnboardingButton(
            text: 'Devam',
            onTap: _validateAndNext,
            colors: const [Color(0xFFFFD700), Color(0xFFFF8C00)],
          ),
        ],
      ),
    );
  }

  Widget _buildAgePage() {
    return _OnboardingPageLayout(
      emoji: '🎂',
      title: 'Kaç yaşındasın?',
      subtitle: 'Yaşın profilinde görünecek.\nSadece rakam gir.',
      child: Column(
        children: [
          _OnboardingInput(
            controller: _ageController,
            hint: 'Yaşın',
            icon: Icons.cake_outlined,
            keyboardType: TextInputType.number,
            maxLength: 3,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
          const SizedBox(height: 28),
          _OnboardingButton(
            text: 'Devam',
            onTap: _validateAndNext,
            colors: const [Color(0xFFFFD700), Color(0xFFFF8C00)],
          ),
        ],
      ),
    );
  }

  Widget _buildCityPage() {
    return _OnboardingPageLayout(
      emoji: '🏙️',
      title: 'Nerede yaşıyorsun?',
      subtitle: 'Şehrini seç, yakınındaki overheard\'ları göster.',
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.03),
                ],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedCity,
              dropdownColor: const Color(0xFF1A1A2E),
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Colors.white24),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Şehir seç',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.2),
                  fontSize: 15,
                ),
                prefixIcon: const Icon(Icons.location_city_rounded,
                    color: Colors.white24, size: 20),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              items: _cities
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCity = v),
            ),
          ),
          const SizedBox(height: 28),
          _OnboardingButton(
            text: 'Devam',
            onTap: _validateAndNext,
            colors: const [Color(0xFFFFD700), Color(0xFFFF8C00)],
          ),
        ],
      ),
    );
  }

  Widget _buildGenderPage() {
    return _OnboardingPageLayout(
      emoji: '👤',
      title: 'Cinsiyetin',
      subtitle: 'Bu bilgi tamamen isteğe bağlı.',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _GenderCard(
                  label: 'Erkek',
                  icon: Icons.male_rounded,
                  isSelected: _selectedGender == 'Erkek',
                  onTap: () => setState(() => _selectedGender = 'Erkek'),
                  selectedColors: const [Color(0xFF1E88E5), Color(0xFF42A5F5)],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _GenderCard(
                  label: 'Kadın',
                  icon: Icons.female_rounded,
                  isSelected: _selectedGender == 'Kadın',
                  onTap: () => setState(() => _selectedGender = 'Kadın'),
                  selectedColors: const [Color(0xFFE91E63), Color(0xFFF06292)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _OnboardingButton(
            text: 'Devam',
            onTap: _validateAndNext,
            colors: const [Color(0xFFFFD700), Color(0xFFFF8C00)],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPage() {
    return _OnboardingPageLayout(
      emoji: '📸',
      title: 'Profil Fotoğrafın',
      subtitle:
          'Bir avatar seç veya kendi fotoğrafını yükle!\nSonra da değiştirebilirsin.',
      child: Column(
        children: [
          // Seçilen fotoğraf/avatar önizleme
          GestureDetector(
            onTap: _pickPhoto,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                    (_selectedPhoto == null && _selectedPresetAvatar == null)
                        ? LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.08),
                              Colors.white.withOpacity(0.03),
                            ],
                          )
                        : null,
                border: Border.all(
                  color:
                      (_selectedPhoto != null || _selectedPresetAvatar != null)
                          ? const Color(0xFFFFD700).withOpacity(0.5)
                          : Colors.white.withOpacity(0.1),
                  width: 2,
                ),
                boxShadow:
                    (_selectedPhoto != null || _selectedPresetAvatar != null)
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                image: _selectedPhoto != null
                    ? DecorationImage(
                        image: FileImage(_selectedPhoto!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _selectedPresetAvatar != null
                  ? ClipOval(
                      child: Image.asset(
                        _selectedPresetAvatar!,
                        fit: BoxFit.cover,
                        width: 120,
                        height: 120,
                      ),
                    )
                  : _selectedPhoto == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt_rounded,
                                color: Colors.white.withOpacity(0.25),
                                size: 36),
                            const SizedBox(height: 4),
                            Text(
                              'Galeriden Seç',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.25),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : null,
            ),
          ),
          if (_selectedPhoto != null || _selectedPresetAvatar != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() {
                _selectedPhoto = null;
                _selectedPresetAvatar = null;
              }),
              child: Text(
                'Kaldır',
                style: TextStyle(
                  color: Colors.red.withOpacity(0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // ── Preset Avatar Grid ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.06),
                  Colors.white.withOpacity(0.02),
                ],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pets_rounded,
                        color: const Color(0xFFFFD700).withOpacity(0.7),
                        size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'veya bir avatar seç',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 72,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: AvatarService.presetAvatars.length,
                    itemBuilder: (context, index) {
                      final avatar = AvatarService.presetAvatars[index];
                      final isSelected = _selectedPresetAvatar == avatar;
                      return GestureDetector(
                        onTap: () => _selectPresetAvatar(avatar),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 64,
                          height: 64,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFFD700)
                                  : Colors.white.withOpacity(0.1),
                              width: isSelected ? 3 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFFFD700)
                                          .withOpacity(0.3),
                                      blurRadius: 12,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              avatar,
                              fit: BoxFit.cover,
                              width: 64,
                              height: 64,
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
          const SizedBox(height: 28),
          _OnboardingButton(
            text: _isSaving ? 'Kaydediliyor...' : 'Tamamla 🚀',
            onTap: _isSaving ? () {} : _finish,
            colors: const [Color(0xFF72246C), Color(0xFF9B30FF)],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════
//  Step Indicator
// ══════════════════════════════════════
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepIndicator({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final isActive = index <= currentStep;
        return Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: isActive
                  ? const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                    )
                  : null,
              color: isActive ? null : Colors.white.withOpacity(0.08),
            ),
          ),
        );
      }),
    );
  }
}

// ══════════════════════════════════════
//  Onboarding Sayfa Layout
// ══════════════════════════════════════
class _OnboardingPageLayout extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Widget child;

  const _OnboardingPageLayout({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Text(emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 36),
          child,
        ],
      ),
    );
  }
}

// ══════════════════════════════════════
//  Onboarding Input
// ══════════════════════════════════════
class _OnboardingInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  const _OnboardingInput({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.maxLength,
    this.inputFormatters,
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
              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.03),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLength: maxLength,
            inputFormatters: inputFormatters,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.2),
                fontSize: 15,
              ),
              prefixIcon: Icon(icon, color: Colors.white24, size: 20),
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
//  Gender Card
// ══════════════════════════════════════
class _GenderCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final List<Color> selectedColors;

  const _GenderCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.selectedColors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isSelected
              ? LinearGradient(colors: selectedColors)
              : LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.06),
                    Colors.white.withOpacity(0.03),
                  ],
                ),
          border: Border.all(
            color: isSelected
                ? selectedColors.first.withOpacity(0.5)
                : Colors.white.withOpacity(0.08),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: selectedColors.first.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 42,
              color: isSelected ? Colors.white : Colors.white30,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isSelected ? 1.0 : 0.0,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: Icon(Icons.check_rounded,
                    color: selectedColors.first, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════
//  Onboarding Buton
// ══════════════════════════════════════
class _OnboardingButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final List<Color> colors;

  const _OnboardingButton({
    required this.text,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
          child: Text(
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
