import 'package:flutter/material.dart';
import 'package:silvae_app/features/daily_reports/domain/daily_report.dart';
import 'package:silvae_app/features/daily_reports/presentation/report_list_page.dart'
    show formatDay, formatHours;

enum ConflictChoice { keepLocal, keepServer }

/// Il conflitto messo davanti a chi lo deve decidere. Le due versioni sono
/// entrambe già sul dispositivo: quella scritta qui e quella scaricata dal
/// server durante il pull, così la scelta si fa anche senza rete.
class ConflictDialog extends StatelessWidget {
  const ConflictDialog({required this.report, super.key});

  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    final remote = report.remoteSnapshot;

    return AlertDialog(
      title: const Text('Report modificato anche altrove'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Questo report è stato cambiato sul server dopo che il '
              'dispositivo aveva già le sue modifiche. Scegli quale versione '
              'tenere: l\'altra viene persa.',
            ),
            const SizedBox(height: 16),
            _VersionCard(
              title: 'La tua versione',
              report: report,
              highlight: true,
            ),
            const SizedBox(height: 8),
            if (remote == null)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'La versione del server non è ancora stata scaricata. '
                    'Sincronizza quando c\'è rete per vederla.',
                  ),
                ),
              )
            else
              _VersionCard(
                title: 'Versione sul server',
                report: remote,
                highlight: false,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Decido dopo'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, ConflictChoice.keepServer),
          child: const Text('Tieni quella del server'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, ConflictChoice.keepLocal),
          child: const Text('Tieni la mia'),
        ),
      ],
    );
  }
}

class _VersionCard extends StatelessWidget {
  const _VersionCard({
    required this.title,
    required this.report,
    required this.highlight,
  });

  final String title;
  final DailyReport report;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: highlight
          ? Theme.of(context).colorScheme.secondaryContainer
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text('Data: ${formatDay(report.reportDate)}'),
            Text(
              'Squadra: ${report.content.crew.length} persone · '
              '${formatHours(report.content.totalHours)} ore',
            ),
            Text('Lavorazioni: ${report.content.activities.length}'),
            Text('Foto: ${report.content.photos.length}'),
            if (report.notes case final notes? when notes.isNotEmpty)
              Text('Note: $notes'),
            Text('Versione ${report.version}'),
          ],
        ),
      ),
    );
  }
}
