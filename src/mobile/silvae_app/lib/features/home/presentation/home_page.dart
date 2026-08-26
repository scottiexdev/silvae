import 'dart:async';

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

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Un tentativo all'apertura: se la rete è tornata mentre l'app era
    // chiusa, la coda si svuota senza che l'operatore debba accorgersene.
    WidgetsBinding.instance.addPostFrameCallback((_) => _synchronize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_synchronize());
    }
  }

  Future<void> _synchronize() async {
    if (_syncing) {
      return;
    }
    setState(() => _syncing = true);
    await ref.read(syncSchedulerProvider).syncNow();
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

    final result = await showDialog<_ReportDraft>(
      context: context,
      builder: (context) => _ReportDialog(worksites: worksites),
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
    unawaited(_synchronize());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rapportino salvato sul dispositivo.')),
      );
    }
  }

  Future<void> _editReport(DailyReport report, List<Worksite> worksites) async {
    if (worksites.isEmpty) {
      return;
    }

    final result = await showDialog<_ReportDraft>(
      context: context,
      builder: (context) =>
          _ReportDialog(worksites: worksites, initial: report),
    );
    if (result == null) {
      return;
    }

    await ref
        .read(reportRepositoryProvider)
        .updateOffline(
          reportId: report.id,
          worksiteId: result.worksiteId,
          reportDate: result.date,
          expectedVersion: report.version,
          notes: result.notes,
        );
    ref.invalidate(dailyReportsProvider);
    unawaited(_synchronize());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modifica salvata sul dispositivo.')),
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
                              onEdit: () => _editReport(
                                report,
                                worksites.value ?? const [],
                              ),
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
  const _ReportCard({
    required this.report,
    required this.onEdit,
    this.worksite,
  });

  final DailyReport report;
  final Worksite? worksite;
  final VoidCallback onEdit;

  /// Il server accetta modifiche soltanto su bozza o rapportino riaperto, e
  /// un conflitto va risolto prima di accodare altre modifiche.
  bool get _isEditable =>
      (report.status == 'Draft' || report.status == 'Reopened') &&
      report.syncStatus != ReportSyncStatus.conflict;

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
    return Card(
      child: ListTile(
        title: Text(worksite?.name ?? 'Cantiere'),
        subtitle: Text(
          '${worksite?.jobOrderName ?? 'Commessa non assegnata'}\n'
          '${report.reportDate.day.toString().padLeft(2, '0')}/'
          '${report.reportDate.month.toString().padLeft(2, '0')}/'
          '${report.reportDate.year}\n$label',
        ),
        isThreeLine: true,
        leading: Icon(icon, color: color),
        trailing: _isEditable ? const Icon(Icons.edit_outlined) : null,
        onTap: _isEditable ? onEdit : null,
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

final class _ReportDraft {
  const _ReportDraft({
    required this.worksiteId,
    required this.date,
    this.notes,
  });

  final String worksiteId;
  final DateTime date;
  final String? notes;
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.worksites, this.initial});

  final List<Worksite> worksites;
  final DailyReport? initial;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  /// Un rapportino può puntare a un cantiere non più assegnato: in quel caso
  /// il menu non contiene il suo id e ricadiamo sul primo disponibile.
  late String _worksiteId =
      widget.worksites.any((item) => item.id == widget.initial?.worksiteId)
      ? widget.initial!.worksiteId
      : widget.worksites.first.id;
  late final _notesController = TextEditingController(
    text: widget.initial?.notes ?? '',
  );

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;
    return AlertDialog(
      title: Text(isEditing ? 'Modifica rapportino' : 'Nuovo rapportino'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _worksiteId,
            decoration: const InputDecoration(labelText: 'Cantiere'),
            items: widget.worksites
                .map(
                  (item) =>
                      DropdownMenuItem(value: item.id, child: Text(item.label)),
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
            _ReportDraft(
              worksiteId: _worksiteId,
              date: widget.initial?.reportDate ?? DateTime.now(),
              notes: _notesController.text,
            ),
          ),
          child: const Text('Salva sul dispositivo'),
        ),
      ],
    );
  }
}
