import 'dart:io';
import 'dart:ui';
import 'package:HeardOver/screens/friend_screen.dart';
import 'package:HeardOver/screens/my_post_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/avatar_service.dart';
import '../services/karizma_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isUploading = false;
  bool _isDeletingAccount = false;
  int _friendCount = 0;
  int _postCount = 0;
  int _karizma = 0;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadProfile();
    _loadStats();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await AuthService.getUserProfile();
    if (mounted) {
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
      _animController.forward();
    }
  }

  Future<void> _loadStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final friendsQuery = await FirebaseFirestore.instance
          .collection('friends')
          .where('users', arrayContains: user.uid)
          .get();
      final friendUids = <String>{};
      for (final doc in friendsQuery.docs) {
        final users = List<String>.from(doc['users']);
        for (final u in users) {
          if (u != user.uid) friendUids.add(u);
        }
      }

      final postsQuery = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: user.uid)
          .get();

      final karizma = await KarizmaService.calculateKarizma(user.uid);

      if (mounted) {
        setState(() {
          _friendCount = friendUids.length;
          _postCount = postsQuery.docs.length;
          _karizma = karizma;
        });
      }
    } catch (_) {}
  }

  // ══════════════════════════════════════
  //  Galeriden Fotoğraf
  // ══════════════════════════════════════
  Future<void> _pickAndUploadPhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (picked == null) return;

      setState(() => _isUploading = true);

      final file = File(picked.path);
      final url = await AvatarService.uploadGalleryPhoto(file);

      if (mounted) {
        setState(() {
          _profile?['photoUrl'] = url;
          _isUploading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Hata: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // ══════════════════════════════════════
  //  Preset Avatar Seç
  // ══════════════════════════════════════
  Future<void> _showPresetAvatarPicker() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.55,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF12121F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pets_rounded,
                    color: const Color(0xFFFFD700).withOpacity(0.7), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Avatar Seç',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                  ),
                  itemCount: AvatarService.presetAvatars.length,
                  itemBuilder: (context, index) {
                    final avatar = AvatarService.presetAvatars[index];
                    return GestureDetector(
                      onTap: () => Navigator.pop(ctx, avatar),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(avatar, fit: BoxFit.cover),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() => _isUploading = true);
      try {
        final url = await AvatarService.uploadPresetAvatar(result);
        if (mounted) {
          setState(() {
            _profile?['photoUrl'] = url;
            _isUploading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Hata: $e', style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  // ══════════════════════════════════════
  //  Fotoğraf Seçim Menüsü
  // ══════════════════════════════════════
  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF12121F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Profil Fotoğrafı',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadPhoto();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF72246C), Color(0xFF9B30FF)],
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_library_rounded,
                        color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text('Galeriden Fotoğraf Seç',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                _showPresetAvatarPicker();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pets_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text('Avatar Seç',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  //  Şifre Değiştirme
  // ══════════════════════════════════════
  void _showChangePasswordSheet() {
    final emailController = TextEditingController();
    final oldPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool isLoading = false;

    String? emailError;
    String? oldPassError;
    String? newPassError;
    String? confirmPassError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          void clearErrors() {
            emailError = null;
            oldPassError = null;
            newPassError = null;
            confirmPassError = null;
          }

          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF12121F),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
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
                          child: const Icon(Icons.lock_rounded,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text('Şifre Değiştir',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _passField(
                        controller: emailController,
                        hint: 'Kayıtlı e-posta adresin',
                        icon: Icons.mail_outline_rounded,
                        isPassword: false,
                        errorText: emailError),
                    const SizedBox(height: 12),
                    _passField(
                        controller: oldPassController,
                        hint: 'Mevcut şifren',
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        errorText: oldPassError),
                    const SizedBox(height: 12),
                    _passField(
                        controller: newPassController,
                        hint: 'Yeni şifre',
                        icon: Icons.lock_reset_rounded,
                        isPassword: true,
                        errorText: newPassError),
                    const SizedBox(height: 12),
                    _passField(
                        controller: confirmPassController,
                        hint: 'Yeni şifre (tekrar)',
                        icon: Icons.lock_reset_rounded,
                        isPassword: true,
                        errorText: confirmPassError),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: isLoading
                          ? null
                          : () async {
                              final email = emailController.text.trim();
                              final oldPass = oldPassController.text.trim();
                              final newPass = newPassController.text.trim();
                              final confirmPass =
                                  confirmPassController.text.trim();

                              clearErrors();
                              bool hasError = false;

                              if (email.isEmpty) {
                                emailError = 'E-posta adresi boş bırakılamaz';
                                hasError = true;
                              }
                              if (oldPass.isEmpty) {
                                oldPassError = 'Mevcut şifre boş bırakılamaz';
                                hasError = true;
                              }
                              if (newPass.isEmpty) {
                                newPassError = 'Yeni şifre boş bırakılamaz';
                                hasError = true;
                              } else if (newPass.length < 6) {
                                newPassError = 'En az 6 karakter olmalı';
                                hasError = true;
                              } else if (newPass == oldPass) {
                                newPassError =
                                    'Yeni şifre eskisiyle aynı olamaz';
                                hasError = true;
                              }
                              if (confirmPass.isEmpty) {
                                confirmPassError =
                                    'Şifre tekrarı boş bırakılamaz';
                                hasError = true;
                              } else if (newPass != confirmPass) {
                                confirmPassError = 'Şifreler eşleşmiyor';
                                hasError = true;
                              }

                              if (hasError) {
                                setSheetState(() {});
                                return;
                              }

                              setSheetState(() => isLoading = true);

                              try {
                                final user = FirebaseAuth.instance.currentUser;
                                if (user == null) {
                                  setSheetState(() {
                                    emailError = 'Oturum bulunamadı';
                                    isLoading = false;
                                  });
                                  return;
                                }
                                if (user.email != email) {
                                  setSheetState(() {
                                    emailError = 'E-posta adresi hatalı';
                                    isLoading = false;
                                  });
                                  return;
                                }

                                final credential = EmailAuthProvider.credential(
                                    email: email, password: oldPass);
                                await user
                                    .reauthenticateWithCredential(credential);
                                await user.updatePassword(newPass);

                                if (mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                          'Şifren başarıyla değiştirildi ✅',
                                          style:
                                              TextStyle(color: Colors.white)),
                                      backgroundColor: const Color(0xFF4CAF50),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                  );
                                }
                              } on FirebaseAuthException catch (e) {
                                switch (e.code) {
                                  case 'wrong-password':
                                    oldPassError = 'Mevcut şifre yanlış';
                                    break;
                                  case 'too-many-requests':
                                    oldPassError =
                                        'Çok fazla deneme, biraz bekle';
                                    break;
                                  case 'weak-password':
                                    newPassError = 'Şifre çok zayıf';
                                    break;
                                  case 'invalid-credential':
                                    oldPassError = 'Şifre veya e-posta hatalı';
                                    break;
                                  default:
                                    oldPassError = 'Hata: ${e.message}';
                                }
                                setSheetState(() => isLoading = false);
                              } catch (e) {
                                setSheetState(() {
                                  oldPassError = 'Hata: $e';
                                  isLoading = false;
                                });
                              }
                            },
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: isLoading
                              ? null
                              : const LinearGradient(colors: [
                                  Color(0xFFFFD700),
                                  Color(0xFFFF8C00)
                                ]),
                          color:
                              isLoading ? Colors.white.withOpacity(0.06) : null,
                        ),
                        child: Center(
                          child: isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Color(0xFFFFD700)))
                              : const Text('Şifreyi Güncelle',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _passField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isPassword,
    String? errorText,
  }) {
    final hasError = errorText != null && errorText.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: hasError
                ? Colors.red.withOpacity(0.08)
                : Colors.white.withOpacity(0.06),
            border: Border.all(
              color: hasError
                  ? Colors.red.shade400
                  : Colors.white.withOpacity(0.06),
              width: hasError ? 1.5 : 1,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: hasError
                    ? Colors.red.shade300.withOpacity(0.5)
                    : Colors.white.withOpacity(0.2),
                fontSize: 15,
              ),
              prefixIcon: Icon(icon,
                  color: hasError ? Colors.red.shade400 : Colors.white24,
                  size: 20),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded,
                    color: Colors.red.shade400, size: 14),
                const SizedBox(width: 6),
                Text(
                  errorText!,
                  style: TextStyle(
                      color: Colors.red.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ══════════════════════════════════════
  //  Hesap Silme Onay
  // ══════════════════════════════════════
  void _showDeleteAccountConfirm() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF12121F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.shade700.withOpacity(0.15),
                border: Border.all(
                    color: Colors.red.shade700.withOpacity(0.3), width: 2),
              ),
              child: Icon(Icons.warning_rounded,
                  color: Colors.red.shade400, size: 30),
            ),
            const SizedBox(height: 16),
            const Text('Hesabı Sil',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(
              'Hesabın, tüm gönderilerin, arkadaşlıkların\nve verilerin kalıcı olarak silinecek.\n\nBu işlem geri alınamaz!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 14,
                  height: 1.5),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.white.withOpacity(0.06),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: const Center(
                        child: Text('Vazgeç',
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _deleteAccount();
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                            colors: [Colors.red.shade700, Colors.red.shade900]),
                      ),
                      child: const Center(
                        child: Text('Evet, Sil',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    setState(() => _isDeletingAccount = true);
    try {
      await AuthService.deleteAccount();
    } catch (e) {
      if (mounted) {
        setState(() => _isDeletingAccount = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hesap silinemedi: $e',
                style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // ══════════════════════════════════════
  //  Yardımcı Getter'lar
  // ══════════════════════════════════════
  String _getValue(String key) {
    if (_profile == null) return 'Belirtilmemiş';
    final val = _profile![key];
    if (val == null) return 'Belirtilmemiş';
    if (val is String && val.isEmpty) return 'Belirtilmemiş';
    if (val is int && val == 0) return 'Belirtilmemiş';
    return val.toString();
  }

  String get _displayName {
    final fullName = _getValue('fullName');
    if (fullName != 'Belirtilmemiş') return fullName;
    return _getValue('username');
  }

  String get _username {
    if (_profile == null) return '@anonim';
    final u = _profile!['username'];
    if (u == null || (u is String && u.isEmpty)) return '@anonim';
    return '@$u';
  }

  String get _initial {
    final name = _displayName;
    if (name.isEmpty || name == 'Belirtilmemiş') return '?';
    return name[0].toUpperCase();
  }

  // ══════════════════════════════════════
  //  Düzenleme Dialogları
  // ══════════════════════════════════════
  Future<void> _editFullName() async {
    final controller = TextEditingController(
      text:
          _getValue('fullName') == 'Belirtilmemiş' ? '' : _getValue('fullName'),
    );

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditSheet(
        title: 'İsim Soyisim',
        child: _EditInput(
          controller: controller,
          hint: 'Adın Soyadın',
          icon: Icons.person_outline_rounded,
          maxLength: 15,
          keyboardType: TextInputType.name,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
                RegExp(r'[a-zA-ZçÇğĞıİöÖşŞüÜ\s]')),
          ],
        ),
        onSave: () {
          final val = controller.text.trim();
          if (val.isNotEmpty && val.length < 2) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: const Text('En az 2 karakter olmalı',
                    style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
            return;
          }
          Navigator.pop(ctx, val);
        },
      ),
    );

    if (result != null && mounted) {
      await AuthService.updateField('fullName', result);
      _loadProfile();
    }
  }

  Future<void> _editAge() async {
    final controller = TextEditingController(
      text: _getValue('age') == 'Belirtilmemiş' ? '' : _getValue('age'),
    );

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditSheet(
        title: 'Yaş',
        child: _EditInput(
          controller: controller,
          hint: 'Yaşın',
          icon: Icons.cake_outlined,
          maxLength: 3,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        onSave: () {
          final val = controller.text.trim();
          if (val.isNotEmpty) {
            final age = int.tryParse(val);
            if (age == null || age < 13 || age > 120) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: const Text('Geçerli bir yaş gir (13-120)',
                      style: TextStyle(color: Colors.white)),
                  backgroundColor: Colors.red.shade700,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
              return;
            }
          }
          Navigator.pop(ctx, val);
        },
      ),
    );

    if (result != null && mounted) {
      final age = int.tryParse(result) ?? 0;
      await AuthService.updateField('age', age);
      _loadProfile();
    }
  }

  Future<void> _editCity() async {
    final cities = [
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

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
        decoration: const BoxDecoration(
          color: Color(0xFF12121F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const Text('Şehir Seç',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: cities.length,
                itemBuilder: (_, i) {
                  final isSelected = _getValue('city') == cities[i];
                  return ListTile(
                    title: Text(cities[i],
                        style: TextStyle(
                            color: isSelected
                                ? const Color(0xFFFFD700)
                                : Colors.white70,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 15)),
                    trailing: isSelected
                        ? const Icon(Icons.check_rounded,
                            color: Color(0xFFFFD700), size: 20)
                        : null,
                    onTap: () => Navigator.pop(ctx, cities[i]),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      await AuthService.updateField('city', result);
      _loadProfile();
    }
  }

  Future<void> _editGender() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF12121F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Cinsiyet Seç',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _GenderPickCard(
                    label: 'Erkek',
                    icon: Icons.male_rounded,
                    isSelected: _getValue('gender') == 'Erkek',
                    color: const Color(0xFF1E88E5),
                    onTap: () => Navigator.pop(ctx, 'Erkek'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _GenderPickCard(
                    label: 'Kadın',
                    icon: Icons.female_rounded,
                    isSelected: _getValue('gender') == 'Kadın',
                    color: const Color(0xFFE91E63),
                    onTap: () => Navigator.pop(ctx, 'Kadın'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      await AuthService.updateField('gender', result);
      _loadProfile();
    }
  }

  // ══════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_isLoading || _isDeletingAccount) {
      return SizedBox.expand(
        child: ColoredBox(
          color: const Color(0xFF0A0A0F),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Color(0xFFFFD700)),
                ),
                if (_isDeletingAccount) ...[
                  const SizedBox(height: 16),
                  Text('Hesap siliniyor...',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4), fontSize: 14)),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final photoUrl = _profile?['photoUrl'] as String?;

    return SizedBox.expand(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0F1A), Color(0xFF0A0A0F), Color(0xFF0A0A0F)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 100),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // ── Header ──
                  Row(
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
                        child: const Icon(Icons.person_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Text('Profil',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => Container(
                              padding: const EdgeInsets.all(24),
                              decoration: const BoxDecoration(
                                color: Color(0xFF12121F),
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(24)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFFF8C00)
                                          .withOpacity(0.15),
                                      border: Border.all(
                                          color: const Color(0xFFFF8C00)
                                              .withOpacity(0.3),
                                          width: 2),
                                    ),
                                    child: const Icon(Icons.logout_rounded,
                                        color: Color(0xFFFF8C00), size: 28),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text('Çıkış Yap',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Hesabından çıkış yapmak istediğine\nemin misin?',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.4),
                                        fontSize: 14,
                                        height: 1.5),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => Navigator.pop(ctx),
                                          child: Container(
                                            height: 48,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              color: Colors.white
                                                  .withOpacity(0.06),
                                              border: Border.all(
                                                  color: Colors.white
                                                      .withOpacity(0.08)),
                                            ),
                                            child: const Center(
                                              child: Text('Vazgeç',
                                                  style: TextStyle(
                                                      color: Colors.white54,
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () async {
                                            Navigator.pop(ctx);
                                            await AuthService.logout();
                                          },
                                          child: Container(
                                            height: 48,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFFFFD700),
                                                  Color(0xFFFF8C00)
                                                ],
                                              ),
                                            ),
                                            child: const Center(
                                              child: Text('Çıkış Yap',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w800)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.08)),
                          ),
                          child: const Icon(Icons.logout_rounded,
                              color: Colors.white38, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── Ayırıcı ──
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(vertical: 12),
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
                  const SizedBox(height: 12),

                  // ── Avatar ──
                  GestureDetector(
                    onTap: _isUploading ? null : _showPhotoOptions,
                    child: Stack(
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF72246C), Color(0xFF9B30FF)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF9B30FF).withOpacity(0.4),
                                blurRadius: 24,
                                spreadRadius: 2,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: photoUrl != null && photoUrl.isNotEmpty
                                ? Image.network(photoUrl,
                                    fit: BoxFit.cover,
                                    width: 110,
                                    height: 110,
                                    errorBuilder: (_, __, ___) => Center(
                                        child: Text(_initial,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 42,
                                                fontWeight: FontWeight.w900))))
                                : Center(
                                    child: Text(_initial,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 42,
                                            fontWeight: FontWeight.w900))),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(colors: [
                                Color(0xFFFFD700),
                                Color(0xFFFF8C00)
                              ]),
                              border: Border.all(
                                  color: const Color(0xFF0A0A0F), width: 3),
                              boxShadow: [
                                BoxShadow(
                                    color: const Color(0xFFFFD700)
                                        .withOpacity(0.35),
                                    blurRadius: 8),
                              ],
                            ),
                            child: _isUploading
                                ? const Padding(
                                    padding: EdgeInsets.all(7),
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.camera_alt_rounded,
                                    color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── İsim ──
                  Text(_displayName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 4),

                  // ── Username ──
                  Text(_username,
                      style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 20),

                  // ── Stat Kartları ──
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const MyPostsScreen()));
                          },
                          child: _statCard(
                              icon: Icons.article_rounded,
                              label: 'Gönderilerim',
                              value: '$_postCount',
                              color: const Color(0xFF9B30FF)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const FriendsScreen()));
                          },
                          child: _statCard(
                              icon: Icons.people_rounded,
                              label: 'Arkadaşlarım',
                              value: '$_friendCount',
                              color: const Color(0xFF1E88E5)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Karizma Kartı ──
                  _buildKarizmaCard(),
                  const SizedBox(height: 24),

                  // ── Bilgiler ──
                  _buildSectionTitle('Bilgiler'),
                  const SizedBox(height: 12),

                  _buildInfoCard(
                      icon: Icons.mail_outline_rounded,
                      label: 'Email',
                      value: _getValue('email'),
                      valueColor: Colors.white,
                      editable: false),
                  const SizedBox(height: 10),
                  _buildInfoCard(
                      icon: Icons.person_outline_rounded,
                      label: 'İsim Soyisim',
                      value: _getValue('fullName'),
                      editable: true,
                      onEdit: _editFullName),
                  const SizedBox(height: 10),
                  _buildInfoCard(
                      icon: Icons.cake_outlined,
                      label: 'Yaş',
                      value: _getValue('age'),
                      editable: true,
                      onEdit: _editAge),
                  const SizedBox(height: 10),
                  _buildInfoCard(
                      icon: Icons.location_city_rounded,
                      label: 'Şehir',
                      value: _getValue('city'),
                      editable: true,
                      onEdit: _editCity),
                  const SizedBox(height: 10),
                  _buildInfoCard(
                      icon: Icons.wc_rounded,
                      label: 'Cinsiyet',
                      value: _getValue('gender'),
                      editable: true,
                      onEdit: _editGender),

                  // ══════════════════════════════════════
                  //  Şifre Değiştir + Hesap Sil (YAN YANA)
                  // ══════════════════════════════════════
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      // Şifremi Değiştir
                      Expanded(
                        child: GestureDetector(
                          onTap: _showChangePasswordSheet,
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFFFFD700).withOpacity(0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock_reset_rounded,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 6),
                                Text('Şifre Değiştir',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Hesabımı Sil
                      Expanded(
                        child: GestureDetector(
                          onTap: _showDeleteAccountConfirm,
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.red.withOpacity(0.08),
                              border: Border.all(
                                  color: Colors.red.withOpacity(0.15)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.delete_forever_rounded,
                                    color: Colors.red.shade400, size: 18),
                                const SizedBox(width: 6),
                                Text('Hesabımı Sil',
                                    style: TextStyle(
                                        color: Colors.red.shade400,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  //  Stat Card
  // ══════════════════════════════════════
  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.12), color.withOpacity(0.04)],
        ),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: color.withOpacity(0.15),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
                Text(label,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              color: Colors.white.withOpacity(0.15), size: 14),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  Karizma Kartı
  // ══════════════════════════════════════
  Widget _buildKarizmaCard() {
    final level = KarizmaService.getLevel(_karizma);
    final nextTarget = KarizmaService.getNextLevelTarget(_karizma);
    final progress = KarizmaService.getProgress(_karizma);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1035), Color(0xFF0F0A1F)],
            ),
            border: Border.all(
                color: const Color(0xFFFFD700).withOpacity(0.15), width: 1),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF1E88E5),
                          Color(0xFF9B30FF),
                          Color(0xFFFF8C00)
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFF9B30FF).withOpacity(0.4),
                            blurRadius: 12),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.local_fire_department_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('Karizma Puanı',
                      style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3)),
                ],
              ),
              const SizedBox(height: 16),
              Text(KarizmaService.format(_karizma),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1)),
              const SizedBox(height: 6),
              Text(
                _karizma == 0
                    ? 'Henüz başlangıç — overheard paylaşarak kazan!'
                    : 'Harika gidiyorsun! Paylaşmaya devam 🔥',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: Colors.white.withOpacity(0.06),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: const LinearGradient(colors: [
                        Color(0xFF1E88E5),
                        Color(0xFF9B30FF),
                        Color(0xFFFF8C00)
                      ]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Seviye: $level',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  Text(_karizma >= 5000 ? 'MAX!' : 'Sonraki: $nextTarget puan',
                      style: TextStyle(
                          color: const Color(0xFFFFD700).withOpacity(0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  //  Section Title
  // ══════════════════════════════════════
  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3)),
      ],
    );
  }

  // ══════════════════════════════════════
  //  Info Card
  // ══════════════════════════════════════
  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool editable = false,
    VoidCallback? onEdit,
  }) {
    return GestureDetector(
      onTap: editable ? onEdit : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.06),
              Colors.white.withOpacity(0.02)
            ],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white.withOpacity(0.06),
              ),
              child: Icon(icon, color: Colors.white38, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: TextStyle(
                          color: valueColor ?? Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (editable)
              Icon(Icons.edit_rounded,
                  color: Colors.white.withOpacity(0.15), size: 16),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════
//  Edit Sheet
// ══════════════════════════════════════
class _EditSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback onSave;

  const _EditSheet(
      {required this.title, required this.child, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF12121F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            child,
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onSave,
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                ),
                child: const Center(
                  child: Text('Kaydet',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════
//  Edit Input
// ══════════════════════════════════════
class _EditInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _EditInput({
    required this.controller,
    required this.hint,
    required this.icon,
    this.maxLength,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        autofocus: true,
        style: const TextStyle(
            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 15),
          prefixIcon: Icon(icon, color: Colors.white24, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          counterText: '',
        ),
      ),
    );
  }
}

// ══════════════════════════════════════
//  Gender Pick Card
// ══════════════════════════════════════
class _GenderPickCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _GenderPickCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isSelected
              ? LinearGradient(colors: [color, color.withOpacity(0.7)])
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.06),
          border: Border.all(
            color: isSelected
                ? color.withOpacity(0.5)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 36, color: isSelected ? Colors.white : Colors.white30),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white54,
                    fontSize: 15,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
