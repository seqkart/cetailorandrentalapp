import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/biometric_authenticator.dart';
import 'core/app_locale_controller.dart';
import 'core/session_store.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/pin_screen.dart';
import 'features/dashboard/dashboard_repository.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/dashboard/administration_repository.dart';
import 'features/rentals/rental_repository.dart';
import 'features/reports/reports_repository.dart';
import 'features/tailoring/tailoring_repository.dart';
import 'splash/animated_splash.dart';
import 'widgets/stitch_loader.dart';
import 'l10n/generated/app_localizations.dart';

class TailorRentalsApp extends StatefulWidget {
  const TailorRentalsApp({
    required this.authRepository,
    required this.dashboardRepository,
    required this.rentalRepository,
    required this.reportsRepository,
    required this.tailoringRepository,
    required this.administrationRepository,
    required this.sessionStore,
    this.biometricAuthenticator,
    super.key,
  });

  final AuthRepository authRepository;
  final DashboardRepository dashboardRepository;
  final RentalRepository rentalRepository;
  final ReportsRepository reportsRepository;
  final TailoringRepository tailoringRepository;
  final AdministrationRepository administrationRepository;
  final SessionStore sessionStore;
  final BiometricAuthenticator? biometricAuthenticator;

  @override
  State<TailorRentalsApp> createState() => _TailorRentalsAppState();
}

class _TailorRentalsAppState extends State<TailorRentalsApp> {
  late final AppLocaleController _localeController = AppLocaleController(
    widget.sessionStore,
  );

  @override
  void initState() {
    super.initState();
    _localeController.load().catchError((Object error) {
      debugPrint('Could not restore app language preference: $error');
    });
  }

  @override
  void dispose() {
    _localeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _localeController,
      builder: (context, _) => MaterialApp(
        title: 'Creative Ease Tailoring & Rentals',
        debugShowCheckedModeBanner: false,
        locale: _localeController.value,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        theme: ThemeData(
          textTheme: _slightlyLargerTextTheme(),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1688E8),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF3F8FE),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF3F8FE),
            foregroundColor: Color(0xFF142C4B),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
            titleTextStyle: TextStyle(
              color: Color(0xFF142C4B),
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          cardTheme: CardThemeData(
            color: const Color(0xECFFFFFF),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFFDCEAF8)),
            ),
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: const Color(0xFFF9FCFF),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: Color(0xFFDCEAF8)),
            ),
          ),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: Color(0xFFF8FBFF),
            surfaceTintColor: Colors.transparent,
            showDragHandle: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF1688E8),
            foregroundColor: Colors.white,
            elevation: 6,
            shape: CircleBorder(),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1688E8),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1679CF),
              side: const BorderSide(color: Color(0xFFB8D9F6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          tabBarTheme: TabBarThemeData(
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: const Color(0xFFE1F1FF),
              borderRadius: BorderRadius.circular(14),
            ),
            labelColor: const Color(0xFF087DD3),
            unselectedLabelColor: const Color(0xFF77879A),
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          useMaterial3: true,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFF7FAFE),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Color(0xFFDDE9F6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Color(0xFFDDE9F6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(
                color: Color(0xFF1688E8),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Color(0xFFD75264)),
            ),
          ),
        ),
        home: _SessionGate(
          authRepository: widget.authRepository,
          dashboardRepository: widget.dashboardRepository,
          rentalRepository: widget.rentalRepository,
          reportsRepository: widget.reportsRepository,
          tailoringRepository: widget.tailoringRepository,
          administrationRepository: widget.administrationRepository,
          sessionStore: widget.sessionStore,
          localeController: _localeController,
          onLocaleChanged: _localeController.setLocale,
          biometricAuthenticator:
              widget.biometricAuthenticator ?? DeviceBiometricAuthenticator(),
        ),
      ),
    );
  }
}

TextTheme _slightlyLargerTextTheme() {
  final base = Typography.material2021().black;
  TextStyle? larger(TextStyle? style) =>
      style?.copyWith(fontSize: (style.fontSize ?? 14) + 1);
  return base.copyWith(
    displayLarge: larger(base.displayLarge),
    displayMedium: larger(base.displayMedium),
    displaySmall: larger(base.displaySmall),
    headlineLarge: larger(base.headlineLarge),
    headlineMedium: larger(base.headlineMedium),
    headlineSmall: larger(base.headlineSmall),
    titleLarge: larger(base.titleLarge),
    titleMedium: larger(base.titleMedium),
    titleSmall: larger(base.titleSmall),
    bodyLarge: larger(base.bodyLarge),
    bodyMedium: larger(base.bodyMedium),
    bodySmall: larger(base.bodySmall),
    labelLarge: larger(base.labelLarge),
    labelMedium: larger(base.labelMedium),
    labelSmall: larger(base.labelSmall),
  );
}

class _SessionGate extends StatefulWidget {
  const _SessionGate({
    required this.authRepository,
    required this.dashboardRepository,
    required this.rentalRepository,
    required this.reportsRepository,
    required this.tailoringRepository,
    required this.administrationRepository,
    required this.sessionStore,
    required this.localeController,
    required this.onLocaleChanged,
    required this.biometricAuthenticator,
  });

  final AuthRepository authRepository;
  final DashboardRepository dashboardRepository;
  final RentalRepository rentalRepository;
  final ReportsRepository reportsRepository;
  final TailoringRepository tailoringRepository;
  final AdministrationRepository administrationRepository;
  final SessionStore sessionStore;
  final AppLocaleController localeController;
  final Future<void> Function(Locale) onLocaleChanged;
  final BiometricAuthenticator biometricAuthenticator;

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate>
    with WidgetsBindingObserver {
  late Future<_SessionAccess?> _accessFuture;
  _SessionAccess? _access;
  bool _unlocked = false;
  bool _splashComplete = false;
  bool _isInBackground = false;
  Timer? _backgroundLockTimer;
  DateTime? _backgroundedAt;

  Future<_SessionAccess?> _loadAccess() => _readAccess().timeout(
    const Duration(seconds: 15),
    onTimeout: () => throw TimeoutException(
      'Secure sign-in storage is taking too long to respond. Retry or restart the app.',
    ),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _accessFuture = _loadAccess();
  }

  @override
  void dispose() {
    _backgroundLockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final wasAwayLongEnough =
          _backgroundedAt != null &&
          DateTime.now().difference(_backgroundedAt!) >=
              const Duration(minutes: 1);
      _isInBackground = false;
      _backgroundedAt = null;
      _backgroundLockTimer?.cancel();
      _backgroundLockTimer = null;
      if (wasAwayLongEnough && _access != null && _unlocked) {
        setState(() => _unlocked = false);
      }
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _isInBackground = true;
      _backgroundedAt ??= DateTime.now();
      _backgroundLockTimer?.cancel();
      _backgroundLockTimer = Timer(const Duration(minutes: 1), () {
        if (mounted && _isInBackground && _access != null && _unlocked) {
          setState(() => _unlocked = false);
        }
      });
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
    if (!session.hasSupportedRole) {
      await widget.sessionStore.clear();
      widget.authRepository.clearToken();
      return null;
    }
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
    if (!_splashComplete) {
      return AnimatedSplash(
        onFinished: () {
          if (mounted) setState(() => _splashComplete = true);
        },
      );
    }
    return FutureBuilder<_SessionAccess?>(
      future: _accessFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _SessionRestoreError(
            message: snapshot.error.toString(),
            onRetry: () {
              setState(() {
                _accessFuture = _loadAccess();
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
            locale: widget.localeController.value,
            onLocaleChanged: widget.onLocaleChanged,
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
          rentalRepository: widget.rentalRepository,
          reportsRepository: widget.reportsRepository,
          tailoringRepository: widget.tailoringRepository,
          administrationRepository: widget.administrationRepository,
          locale: widget.localeController.value,
          onLocaleChanged: widget.onLocaleChanged,
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
  Widget build(BuildContext context) =>
      const LoadingScreen(message: 'Preparing your workspace');
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
