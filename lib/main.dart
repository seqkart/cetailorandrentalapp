import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/session_store.dart';
import 'features/auth/auth_repository.dart';
import 'features/dashboard/dashboard_repository.dart';
import 'features/dashboard/administration_repository.dart';
import 'features/rentals/rental_repository.dart';
import 'features/reports/reports_repository.dart';
import 'features/tailoring/tailoring_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  const storage = FlutterSecureStorage();
  final apiClient = ApiClient();
  final sessionStore = SessionStore(storage);

  runApp(
    TailorRentalsApp(
      authRepository: AuthRepository(apiClient, sessionStore),
      dashboardRepository: DashboardRepository(apiClient),
      rentalRepository: RentalRepository(apiClient),
      reportsRepository: ReportsRepository(apiClient),
      tailoringRepository: TailoringRepository(apiClient),
      administrationRepository: AdministrationRepository(apiClient),
      sessionStore: sessionStore,
    ),
  );
}
