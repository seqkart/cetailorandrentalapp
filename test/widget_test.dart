import 'package:ce_tailor_rentals/app.dart';
import 'package:ce_tailor_rentals/core/biometric_authenticator.dart';
import 'package:ce_tailor_rentals/core/api_client.dart';
import 'package:ce_tailor_rentals/core/session_store.dart';
import 'package:ce_tailor_rentals/features/auth/auth_repository.dart';
import 'package:ce_tailor_rentals/features/auth/login_screen.dart';
import 'package:ce_tailor_rentals/features/auth/pin_screen.dart';
import 'package:ce_tailor_rentals/features/dashboard/dashboard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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
        biometricAuthenticator: _UnavailableBiometrics(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Team sign in'), findsOneWidget);
    expect(find.text('App ID'), findsOneWidget);
  });

  testWidgets('sign-in transitions to dashboard without setState errors', (
    WidgetTester tester,
  ) async {
    final sessionStore = _EmptySessionStore();
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient((request) async {
        final response = switch (request.url.path) {
          '/api/v1/Master/GetFinancialYearsByAppIdAsync' => '{"errorCode":0,"data":[{"finYearID":7,"finYearName":"2026-27","isCurrent":true}]}',
          '/api/v1/Account/login' => '{"errorCode":0,"token":"test-token","userID":1,"userName":"Taylor","companyName":"Studio"}',
          '/api/v1/Transaction/GetDashboardSummaryAsync' =>
            '{"errorCode":0,"data":{}}',
          '/api/v1/transaction/GetDashboardDetails' =>
            '{"errorCode":0,"data":{}}',
          '/api/v1/transaction/GetOrderAndRentalStatusCounts' =>
            '{"errorCode":0,"data":{}}',
          '/api/v1/Transaction/GetRecentPaymentsAsync' =>
            '{"errorCode":0,"data":[]}',
          _ => '{"errorCode":0,"data":[]}',
        };
        return http.Response(response, 200);
      }),
    );

    await tester.pumpWidget(
      TailorRentalsApp(
        authRepository: AuthRepository(api, sessionStore),
        dashboardRepository: DashboardRepository(api),
        sessionStore: sessionStore,
        biometricAuthenticator: _UnavailableBiometrics(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'app-123');
    await tester.tap(find.text('Load financial years'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), 'Taylor');
    await tester.enterText(find.byType(TextFormField).at(2), 'password');
    await tester.ensureVisible(find.text('SIGN IN'));
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();

    expect(find.text('Protect your account'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('mpin-field')), '1234');
    await tester.enterText(find.byKey(const Key('confirm-mpin-field')), '1234');
    await tester.tap(find.text('SAVE MPIN'));
    await tester.pumpAndSettle();

    expect(find.text('Tailoring & Rentals'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(sessionStore.savedPin, '1234');

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Team sign in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved session requires correct MPIN before opening dashboard', (
    WidgetTester tester,
  ) async {
    final sessionStore = _EmptySessionStore()
      ..savedSession = const AuthSession(
        token: 'test-token',
        appId: 'app-123',
        financialYearId: 7,
        financialYearName: '2026-27',
        companyName: 'Studio',
        userName: 'Taylor',
      )
      ..savedPin = '4321';
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient(
        (_) async => http.Response('{"errorCode":0,"data":{}}', 200),
      ),
    );

    await tester.pumpWidget(
      TailorRentalsApp(
        authRepository: AuthRepository(api, sessionStore),
        dashboardRepository: DashboardRepository(api),
        sessionStore: sessionStore,
        biometricAuthenticator: _UnavailableBiometrics(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('mpin-field')), '1111');
    await tester.tap(find.text('UNLOCK'));
    await tester.pumpAndSettle();
    expect(find.text('That MPIN is not correct. Try again.'), findsOneWidget);
    expect(find.text('Tailoring & Rentals'), findsNothing);

    await tester.enterText(find.byKey(const Key('mpin-field')), '4321');
    await tester.tap(find.text('UNLOCK'));
    await tester.pumpAndSettle();
    expect(find.text('Tailoring & Rentals'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MPIN setup allows enabling biometric unlock', (
    WidgetTester tester,
  ) async {
    ({String pin, bool useBiometrics})? savedSettings;
    await tester.pumpWidget(
      MaterialApp(
        home: PinScreen(
          isSetup: true,
          useBiometrics: false,
          onSetupComplete: (settings) async => savedSettings = settings,
          onPinAccepted: () {},
          biometricAuthenticator: _AvailableBiometrics(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Enable fingerprint unlock'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.enterText(find.byKey(const Key('mpin-field')), '2468');
    await tester.enterText(find.byKey(const Key('confirm-mpin-field')), '2468');
    await tester.tap(find.text('SAVE MPIN'));
    await tester.pumpAndSettle();

    expect(savedSettings?.pin, '2468');
    expect(savedSettings?.useBiometrics, isTrue);
  });

  testWidgets('forgot MPIN can clear the session and return to sign in', (
    WidgetTester tester,
  ) async {
    var signedInAgain = false;
    await tester.pumpWidget(
      MaterialApp(
        home: PinScreen(
          isSetup: false,
          useBiometrics: false,
          savedPin: '1357',
          onSetupComplete: (_) async {},
          onPinAccepted: () {},
          onForgotPin: () async => signedInAgain = true,
          biometricAuthenticator: _UnavailableBiometrics(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot MPIN? Sign in again'));
    await tester.pumpAndSettle();

    expect(signedInAgain, isTrue);
    expect(tester.takeException(), isNull);
  });
}

class _EmptySessionStore extends SessionStore {
  _EmptySessionStore() : super(const FlutterSecureStorage());

  @override
  Future<AuthSession?> read() async => savedSession;

  @override
  Future<String?> readPin() async => savedPin;

  @override
  Future<bool> readBiometricPreference() async => useBiometrics;

  @override
  Future<void> clear() async {
    savedSession = null;
    savedPin = null;
    useBiometrics = false;
  }

  @override
  Future<void> write(AuthSession session) async {
    savedSession = session;
  }

  @override
  Future<void> saveUnlockSettings({
    required String pin,
    required bool useBiometrics,
  }) async {
    savedPin = pin;
    this.useBiometrics = useBiometrics;
  }

  AuthSession? savedSession;
  String? savedPin;
  bool useBiometrics = false;
}

class _UnavailableBiometrics implements BiometricAuthenticator {
  @override
  Future<bool> get canAuthenticate async => false;

  @override
  Future<bool> authenticate() async => false;
}

class _AvailableBiometrics implements BiometricAuthenticator {
  @override
  Future<bool> get canAuthenticate async => true;

  @override
  Future<bool> authenticate() async => true;
}
