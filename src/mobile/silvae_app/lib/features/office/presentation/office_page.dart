import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silvae_api_client/silvae_api_client.dart';
import 'package:silvae_app/app/dependencies.dart';
import 'package:silvae_app/app/theme.dart';
import 'package:silvae_app/app/ui.dart';
import 'package:silvae_app/core/files/file_transfer.dart';
import 'package:silvae_app/features/daily_reports/presentation/report_list_page.dart'
    show formatDay, formatHours, statusTone, translateStatus;

/// La vista del coordinatore: i report di tutta l'organizzazione, filtrati per
/// commessa, cantiere, squadra e data, con approvazione, riapertura ed export.
class OfficePage extends ConsumerWidget {
  const OfficePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(officeReportsProvider);

    return Scaffold(
      body: Column(
        children: [
          const _FilterBar(),
          Expanded(
            child: reports.when(
              data: (items) => items.isEmpty
                  ? const Center(
                      child: EmptyState(
                        icon: Icons.filter_alt_outlined,
                        title: 'Nessun report con questi filtri',
                        message:
                            'Allarga il periodo o togli un filtro: i report '
                            'arrivano dai dispositivi appena trovano rete.',
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(officeReportsProvider),
                      child: PageBody(
                        padding: const EdgeInsets.fromLTRB(
                          Insets.gutter,
                          Insets.gap,
                          Insets.gutter,
                          Insets.bottom,
                        ),
                        children: [
                          SectionHeader(
                            title: 'Giornate ricevute',
                            trailing: Text(
                              '${items.length}',
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.tabular,
                            ),
                          ),
                          ...items.map(
                            (report) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: Insets.gap,
                              ),
                              child: _OfficeReportCard(report: report),
                            ),
                          ),
                        ],
                      ),
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.all(Insets.gutter),
                child: LoadingList(),
              ),
              error: (error, stackTrace) => Center(
                child: ErrorState(
                  title: 'Impossibile leggere i report',
                  detail: error,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: reports.hasValue && reports.value!.isNotEmpty
          ? const _ExportButton()
          : null,
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final filter = ref.watch(reportFilterProvider);
    final jobOrders = ref.watch(jobOrdersProvider).value ?? const [];
    final worksites = ref.watch(allWorksitesProvider).value ?? const [];
    final members = ref.watch(organizationMembersProvider).value ?? const [];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          spacing: 8,
          children: [
            _FilterChip(
              icon: Icons.work_outline,
              label: filter.jobOrderId == null
                  ? 'Commessa'
                  : _labelOf(
                      jobOrders,
                      filter.jobOrderId!,
                      (item) => item.id,
                      (item) => '${item.code} · ${item.name}',
                    ),
              selected: filter.jobOrderId != null,
              onTap: () async {
                final choice = await _pick<JobOrderDto>(
                  context,
                  'Commessa',
                  jobOrders,
                  (item) => '${item.code} · ${item.name}',
                );
                ref
                    .read(reportFilterProvider.notifier)
                    .set(
                      choice == null
                          ? filter.copyWith(clearJobOrder: true)
                          : filter.copyWith(jobOrderId: choice.id),
                    );
              },
            ),
            _FilterChip(
              icon: Icons.terrain_outlined,
              label: filter.worksiteId == null
                  ? 'Cantiere'
                  : _labelOf(
                      worksites,
                      filter.worksiteId!,
                      (item) => item.id,
                      (item) => '${item.code} · ${item.name}',
                    ),
              selected: filter.worksiteId != null,
              onTap: () async {
                final choice = await _pick<WorksiteDto>(
                  context,
                  'Cantiere',
                  worksites,
                  (item) => '${item.code} · ${item.name}',
                );
                ref
                    .read(reportFilterProvider.notifier)
                    .set(
                      choice == null
                          ? filter.copyWith(clearWorksite: true)
                          : filter.copyWith(worksiteId: choice.id),
                    );
              },
            ),
            _FilterChip(
              icon: Icons.groups_outlined,
              label: filter.crewUserId == null
                  ? 'Squadra'
                  : _labelOf(
                      members,
                      filter.crewUserId!,
                      (item) => item.userId,
                      (item) => item.displayName,
                    ),
              selected: filter.crewUserId != null,
              onTap: () async {
                final choice = await _pick<OrganizationMemberDto>(
                  context,
                  'Persona in squadra',
                  members,
                  (item) => item.displayName,
                );
                ref
                    .read(reportFilterProvider.notifier)
                    .set(
                      choice == null
                          ? filter.copyWith(clearCrewUser: true)
                          : filter.copyWith(crewUserId: choice.userId),
                    );
              },
            ),
            _FilterChip(
              icon: Icons.date_range_outlined,
              label: filter.from == null
                  ? 'Periodo'
                  : '${formatDay(filter.from!)} – ${formatDay(filter.to!)}',
              selected: filter.from != null,
              onTap: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(DateTime.now().year - 3),
                  lastDate: DateTime.now(),
                );
                ref
                    .read(reportFilterProvider.notifier)
                    .set(
                      range == null
                          ? filter.copyWith(clearDates: true)
                          : filter.copyWith(from: range.start, to: range.end),
                    );
              },
            ),
            _FilterChip(
              icon: Icons.flag_outlined,
              label: filter.status == null
                  ? 'Stato'
                  : translateStatus(filter.status!),
              selected: filter.status != null,
              onTap: () async {
                final choice = await _pick<String>(context, 'Stato', const [
                  'Draft',
                  'Submitted',
                  'Approved',
                  'Reopened',
                ], translateStatus);
                ref
                    .read(reportFilterProvider.notifier)
                    .set(
                      choice == null
                          ? filter.copyWith(clearStatus: true)
                          : filter.copyWith(status: choice),
                    );
              },
            ),
            if (!filter.isEmpty)
              TextButton.icon(
                onPressed: () =>
                    ref.read(reportFilterProvider.notifier).clear(),
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('Azzera'),
              ),
          ],
        ),
      ),
    );
  }

  static String _labelOf<T>(
    List<T> items,
    String id,
    String Function(T) idOf,
    String Function(T) labelOf,
  ) {
    for (final item in items) {
      if (idOf(item) == id) {
        return labelOf(item);
      }
    }
    return 'Selezionato';
  }

  /// Un elenco di scelte con «Tutti» in cima: annullare il filtro deve
  /// costare quanto impostarlo.
  static Future<T?> _pick<T>(
    BuildContext context,
    String title,
    List<T> items,
    String Function(T) labelOf,
  ) => showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: Insets.gutter),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          ListTile(
            leading: const Icon(Icons.clear_all),
            title: const Text('Tutti'),
            onTap: () => Navigator.pop(context),
          ),
          const Divider(height: 1),
          ...items.map(
            (item) => ListTile(
              title: Text(labelOf(item)),
              onTap: () => Navigator.pop(context, item),
            ),
          ),
        ],
      ),
    ),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InputChip(
      label: Text(label),
      selected: selected,
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? colors.onPrimaryContainer : colors.onSurfaceVariant,
      ),
      // Un filtro impostato si distingue dal bordo, non solo dal testo: la
      // barra si legge di sfuggita mentre si scorre l'elenco.
      side: BorderSide(
        color: selected ? colors.primary : colors.outlineVariant,
      ),
      onPressed: onTap,
    );
  }
}

class _OfficeReportCard extends ConsumerWidget {
  const _OfficeReportCard({required this.report});

  final DailyReportSummaryDto report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final action = _actionFor(context, ref);

    return SurfaceCard(
      accent: report.hasSafetyFinding
          ? toneColors(context, Tone.caution).foreground
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(
                icon: report.hasSafetyFinding
                    ? Icons.warning_amber
                    : Icons.description_outlined,
                tone: report.hasSafetyFinding ? Tone.caution : Tone.neutral,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.worksiteName,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${report.worksiteCode} · '
                      '${report.jobOrderName ?? 'Commessa non assegnata'}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: translateStatus(report.status),
                tone: statusTone(report.status),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Facts([
            (Icons.event_outlined, formatDay(report.reportDate)),
            (Icons.groups_outlined, '${report.crewCount} in squadra'),
            (Icons.schedule_outlined, '${formatHours(report.totalHours)} ore'),
            (Icons.person_outline, report.authorName),
          ]),
          if (action != null) ...[
            const SizedBox(height: 14),
            Align(alignment: Alignment.centerRight, child: action),
          ],
        ],
      ),
    );
  }

  Widget? _actionFor(BuildContext context, WidgetRef ref) {
    Future<void> run(Future<void> Function() action, String done) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await action();
        ref.invalidate(officeReportsProvider);
        messenger.showSnackBar(SnackBar(content: Text(done)));
      } on Object catch (error) {
        messenger.showSnackBar(
          SnackBar(content: Text('Operazione non riuscita: $error')),
        );
      }
    }

    return switch (report.status) {
      'Submitted' => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.lock_open_outlined, size: 18),
            label: const Text('Riapri'),
            onPressed: () => run(
              () => ref.read(apiClientProvider).reopenDailyReport(report.id),
              'Report riaperto.',
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Approva'),
            onPressed: () => run(
              () => ref.read(apiClientProvider).approveDailyReport(report.id),
              'Report approvato.',
            ),
          ),
        ],
      ),
      'Approved' => TextButton.icon(
        icon: const Icon(Icons.lock_open_outlined, size: 18),
        label: const Text('Riapri per correzione'),
        onPressed: () => run(
          () => ref.read(apiClientProvider).reopenDailyReport(report.id),
          'Report riaperto: ora il cantiere può correggerlo.',
        ),
      ),
      _ => null,
    };
  }
}

class _ExportButton extends ConsumerWidget {
  const _ExportButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.extended(
      onPressed: () async {
        final asPdf = await showModalBottomSheet<bool>(
          context: context,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Esporta i report filtrati',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                ListTile(
                  leading: const IconBadge(icon: Icons.table_view_outlined),
                  title: const Text('Foglio di calcolo'),
                  subtitle: const Text('CSV, una riga per persona e giornata'),
                  onTap: () => Navigator.pop(context, false),
                ),
                ListTile(
                  leading: const IconBadge(icon: Icons.picture_as_pdf_outlined),
                  title: const Text('Documento da stampare'),
                  subtitle: const Text('PDF, come il foglio presenze'),
                  onTap: () => Navigator.pop(context, true),
                ),
                const SizedBox(height: Insets.gap),
              ],
            ),
          ),
        );
        if (asPdf == null || !context.mounted) {
          return;
        }

        final filter = ref.read(reportFilterProvider);
        final messenger = ScaffoldMessenger.of(context);
        try {
          final file = await ref
              .read(apiClientProvider)
              .exportDailyReports(
                asPdf: asPdf,
                jobOrderId: filter.jobOrderId,
                worksiteId: filter.worksiteId,
                crewUserId: filter.crewUserId,
                from: filter.from,
                to: filter.to,
                status: filter.status,
              );
          await const FileTransfer().save(file);
        } on Object catch (error) {
          messenger.showSnackBar(
            SnackBar(content: Text('Export non riuscito: $error')),
          );
        }
      },
      icon: const Icon(Icons.download),
      label: const Text('Esporta'),
    );
  }
}
