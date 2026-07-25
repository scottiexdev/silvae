import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silvae_app/app/dependencies.dart';
import 'package:silvae_app/features/daily_reports/domain/daily_report.dart';
import 'package:silvae_app/features/worksites/domain/worksite.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _syncing = false;

  Future<void> _synchronize() async {
    setState(() => _syncing = true);
    await ref.read(reportRepositoryProvider).synchronize();
    ref.invalidate(worksitesProvider);
    ref.invalidate(dailyReportsProvider);
    if (mounted) {
      setState(() => _syncing = false);
    }
  }

  Future<void> _createReport(List<Worksite> worksites) async {
    if (worksites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessun cantiere disponibile offline.')),
      );
      return;
    }

    final result = await showDialog<_NewReport>(
      context: context,
      builder: (context) => _NewReportDialog(worksites: worksites),
    );
    if (result == null) {
      return;
    }

    await ref
        .read(reportRepositoryProvider)
        .createOffline(
          worksiteId: result.worksiteId,
          reportDate: result.date,
          notes: result.notes,
        );
    ref.invalidate(dailyReportsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rapportino salvato sul dispositivo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final worksites = ref.watch(worksitesProvider);
    final reports = ref.watch(dailyReportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forest, color: Color(0xFF246B45)),
            SizedBox(width: 8),
            Text('Silvae'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sincronizza',
            onPressed: _syncing ? null : _synchronize,
            icon: _syncing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: 'Esci',
            onPressed: () => ref.read(authGatewayProvider).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _synchronize,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Rapportini',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            const Text('I dati vengono salvati prima sul dispositivo.'),
            const SizedBox(height: 20),
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
        onPressed: () => _createReport(worksites.value ?? const []),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo rapportino'),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, this.worksite});

  final DailyReport report;
  final Worksite? worksite;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (report.syncStatus) {
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
      ReportSyncStatus.error => (
        Icons.sync_problem,
        'Errore di sincronizzazione',
        Colors.red,
      ),
    };
    return Card(
      child: ListTile(
        title: Text(worksite?.name ?? 'Cantiere'),
        subtitle: Text(
          '${report.reportDate.day.toString().padLeft(2, '0')}/'
          '${report.reportDate.month.toString().padLeft(2, '0')}/'
          '${report.reportDate.year}\n$label',
        ),
        isThreeLine: true,
        leading: Icon(icon, color: color),
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
        child: Text('Non ci sono ancora rapportini su questo dispositivo.'),
      ),
    );
  }
}

final class _NewReport {
  const _NewReport({required this.worksiteId, required this.date, this.notes});

  final String worksiteId;
  final DateTime date;
  final String? notes;
}

class _NewReportDialog extends StatefulWidget {
  const _NewReportDialog({required this.worksites});

  final List<Worksite> worksites;

  @override
  State<_NewReportDialog> createState() => _NewReportDialogState();
}

class _NewReportDialogState extends State<_NewReportDialog> {
  late String _worksiteId = widget.worksites.first.id;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuovo rapportino'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _worksiteId,
            decoration: const InputDecoration(labelText: 'Cantiere'),
            items: widget.worksites
                .map(
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text('${item.code} · ${item.name}'),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) => _worksiteId = value!,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            maxLines: 4,
            maxLength: 4000,
            decoration: const InputDecoration(
              labelText: 'Note',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _NewReport(
              worksiteId: _worksiteId,
              date: DateTime.now(),
              notes: _notesController.text,
            ),
          ),
          child: const Text('Salva sul dispositivo'),
        ),
      ],
    );
  }
}
