import 'package:flutter/material.dart';

import 'core/session_store.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_repository.dart';
import 'features/dashboard/dashboard_screen.dart';

class TailorRentalsApp extends StatelessWidget {
  const TailorRentalsApp({
    required this.authRepository,
    required this.dashboardRepository,
    required this.sessionStore,
    super.key,
  });

  final AuthRepository authRepository;
  final DashboardRepository dashboardRepository;
  final SessionStore sessionStore;

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
      ),
    );
  }
}

class _SessionGate extends StatefulWidget {
  const _SessionGate({
    required this.authRepository,
    required this.dashboardRepository,
    required this.sessionStore,
  });

  final AuthRepository authRepository;
  final DashboardRepository dashboardRepository;
  final SessionStore sessionStore;

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  late Future<AuthSession?> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = widget.sessionStore.read();
  }

  void _setSession(AuthSession session) {
    setState(() => _sessionFuture = Future.value(session));
  }

  Future<void> _signOut() async {
    await widget.sessionStore.clear();
    widget.authRepository.clearToken();
    if (mounted) setState(() => _sessionFuture = Future.value(null));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthSession?>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _SessionRestoreError(
            message: snapshot.error.toString(),
            onRetry: () {
              setState(() => _sessionFuture = widget.sessionStore.read());
            },
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const _AppLoadingScreen();
        }

        final session = snapshot.data;
        if (session == null) {
          return LoginScreen(
            repository: widget.authRepository,
            onSignedIn: _setSession,
          );
        }
        return DashboardScreen(
          session: session,
          repository: widget.dashboardRepository,
          onSignOut: _signOut,
        );
      },
    );
  }
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
