import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silvae_api_client/silvae_api_client.dart';
import 'package:silvae_app/core/auth/auth_gateway.dart';
import 'package:silvae_app/core/database/local_database.dart';
import 'package:silvae_app/features/daily_reports/data/daily_report_repository.dart';
import 'package:silvae_app/features/daily_reports/domain/daily_report.dart';
import 'package:silvae_app/features/worksites/domain/worksite.dart';

final localDatabaseProvider = Provider<LocalDatabase>(
  (ref) => throw StateError('LocalDatabase non configurato'),
);

final apiClientProvider = Provider<SilvaeApiClient>(
  (ref) => throw StateError('SilvaeApiClient non configurato'),
);

final organizationIdProvider = Provider<String>(
  (ref) => throw StateError('Organizzazione non configurata'),
);

final authGatewayProvider = Provider<AuthGateway>(
  (ref) => throw StateError('AuthGateway non configurato'),
);

final authStateProvider = StreamProvider<bool>(
  (ref) => ref.watch(authGatewayProvider).authChanges,
);

final reportRepositoryProvider = Provider<DailyReportRepository>(
  (ref) => DailyReportRepository(
    ref.watch(localDatabaseProvider),
    ref.watch(apiClientProvider),
    ref.watch(organizationIdProvider),
  ),
);

final worksitesProvider = FutureProvider<List<Worksite>>(
  (ref) => ref.watch(reportRepositoryProvider).getWorksites(refresh: true),
);

final dailyReportsProvider = FutureProvider<List<DailyReport>>(
  (ref) => ref.watch(reportRepositoryProvider).getReports(),
);
