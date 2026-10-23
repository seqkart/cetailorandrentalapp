import 'package:ce_tailor_rentals/app.dart';
import 'package:ce_tailor_rentals/core/api_client.dart';
import 'package:ce_tailor_rentals/core/session_store.dart';
import 'package:ce_tailor_rentals/features/auth/auth_repository.dart';
import 'package:ce_tailor_rentals/features/auth/login_screen.dart';
import 'package:ce_tailor_rentals/features/dashboard/dashboard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sign-in screen presents the backend login fields', (
    WidgetTester tester,
  ) async {
    final repository = AuthRepository(
      ApiClient(),
      const SessionStore(FlutterSecureStorage()),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(repository: repository, onSignedIn: (_) {}),
      ),
    );

    expect(find.text('Made to fit.\nReady to wear.'), findsOneWidget);
    expect(find.text('App ID'), findsOneWidget);
    expect(find.text('Financial year'), findsOneWidget);
    expect(find.text('User name'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('SIGN IN'), findsOneWidget);
  });

  testWidgets('app opens sign in after restoring an empty session', (
    WidgetTester tester,
  ) async {
    final sessionStore = _EmptySessionStore();
    final api = ApiClient();

    await tester.pumpWidget(
      TailorRentalsApp(
        authRepository: AuthRepository(api, sessionStore),
        dashboardRepository: DashboardRepository(api),
        sessionStore: sessionStore,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Team sign in'), findsOneWidget);
    expect(find.text('App ID'), findsOneWidget);
  });
}

class _EmptySessionStore extends SessionStore {
  _EmptySessionStore() : super(const FlutterSecureStorage());

  @override
  Future<AuthSession?> read() async => null;

  @override
  Future<void> clear() async {}

  @override
  Future<void> write(AuthSession session) async {}
}
