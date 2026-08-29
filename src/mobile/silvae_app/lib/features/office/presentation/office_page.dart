import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silvae_api_client/silvae_api_client.dart';
import 'package:silvae_app/app/dependencies.dart';
import 'package:silvae_app/core/files/file_transfer.dart';
import 'package:silvae_app/features/daily_reports/presentation/report_list_page.dart'
    show formatDay, formatHours, translateStatus;

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
          const Divider(height: 1),
          Expanded(
            child: reports.when(
              data: (items) => items.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Nessun report con questi filtri.'),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(officeReportsProvider),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: items.length,
                        itemBuilder: (context, index) =>
                            _OfficeReportCard(report: items[index]),
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Impossibile leggere i report: $error'),
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
    final filter = ref.watch(reportFilterProvider);
    final jobOrders = ref.watch(jobOrdersProvider).value ?? const [];
    final worksites = ref.watch(allWorksitesProvider).value ?? const [];
    final members = ref.watch(organizationMembersProvider).value ?? const [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _FilterChip(
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
              onPressed: () => ref.read(reportFilterProvider.notifier).clear(),
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Azzera'),
            ),
        ],
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
        children: [
          ListTile(
            title: Text(title, style: Theme.of(context).textTheme.titleMedium),
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
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      avatar: const Icon(Icons.arrow_drop_down, size: 18),
      onPressed: onTap,
    );
  }
}

class _OfficeReportCard extends ConsumerWidget {
  const _OfficeReportCard({required this.report});

  final DailyReportSummaryDto report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text('${report.worksiteCode} · ${report.worksiteName}'),
        subtitle: Text(
          '${report.jobOrderName ?? 'Commessa non assegnata'}\n'
          '${formatDay(report.reportDate)} · ${report.crewCount} in squadra · '
          '${formatHours(report.totalHours)} ore\n'
          '${translateStatus(report.status)} · ${report.authorName}',
        ),
        isThreeLine: true,
        leading: report.hasSafetyFinding
            ? const Icon(Icons.warning_amber, color: Colors.orange)
            : const Icon(Icons.description_outlined),
        trailing: _actionFor(context, ref),
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
          IconButton(
            tooltip: 'Riapri',
            icon: const Icon(Icons.lock_open_outlined),
            onPressed: () => run(
              () => ref.read(apiClientProvider).reopenDailyReport(report.id),
              'Report riaperto.',
            ),
          ),
          FilledButton(
            onPressed: () => run(
              () => ref.read(apiClientProvider).approveDailyReport(report.id),
              'Report approvato.',
            ),
            child: const Text('Approva'),
          ),
        ],
      ),
      'Approved' => IconButton(
        tooltip: 'Riapri per correzione',
        icon: const Icon(Icons.lock_open_outlined),
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
                ListTile(
                  leading: const Icon(Icons.table_view_outlined),
                  title: const Text('Foglio di calcolo (CSV)'),
                  onTap: () => Navigator.pop(context, false),
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: const Text('Documento da stampare (PDF)'),
                  onTap: () => Navigator.pop(context, true),
                ),
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
