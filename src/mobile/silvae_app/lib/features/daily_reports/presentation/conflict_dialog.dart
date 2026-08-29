import 'package:flutter/material.dart';
import 'package:silvae_app/app/theme.dart';
import 'package:silvae_app/app/ui.dart';
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
    final theme = Theme.of(context);
    final remote = report.remoteSnapshot;

    return AlertDialog(
      icon: const IconBadge(
        icon: Icons.merge_type,
        tone: Tone.caution,
        size: 48,
      ),
      title: const Text('Report modificato anche altrove'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Questo report è stato cambiato sul server dopo che il '
                'dispositivo aveva già le sue modifiche. Scegli quale '
                'versione tenere: l\'altra viene persa.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: Insets.gutter),
              _VersionCard(
                title: 'La tua versione',
                report: report,
                highlight: true,
              ),
              const SizedBox(height: Insets.gap),
              if (remote == null)
                const InfoNote(
                  'La versione del server non è ancora stata scaricata. '
                  'Sincronizza quando c\'è rete per vederla.',
                  icon: Icons.cloud_off_outlined,
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? colors.primaryContainer : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.field),
        border: Border.all(
          color: highlight ? colors.primary : colors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
              Text(
                'Versione ${report.version}',
                style: theme.textTheme.labelSmall?.tabular,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Facts([
            (Icons.event_outlined, formatDay(report.reportDate)),
            (
              Icons.groups_outlined,
              '${report.content.crew.length} · '
                  '${formatHours(report.content.totalHours)} ore',
            ),
            (Icons.forest_outlined, '${report.content.activities.length}'),
            (Icons.photo_camera_outlined, '${report.content.photos.length}'),
          ]),
          if (report.notes case final notes? when notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(notes, style: theme.textTheme.bodySmall, maxLines: 3),
          ],
        ],
      ),
    );
  }
}
