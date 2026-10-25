import 'dart:async';

import 'package:ce_tailor_rentals/app.dart';
import 'package:ce_tailor_rentals/core/biometric_authenticator.dart';
import 'package:ce_tailor_rentals/core/api_client.dart';
import 'package:ce_tailor_rentals/core/session_store.dart';
import 'package:ce_tailor_rentals/features/auth/auth_repository.dart';
import 'package:ce_tailor_rentals/features/auth/login_screen.dart';
import 'package:ce_tailor_rentals/features/auth/pin_screen.dart';
import 'package:ce_tailor_rentals/features/dashboard/administration_repository.dart';
import 'package:ce_tailor_rentals/features/dashboard/dashboard_repository.dart';
import 'package:ce_tailor_rentals/features/dashboard/master_management_screen.dart';
import 'package:ce_tailor_rentals/features/dashboard/dashboard_screen.dart';
import 'package:ce_tailor_rentals/features/rentals/rental_repository.dart';
import 'package:ce_tailor_rentals/features/reports/reports_repository.dart';
import 'package:ce_tailor_rentals/features/tailoring/tailoring_repository.dart';
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

    final backgroundFinder = find.byKey(
      const ValueKey('login-animated-background'),
    );
    final initialGradient =
        (tester.widget<Container>(backgroundFinder).decoration!
                    as BoxDecoration)
                .gradient!
            as LinearGradient;
    expect(initialGradient.colors, hasLength(3));
    expect(initialGradient.colors.first.computeLuminance(), lessThan(0.1));
    await tester.pump(const Duration(seconds: 2));
    final animatedGradient =
        (tester.widget<Container>(backgroundFinder).decoration!
                    as BoxDecoration)
                .gradient!
            as LinearGradient;
    expect(animatedGradient.colors, isNot(initialGradient.colors));

    expect(
      tester
          .widgetList<EditableText>(find.byType(EditableText))
          .every((field) => field.selectAllOnFocus),
      isTrue,
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
        rentalRepository: RentalRepository(api),
        reportsRepository: ReportsRepository(api),
        tailoringRepository: TailoringRepository(api),
        administrationRepository: AdministrationRepository(api),
        sessionStore: sessionStore,
        biometricAuthenticator: _UnavailableBiometrics(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Team sign in'), findsOneWidget);
    expect(find.text('App ID'), findsOneWidget);
  });

  testWidgets('language picker switches to Hindi and persists selection', (
    WidgetTester tester,
  ) async {
    final sessionStore = _EmptySessionStore();
    final api = ApiClient();

    await tester.pumpWidget(
      TailorRentalsApp(
        authRepository: AuthRepository(api, sessionStore),
        dashboardRepository: DashboardRepository(api),
        rentalRepository: RentalRepository(api),
        reportsRepository: ReportsRepository(api),
        tailoringRepository: TailoringRepository(api),
        administrationRepository: AdministrationRepository(api),
        sessionStore: sessionStore,
        biometricAuthenticator: _UnavailableBiometrics(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Team sign in'), findsOneWidget);
    await tester.tap(find.byTooltip('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('हिन्दी'));
    await tester.pumpAndSettle();

    expect(find.text('टीम साइन इन'), findsOneWidget);
    expect(sessionStore.savedLocale, 'hi');
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy session without a role is cleared and requires sign in', (
    WidgetTester tester,
  ) async {
    final sessionStore = _EmptySessionStore()
      ..savedSession = AuthSession.fromJson({
        'token': 'legacy-token',
        'appId': 'app-123',
        'financialYearId': 7,
        'financialYearName': '2026-27',
        'companyName': 'Studio',
        'userName': 'Taylor',
      })
      ..savedPin = '4321';
    final api = ApiClient();

    await tester.pumpWidget(
      TailorRentalsApp(
        authRepository: AuthRepository(api, sessionStore),
        dashboardRepository: DashboardRepository(api),
        rentalRepository: RentalRepository(api),
        reportsRepository: ReportsRepository(api),
        tailoringRepository: TailoringRepository(api),
        administrationRepository: AdministrationRepository(api),
        sessionStore: sessionStore,
        biometricAuthenticator: _UnavailableBiometrics(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Team sign in'), findsOneWidget);
    expect(sessionStore.savedSession, isNull);
    expect(sessionStore.savedPin, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stalled secure storage ends with a retry prompt', (
    WidgetTester tester,
  ) async {
    final sessionStore = _HangingSessionStore();
    final api = ApiClient();

    await tester.pumpWidget(
      TailorRentalsApp(
        authRepository: AuthRepository(api, sessionStore),
        dashboardRepository: DashboardRepository(api),
        rentalRepository: RentalRepository(api),
        reportsRepository: ReportsRepository(api),
        tailoringRepository: TailoringRepository(api),
        administrationRepository: AdministrationRepository(api),
        sessionStore: sessionStore,
        biometricAuthenticator: _UnavailableBiometrics(),
      ),
    );
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 10));

    expect(find.text('Could not restore your sign-in'), findsOneWidget);
    expect(
      find.textContaining('Secure sign-in storage is taking too long'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
          '/api/v1/Account/login' => '{"errorCode":0,"token":"test-token","userID":1,"userName":"Taylor","companyName":"Studio","userRole":"ADMIN"}',
          '/api/v1/Transaction/GetDashboardSummaryAsync' =>
            '{"errorCode":0,"data":{}}',
          '/api/v1/transaction/GetDashboardDetails' =>
            '{"errorCode":0,"data":{}}',
          '/api/v1/transaction/GetOrderAndRentalStatusCounts' => '{"errorCode":0,"data":{"orderStatus":{"labels":["Stitching","Ready"],"series":[3,1]},"rentalStatus":{"labels":["Booked","Delivered","In alterations","Returns"],"series":[4,2,1,3]}}}',
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
        rentalRepository: RentalRepository(api),
        reportsRepository: ReportsRepository(api),
        tailoringRepository: TailoringRepository(api),
        administrationRepository: AdministrationRepository(api),
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

    expect(find.byTooltip('Sign out'), findsOneWidget);
    expect(find.byKey(const ValueKey('party-logo')), findsOneWidget);
    expect(find.text('Tailoring orders'), findsOneWidget);
    expect(find.text('Rental orders'), findsOneWidget);
    expect(find.text('Stitching'), findsOneWidget);
    expect(find.text('In alterations'), findsOneWidget);
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
        userRole: 'RENTAL',
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
        rentalRepository: RentalRepository(api),
        reportsRepository: ReportsRepository(api),
        tailoringRepository: TailoringRepository(api),
        administrationRepository: AdministrationRepository(api),
        sessionStore: sessionStore,
        biometricAuthenticator: _UnavailableBiometrics(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byKey(const Key('pin-digit-0')), findsOneWidget);
    expect(find.byKey(const Key('pin-digit-3')), findsOneWidget);
    expect(find.text('UNLOCK'), findsNothing);
    await tester.enterText(find.byKey(const Key('mpin-field')), '1111');
    await tester.pumpAndSettle();
    expect(find.text('That MPIN is not correct. Try again.'), findsOneWidget);
    expect(find.byTooltip('Sign out'), findsNothing);

    await tester.enterText(find.byKey(const Key('mpin-field')), '4321');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Sign out'), findsOneWidget);
    expect(find.text('Rental workflow'), findsOneWidget);
    expect(find.text('Tailoring orders'), findsNothing);
    expect(find.text('Stitching'), findsNothing);
    expect(find.text('Tailoring'), findsNothing);
    expect(find.text('Rental'), findsOneWidget);
    expect(find.text('Rentals due'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Welcome back'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Rental workflow'), findsOneWidget);
  });

  testWidgets('tailor role sees tailoring workflows without rental sections', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final session = const AuthSession(
      token: 'test-token',
      appId: 'app-123',
      financialYearId: 7,
      financialYearName: '2026-27',
      companyName: 'Studio',
      userName: 'Taylor',
      userRole: 'TAILOR',
    );
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient(
        (_) async => http.Response('{"errorCode":0,"data":{}}', 200),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          session: session,
          repository: DashboardRepository(api),
          rentalRepository: RentalRepository(api),
          reportsRepository: ReportsRepository(api),
          tailoringRepository: TailoringRepository(api),
          administrationRepository: AdministrationRepository(api),
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tailoring workflow'), findsOneWidget);
    expect(find.text('Tailoring orders'), findsOneWidget);
    expect(find.text('Rental orders'), findsNothing);
    expect(find.text('Returns'), findsNothing);
    expect(find.text('Needs attention'), findsNothing);
    expect(find.text('Tailor'), findsOneWidget);
    expect(find.text('Rental'), findsNothing);
    await tester.tap(find.text('Tailor').last);
    await tester.pumpAndSettle();
    expect(find.text('Tailoring transactions'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Tailoring workflow'), findsOneWidget);
    await tester.tap(find.text('Tailor').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ask assistant'));
    await tester.pumpAndSettle();
    expect(find.text('Ava'), findsWidgets);
    await tester.enterText(find.byType(TextField), 'create a tailoring order');
    await tester.tap(find.byTooltip('Send request'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open new order form'));
    await tester.pumpAndSettle();
    expect(find.text('Save order'), findsOneWidget);
    expect(find.byTooltip('Home'), findsOneWidget);
    await tester.tap(find.byTooltip('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Business overview'), findsOneWidget);
    await tester.tap(find.text('Ava').last);
    await tester.pumpAndSettle();
    expect(find.text('Ava'), findsWidgets);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Tailoring workflow'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin Item Master opens its own master form screen', (
    WidgetTester tester,
  ) async {
    final session = const AuthSession(
      token: 'test-token',
      appId: 'app-123',
      financialYearId: 7,
      financialYearName: '2026-27',
      companyName: 'Studio',
      userName: 'Admin',
      userRole: 'ADMIN',
    );
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient(
        (_) async => http.Response('{"errorCode":0,"data":[]}', 200),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          session: session,
          repository: DashboardRepository(api),
          rentalRepository: RentalRepository(api),
          reportsRepository: ReportsRepository(api),
          tailoringRepository: TailoringRepository(api),
          administrationRepository: AdministrationRepository(api),
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Masters and administration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Item Master'));
    await tester.pumpAndSettle();

    expect(find.byType(MasterManagementScreen), findsOneWidget);
    expect(find.text('Item Master'), findsOneWidget);
    expect(find.text('Add item'), findsOneWidget);
    expect(find.byTooltip('Ask assistant'), findsOneWidget);
    expect(find.text('Catalogue'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin Customers menu opens the customer administration form', (
    WidgetTester tester,
  ) async {
    final session = const AuthSession(
      token: 'admin-token',
      appId: 'app-123',
      financialYearId: 7,
      financialYearName: '2026-27',
      companyName: 'Studio',
      userName: 'Admin',
      userRole: 'ADMIN',
    );
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1/',
      client: MockClient(
        (_) async => http.Response('{"errorCode":0,"data":[]}', 200),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          session: session,
          repository: DashboardRepository(api),
          rentalRepository: RentalRepository(api),
          reportsRepository: ReportsRepository(api),
          tailoringRepository: TailoringRepository(api),
          administrationRepository: AdministrationRepository(api),
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Masters and administration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Administration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customers').last);
    await tester.pumpAndSettle();

    expect(find.text('No customers found.'), findsOneWidget);
    await tester.tap(find.byTooltip('Add customer'));
    await tester.pumpAndSettle();
    expect(find.text('Add customer'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Mobile number'), findsOneWidget);
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
    await tester.tap(find.byKey(const Key('mpin-field')));
    await tester.pump();
    final focusedDigit = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('pin-digit-0')).first,
    );
    final focusedDecoration = focusedDigit.decoration! as BoxDecoration;
    expect(focusedDecoration.color, const Color(0xFFFFE6A6));
    expect(focusedDecoration.border!.top.color, const Color(0xFFE19B00));

    await tester.tap(find.byType(SwitchListTile));
    await tester.enterText(find.byKey(const Key('mpin-field')), '2468');
    await tester.enterText(find.byKey(const Key('confirm-mpin-field')), '2468');
    await tester.ensureVisible(find.text('SAVE MPIN'));
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
  Future<String?> readLocale() async => savedLocale;

  @override
  Future<void> writeLocale(String languageCode) async {
    savedLocale = languageCode;
  }

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
  String? savedLocale;
}

class _HangingSessionStore extends SessionStore {
  _HangingSessionStore() : super(const FlutterSecureStorage());

  @override
  Future<AuthSession?> read() => Completer<AuthSession?>().future;
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
