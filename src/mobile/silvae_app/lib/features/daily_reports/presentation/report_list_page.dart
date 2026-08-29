import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silvae_app/app/dependencies.dart';
import 'package:silvae_app/features/daily_reports/domain/daily_report.dart';
import 'package:silvae_app/features/daily_reports/presentation/conflict_dialog.dart';
import 'package:silvae_app/features/daily_reports/presentation/report_editor_page.dart';
import 'package:silvae_app/features/worksites/domain/worksite.dart';

/// I report che stanno su questo dispositivo, con lo stato della loro
/// sincronizzazione. È la schermata che l'operatore apre in cantiere.
class ReportListPage extends ConsumerWidget {
  const ReportListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worksites = ref.watch(worksitesProvider);
    final reports = ref.watch(dailyReportsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(syncSchedulerProvider).syncNow();
          ref
            ..invalidate(worksitesProvider)
            ..invalidate(dailyReportsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            const Text('I dati vengono salvati prima sul dispositivo.'),
            const SizedBox(height: 16),
            reports.when(
              data: (items) => items.isEmpty
                  ? const _EmptyReports()
                  : Column(
                      children: items
                          .map(
                            (report) => _ReportCard(
                              report: report,
                              worksite: worksites.value
                                  ?.where(
                                    (item) => item.id == report.worksiteId,
                                  )
                                  .firstOrNull,
                              onOpen: () =>
                                  _open(context, ref, report, worksites.value),
                              onResolve: () =>
                                  _resolveConflict(context, ref, report),
                            ),
                          )
                          .toList(growable: false),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  Text('Impossibile leggere i dati locali: $error'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref, worksites.value ?? const []),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo report'),
      ),
    );
  }

  Future<void> _create(
    BuildContext context,
    WidgetRef ref,
    List<Worksite> worksites,
  ) async {
    if (worksites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessun cantiere disponibile offline.')),
      );
      return;
    }

    final reportId = await ref
        .read(reportRepositoryProvider)
        .createOffline(
          worksiteId: worksites.first.id,
          reportDate: DateTime.now(),
        );
    ref.invalidate(dailyReportsProvider);
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ReportEditorPage(reportId: reportId),
      ),
    );
    ref.invalidate(dailyReportsProvider);
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    DailyReport report,
    List<Worksite>? worksites,
  ) async {
    if (worksites == null || worksites.isEmpty) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ReportEditorPage(reportId: report.id),
      ),
    );
    ref.invalidate(dailyReportsProvider);
  }

  Future<void> _resolveConflict(
    BuildContext context,
    WidgetRef ref,
    DailyReport report,
  ) async {
    final choice = await showDialog<ConflictChoice>(
      context: context,
      builder: (context) => ConflictDialog(report: report),
    );
    if (choice == null) {
      return;
    }

    final repository = ref.read(reportRepositoryProvider);
    if (choice == ConflictChoice.keepLocal) {
      await repository.keepLocalVersion(report.id);
      unawaited(ref.read(syncSchedulerProvider).syncNow());
    } else {
      await repository.keepServerVersion(report.id);
    }
    ref.invalidate(dailyReportsProvider);
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.onOpen,
    required this.onResolve,
    this.worksite,
  });

  final DailyReport report;
  final Worksite? worksite;
  final VoidCallback onOpen;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = syncStatusBadge(report.syncStatus);
    final isConflict = report.syncStatus == ReportSyncStatus.conflict;

    return Card(
      child: ListTile(
        title: Text(worksite?.name ?? 'Cantiere'),
        subtitle: Text(
          '${worksite?.jobOrderName ?? 'Commessa non assegnata'}\n'
          '${formatDay(report.reportDate)} · '
          '${report.content.crew.length} in squadra · '
          '${formatHours(report.content.totalHours)} ore\n'
          '${translateStatus(report.status)} · $label',
        ),
        isThreeLine: true,
        leading: Icon(icon, color: color),
        trailing: isConflict
            ? FilledButton.tonal(
                onPressed: onResolve,
                child: const Text('Risolvi'),
              )
            : const Icon(Icons.chevron_right),
        onTap: isConflict ? onResolve : onOpen,
      ),
    );
  }
}

class _EmptyReports extends StatelessWidget {
  const _EmptyReports();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Non ci sono ancora report su questo dispositivo.'),
      ),
    );
  }
}

(IconData, String, Color) syncStatusBadge(ReportSyncStatus status) =>
    switch (status) {
      ReportSyncStatus.device => (
        Icons.smartphone,
        'Salvato sul dispositivo',
        Colors.blueGrey,
      ),
      ReportSyncStatus.syncing => (Icons.sync, 'Sincronizzazione', Colors.blue),
      ReportSyncStatus.synced => (
        Icons.cloud_done,
        'Sincronizzato',
        Colors.green,
      ),
      ReportSyncStatus.conflict => (
        Icons.merge_type,
        'Modificato anche altrove',
        Colors.orange,
      ),
      ReportSyncStatus.error => (
        Icons.sync_problem,
        'Errore di sincronizzazione',
        Colors.red,
      ),
    };

String translateStatus(String status) => switch (status) {
  'Draft' => 'Bozza',
  'Submitted' => 'Inviato',
  'Approved' => 'Approvato',
  'Reopened' => 'Riaperto',
  _ => status,
};

String formatDay(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';

String formatHours(double hours) =>
    hours.toStringAsFixed(2).replaceAll('.', ',');
