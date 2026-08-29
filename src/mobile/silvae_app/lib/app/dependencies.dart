import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silvae_api_client/silvae_api_client.dart';
import 'package:silvae_app/core/auth/auth_gateway.dart';
import 'package:silvae_app/core/database/local_database.dart';
import 'package:silvae_app/core/sync/sync_scheduler.dart';
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

final syncSchedulerProvider = Provider<SyncScheduler>((ref) {
  final scheduler = SyncScheduler(ref.watch(reportRepositoryProvider));
  ref.onDispose(scheduler.dispose);
  return scheduler;
});

final currentUserProvider = FutureProvider<CurrentUserDto>(
  (ref) => ref.watch(apiClientProvider).getCurrentUser(),
);

/// Il ruolo decide cosa l'app mostra. Non decide cosa concede: quello lo fa
/// il backend, che il ruolo lo rilegge dalla membership a ogni richiesta.
final currentRoleProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) {
    return 'Worker';
  }
  return user.roleIn(ref.watch(organizationIdProvider));
});

final isOfficeProvider = Provider<bool>((ref) {
  final role = ref.watch(currentRoleProvider);
  return role == 'Administrator' || role == 'Coordinator';
});

final worksitesProvider = FutureProvider<List<Worksite>>(
  (ref) => ref.watch(reportRepositoryProvider).getWorksites(refresh: true),
);

final dailyReportsProvider = FutureProvider<List<DailyReport>>(
  (ref) => ref.watch(reportRepositoryProvider).getReports(),
);

final reportProvider = FutureProvider.family<DailyReport?, String>(
  (ref, reportId) => ref.watch(reportRepositoryProvider).getReport(reportId),
);

final organizationMembersProvider = FutureProvider<List<OrganizationMemberDto>>(
  (ref) => ref.watch(apiClientProvider).getOrganizationMembers(),
);

final jobOrdersProvider = FutureProvider<List<JobOrderDto>>(
  (ref) => ref.watch(apiClientProvider).getJobOrders(),
);

final allWorksitesProvider = FutureProvider<List<WorksiteDto>>(
  (ref) =>
      ref.watch(apiClientProvider).getAssignedWorksites(includeInactive: true),
);

/// I filtri con cui l'ufficio guarda i report. Vivono in uno stato condiviso
/// perché l'export usa gli stessi criteri dell'elenco a schermo.
final class ReportFilter {
  const ReportFilter({
    this.jobOrderId,
    this.worksiteId,
    this.crewUserId,
    this.from,
    this.to,
    this.status,
  });

  final String? jobOrderId;
  final String? worksiteId;
  final String? crewUserId;
  final DateTime? from;
  final DateTime? to;
  final String? status;

  ReportFilter copyWith({
    String? jobOrderId,
    String? worksiteId,
    String? crewUserId,
    DateTime? from,
    DateTime? to,
    String? status,
    bool clearJobOrder = false,
    bool clearWorksite = false,
    bool clearCrewUser = false,
    bool clearDates = false,
    bool clearStatus = false,
  }) => ReportFilter(
    jobOrderId: clearJobOrder ? null : jobOrderId ?? this.jobOrderId,
    worksiteId: clearWorksite ? null : worksiteId ?? this.worksiteId,
    crewUserId: clearCrewUser ? null : crewUserId ?? this.crewUserId,
    from: clearDates ? null : from ?? this.from,
    to: clearDates ? null : to ?? this.to,
    status: clearStatus ? null : status ?? this.status,
  );

  bool get isEmpty =>
      jobOrderId == null &&
      worksiteId == null &&
      crewUserId == null &&
      from == null &&
      to == null &&
      status == null;
}

final class ReportFilterNotifier extends Notifier<ReportFilter> {
  @override
  ReportFilter build() => const ReportFilter();

  void set(ReportFilter filter) => state = filter;

  void clear() => state = const ReportFilter();
}

final reportFilterProvider =
    NotifierProvider<ReportFilterNotifier, ReportFilter>(
      ReportFilterNotifier.new,
    );

final officeReportsProvider = FutureProvider<List<DailyReportSummaryDto>>((
  ref,
) {
  final filter = ref.watch(reportFilterProvider);
  return ref
      .watch(apiClientProvider)
      .searchDailyReports(
        jobOrderId: filter.jobOrderId,
        worksiteId: filter.worksiteId,
        crewUserId: filter.crewUserId,
        from: filter.from,
        to: filter.to,
        status: filter.status,
      );
});

final certificationsProvider = FutureProvider<List<CertificationDto>>(
  (ref) => ref.watch(apiClientProvider).getCertifications(),
);

final expiringCertificationsProvider = FutureProvider<List<CertificationDto>>(
  (ref) => ref.watch(apiClientProvider).getExpiringCertifications(),
);

final documentsProvider = FutureProvider.family<List<DocumentDto>, String?>(
  (ref, worksiteId) =>
      ref.watch(apiClientProvider).getDocuments(worksiteId: worksiteId),
);
