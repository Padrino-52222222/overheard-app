import 'package:HeardOver/screens/onboarding_ekrani.dart';
import 'package:HeardOver/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // EKLENDİ
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/permission_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ─ Immersive full screen başlatıcıda aktif ─
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky); // EKLENDİ
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const OverheardApp());
}

class OverheardApp extends StatelessWidget {
  const OverheardApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ─ Immersive full screen her build'de aktif ─
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky); // EKLENDİ
    return MaterialApp(
      title: 'HeardOver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD700),
          secondary: Color(0xFFFF8C00),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
      ),
      home: const _AuthGate(),
    );
  }
}

// ══════════════════════════════════════
//  Auth Gate — Giriş durumuna göre yönlendirme
// ══════════════════════════════════════
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky); // EKLENDİ
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        // Bekleniyor
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        // Giriş yapılmamış
        if (snapshot.data == null) {
          return const LoginScreen();
        }

        // Giriş yapılmış — onboarding kontrolü
        return const _OnboardingGate();
      },
    );
  }
}

// ══════════════════════════════════════
//  Onboarding Gate — Profil doldurulmuş mu?
// ══════════════════════════════════════
class _OnboardingGate extends StatefulWidget {
  const _OnboardingGate();

  @override
  State<_OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<_OnboardingGate> {
  bool _checking = true;
  bool _onboardingDone = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final done = await AuthService.isOnboardingCompleted();
    if (mounted) {
      setState(() {
        _onboardingDone = done;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky); // EKLENDİ
    if (_checking) return const _SplashScreen();

    if (!_onboardingDone) {
      return const OnboardingScreen();
    }

    return const _LocationGate();
  }
}

// ══════════════════════════════════════
//  Location Gate — Konum izni ve alımı
// ══════════════════════════════════════
class _LocationGate extends StatefulWidget {
  const _LocationGate();

  @override
  State<_LocationGate> createState() => _LocationGateState();
}

class _LocationGateState extends State<_LocationGate> {
  _AppState _state = _AppState.checking;
  Position? _position;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndLocation();
  }

  Future<void> _checkPermissionAndLocation() async {
    final status = await Permission.locationWhenInUse.status;
    if (status.isGranted) {
      await _fetchLocation();
    } else {
      setState(() => _state = _AppState.noPermission);
    }
  }

  Future<void> _fetchLocation() async {
    setState(() => _state = _AppState.checking);
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _position = pos;
        _state = _AppState.ready;
      });
    } catch (_) {
      // Fallback İstanbul/Kadıköy
      setState(() {
        _position = Position(
          latitude: 40.9909,
          longitude: 29.0297,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
        _state = _AppState.ready;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky); // EKLENDİ
    switch (_state) {
      case _AppState.checking:
        return const _SplashScreen();
      case _AppState.noPermission:
        return PermissionScreen(onPermissionGranted: _fetchLocation);
      case _AppState.ready:
        return HomeScreen(initialPosition: _position!);
    }
  }
}

enum _AppState { checking, noPermission, ready }

// ══════════════════════════════════════
//  Splash Screen
// ══════════════════════════════════════
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky); // EKLENDİ
    return const Scaffold(
      backgroundColor: Color(0xFF0A0A0F),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('👂', style: TextStyle(fontSize: 72)),
            SizedBox(height: 20),
            Text(
              'HeardOver',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFFFD700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}