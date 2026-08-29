import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silvae_app/app/dependencies.dart';
import 'package:silvae_app/app/theme.dart';
import 'package:silvae_app/app/ui.dart';
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
        child: PageBody(
          children: [
            const InfoNote(
              'Quello che scrivi è già salvato sul dispositivo. Parte da solo '
              'appena la rete torna.',
              icon: Icons.offline_bolt_outlined,
            ),
            gapSections,
            reports.when(
              data: (items) => items.isEmpty
                  ? EmptyState(
                      icon: Icons.description_outlined,
                      title: 'Nessun report qui sopra',
                      message:
                          'Il primo report della giornata si apre dal '
                          'pulsante in basso e si compila anche senza rete.',
                    )
                  : Column(
                      children: [
                        SectionHeader(
                          title: 'Giornate compilate',
                          trailing: Text(
                            '${items.length}',
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.tabular,
                          ),
                        ),
                        ...items.map(
                          (report) => Padding(
                            padding: const EdgeInsets.only(bottom: Insets.gap),
                            child: _ReportCard(
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
                          ),
                        ),
                      ],
                    ),
              loading: () => const LoadingList(),
              error: (error, stackTrace) => ErrorState(
                title: 'Impossibile leggere i dati locali',
                detail: error,
              ),
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
    final theme = Theme.of(context);
    final sync = syncStatusBadge(report.syncStatus);
    final isConflict = report.syncStatus == ReportSyncStatus.conflict;

    return SurfaceCard(
      onTap: isConflict ? onResolve : onOpen,
      accent: isConflict ? toneColors(context, Tone.caution).foreground : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(icon: sync.$1, tone: sync.$3),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worksite?.name ?? 'Cantiere',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      worksite?.jobOrderName ?? 'Commessa non assegnata',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (isConflict)
                FilledButton.tonal(
                  onPressed: onResolve,
                  child: const Text('Risolvi'),
                )
              else
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Facts([
            (Icons.event_outlined, formatDay(report.reportDate)),
            (Icons.groups_outlined, '${report.content.crew.length} in squadra'),
            (
              Icons.schedule_outlined,
              '${formatHours(report.content.totalHours)} ore',
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(
                label: translateStatus(report.status),
                tone: statusTone(report.status),
              ),
              StatusPill(label: sync.$2, tone: sync.$3, icon: sync.$1),
            ],
          ),
        ],
      ),
    );
  }
}

(IconData, String, Tone) syncStatusBadge(ReportSyncStatus status) =>
    switch (status) {
      ReportSyncStatus.device => (
        Icons.smartphone,
        'Sul dispositivo',
        Tone.neutral,
      ),
      ReportSyncStatus.syncing => (Icons.sync, 'In invio', Tone.info),
      ReportSyncStatus.synced => (
        Icons.cloud_done_outlined,
        'Sincronizzato',
        Tone.positive,
      ),
      ReportSyncStatus.conflict => (
        Icons.merge_type,
        'Modificato anche altrove',
        Tone.caution,
      ),
      ReportSyncStatus.error => (
        Icons.sync_problem,
        'Errore di sincronizzazione',
        Tone.danger,
      ),
    };

Tone statusTone(String status) => switch (status) {
  'Approved' => Tone.positive,
  'Submitted' => Tone.info,
  'Reopened' => Tone.caution,
  _ => Tone.neutral,
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
