import 'package:flutter/material.dart';

import 'core/biometric_authenticator.dart';
import 'core/session_store.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/pin_screen.dart';
import 'features/dashboard/dashboard_repository.dart';
import 'features/dashboard/dashboard_screen.dart';

class TailorRentalsApp extends StatelessWidget {
  const TailorRentalsApp({
    required this.authRepository,
    required this.dashboardRepository,
    required this.sessionStore,
    this.biometricAuthenticator,
    super.key,
  });

  final AuthRepository authRepository;
  final DashboardRepository dashboardRepository;
  final SessionStore sessionStore;
  final BiometricAuthenticator? biometricAuthenticator;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Creative Ease Tailoring & Rentals',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3157A4),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE0E5EF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE0E5EF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF3157A4), width: 1.5),
          ),
        ),
      ),
      home: _SessionGate(
        authRepository: authRepository,
        dashboardRepository: dashboardRepository,
        sessionStore: sessionStore,
        biometricAuthenticator:
            biometricAuthenticator ?? DeviceBiometricAuthenticator(),
      ),
    );
  }
}

class _SessionGate extends StatefulWidget {
  const _SessionGate({
    required this.authRepository,
    required this.dashboardRepository,
    required this.sessionStore,
    required this.biometricAuthenticator,
  });

  final AuthRepository authRepository;
  final DashboardRepository dashboardRepository;
  final SessionStore sessionStore;
  final BiometricAuthenticator biometricAuthenticator;

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate>
    with WidgetsBindingObserver {
  late Future<_SessionAccess?> _accessFuture;
  _SessionAccess? _access;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _accessFuture = _readAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) &&
        _access != null &&
        _unlocked) {
      setState(() => _unlocked = false);
    }
  }

  void _setSession(AuthSession session) {
    setState(() {
      _access = _SessionAccess(session: session);
      _accessFuture = Future.value(_access);
      _unlocked = false;
    });
  }

  Future<_SessionAccess?> _readAccess() async {
    final session = await widget.sessionStore.read();
    if (session == null) return null;
    final pin = await widget.sessionStore.readPin();
    final useBiometrics = await widget.sessionStore.readBiometricPreference();
    return _SessionAccess(
      session: session,
      pin: pin,
      useBiometrics: useBiometrics,
    );
  }

  Future<void> _savePin(({String pin, bool useBiometrics}) settings) async {
    await widget.sessionStore.saveUnlockSettings(
      pin: settings.pin,
      useBiometrics: settings.useBiometrics,
    );
    if (!mounted || _access == null) return;
    final access = _SessionAccess(
      session: _access!.session,
      pin: settings.pin,
      useBiometrics: settings.useBiometrics,
    );
    setState(() {
      _access = access;
      _accessFuture = Future.value(access);
      _unlocked = true;
    });
  }

  void _unlock() {
    if (mounted) setState(() => _unlocked = true);
  }

  Future<void> _signOut() async {
    await widget.sessionStore.clear();
    widget.authRepository.clearToken();
    if (mounted) {
      setState(() {
        _access = null;
        _accessFuture = Future.value(null);
        _unlocked = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SessionAccess?>(
      future: _accessFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _SessionRestoreError(
            message: snapshot.error.toString(),
            onRetry: () {
              setState(() {
                _accessFuture = _readAccess();
              });
            },
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const _AppLoadingScreen();
        }
        final access = snapshot.data;
        if (access == null) {
          return LoginScreen(
            repository: widget.authRepository,
            onSignedIn: _setSession,
          );
        }
        _access = access;
        if (access.pin == null) {
          return PinScreen(
            isSetup: true,
            useBiometrics: access.useBiometrics,
            onSetupComplete: _savePin,
            onPinAccepted: _unlock,
            biometricAuthenticator: widget.biometricAuthenticator,
            onForgotPin: _signOut,
            userName: access.session.userName,
          );
        }
        if (!_unlocked) {
          return PinScreen(
            isSetup: false,
            useBiometrics: access.useBiometrics,
            savedPin: access.pin,
            onSetupComplete: _savePin,
            onPinAccepted: _unlock,
            biometricAuthenticator: widget.biometricAuthenticator,
            userName: access.session.userName,
          );
        }
        return DashboardScreen(
          session: access.session,
          repository: widget.dashboardRepository,
          onSignOut: _signOut,
        );
      },
    );
  }
}

class _SessionAccess {
  const _SessionAccess({
    required this.session,
    this.pin,
    this.useBiometrics = false,
  });

  final AuthSession session;
  final String? pin;
  final bool useBiometrics;
}

class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _SessionRestoreError extends StatelessWidget {
  const _SessionRestoreError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 44),
              const SizedBox(height: 12),
              const Text(
                'Could not restore your sign-in',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      ),
    );
  }
}
