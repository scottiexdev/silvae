import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silvae_api_client/silvae_api_client.dart';
import 'package:silvae_app/app/dependencies.dart';
import 'package:silvae_app/app/theme.dart';
import 'package:silvae_app/app/ui.dart';
import 'package:silvae_app/features/daily_reports/presentation/report_list_page.dart'
    show formatDay, formatHours;

/// Competenze e abilitazioni: l'elenco per persona, gli avvisi di scadenza e
/// l'estrazione da mostrare a un'ispezione.
class SafetyPage extends StatelessWidget {
  const SafetyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabStrip(['Abilitazioni', 'In scadenza', 'Ispezione']),
          Expanded(
            child: TabBarView(
              children: [
                _CertificationsTab(),
                _ExpiringTab(),
                _InspectionTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CertificationsTab extends ConsumerWidget {
  const _CertificationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certifications = ref.watch(certificationsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: certifications.when(
        data: (items) => items.isEmpty
            ? Center(
                child: EmptyState(
                  icon: Icons.workspace_premium_outlined,
                  title: 'Nessuna abilitazione registrata',
                  message:
                      'Patentini e corsi valgono per un intervallo di date: '
                      'l\'ispezione chiede chi era abilitato quel giorno.',
                  action: FilledButton.icon(
                    onPressed: () => _edit(context, ref, null),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Prima abilitazione'),
                  ),
                ),
              )
            : PageBody(
                padding: const EdgeInsets.fromLTRB(
                  Insets.gutter,
                  Insets.gap,
                  Insets.gutter,
                  Insets.bottom,
                ),
                children: items
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: Insets.gap),
                        child: _CertificationCard(
                          certification: item,
                          onEdit: () => _edit(context, ref, item),
                          onDelete: () => _delete(context, ref, item),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
        loading: () => const Padding(
          padding: EdgeInsets.all(Insets.gutter),
          child: LoadingList(rows: 3),
        ),
        error: (error, stackTrace) => Center(
          child: ErrorState(title: 'Abilitazioni non leggibili', detail: error),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-certification',
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Nuova abilitazione'),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    CertificationDto? existing,
  ) async {
    final members = ref.read(organizationMembersProvider).value ?? const [];
    final documents =
        ref.read(documentsProvider(null)).value ?? const <DocumentDto>[];
    final messenger = ScaffoldMessenger.of(context);
    final draft = await showDialog<CertificationDto>(
      context: context,
      builder: (context) => _CertificationDialog(
        members: members,
        documents: documents,
        existing: existing,
      ),
    );
    if (draft == null) {
      return;
    }

    final client = ref.read(apiClientProvider);
    try {
      if (existing == null) {
        await client.createCertification(
          userId: draft.userId,
          kind: draft.kind,
          validFrom: draft.validFrom,
          expiresOn: draft.expiresOn,
          issuer: draft.issuer,
          documentId: draft.documentId,
        );
      } else {
        await client.updateCertification(
          existing.id,
          userId: draft.userId,
          kind: draft.kind,
          validFrom: draft.validFrom,
          expiresOn: draft.expiresOn,
          issuer: draft.issuer,
          documentId: draft.documentId,
        );
      }
      ref
        ..invalidate(certificationsProvider)
        ..invalidate(expiringCertificationsProvider);
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Non salvata: $error')));
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    CertificationDto item,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiClientProvider).deleteCertification(item.id);
      ref
        ..invalidate(certificationsProvider)
        ..invalidate(expiringCertificationsProvider);
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Non rimossa: $error')));
    }
  }
}

/// La scheda di un'abilitazione: chi, cosa e per quanto ancora vale.
class _CertificationCard extends StatelessWidget {
  const _CertificationCard({
    required this.certification,
    required this.onEdit,
    required this.onDelete,
  });

  final CertificationDto certification;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valid = certification.isValidToday;

    return SurfaceCard(
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(
                icon: valid ? Icons.verified_outlined : Icons.gpp_bad_outlined,
                tone: valid ? Tone.positive : Tone.danger,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      certification.displayName,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(certification.kind, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              StatusPill(
                label: valid ? 'Valida oggi' : 'Non valida',
                tone: valid ? Tone.positive : Tone.danger,
              ),
              IconButton(
                tooltip: 'Elimina',
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Facts([
            (Icons.play_arrow_outlined, formatDay(certification.validFrom)),
            (
              Icons.event_busy_outlined,
              certification.expiresOn == null
                  ? 'Senza scadenza'
                  : formatDay(certification.expiresOn!),
            ),
            if (certification.issuer != null)
              (Icons.apartment_outlined, certification.issuer!),
          ]),
        ],
      ),
    );
  }
}

class _ExpiringTab extends ConsumerWidget {
  const _ExpiringTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final expiring = ref.watch(expiringCertificationsProvider);

    return expiring.when(
      data: (items) => PageBody(
        padding: const EdgeInsets.all(Insets.gutter),
        children: [
          const InfoNote(
            'Abilitazioni già scadute o in scadenza nei prossimi 60 giorni. '
            'Un operatore senza abilitazione valida non può fare la '
            'lavorazione che la richiede.',
            icon: Icons.notifications_active_outlined,
          ),
          gapSections,
          if (items.isEmpty)
            const EmptyState(
              icon: Icons.check_circle_outline,
              title: 'Nessuna scadenza in vista',
              message: 'Nei prossimi 60 giorni non scade niente.',
            )
          else
            ...items.map((item) {
              final overdue =
                  item.daysToExpiry != null && item.daysToExpiry! < 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: Insets.gap),
                child: SurfaceCard(
                  accent: toneColors(
                    context,
                    overdue ? Tone.danger : Tone.caution,
                  ).foreground,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconBadge(
                        icon: overdue
                            ? Icons.gpp_bad_outlined
                            : Icons.warning_amber,
                        tone: overdue ? Tone.danger : Tone.caution,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.displayName,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(item.kind, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      StatusPill(
                        label: item.daysToExpiry == null
                            ? 'Senza scadenza'
                            : overdue
                            ? 'Scaduta da ${-item.daysToExpiry!} giorni'
                            : 'Fra ${item.daysToExpiry} giorni',
                        tone: overdue ? Tone.danger : Tone.caution,
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
      loading: () => const Padding(
        padding: EdgeInsets.all(Insets.gutter),
        child: LoadingList(rows: 3),
      ),
      error: (error, stackTrace) => Center(
        child: ErrorState(title: 'Scadenze non leggibili', detail: error),
      ),
    );
  }
}

class _InspectionTab extends ConsumerStatefulWidget {
  const _InspectionTab();

  @override
  ConsumerState<_InspectionTab> createState() => _InspectionTabState();
}

class _InspectionTabState extends ConsumerState<_InspectionTab> {
  DateTimeRange? _range;
  String? _worksiteId;
  List<InspectionDayDto>? _result;
  String? _error;
  bool _loading = false;

  Future<void> _extract() async {
    final range = _range;
    if (range == null) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(apiClientProvider)
          .getCertificationInspection(
            from: range.start,
            to: range.end,
            worksiteId: _worksiteId,
          );
      setState(() {
        _result = result;
        _loading = false;
      });
    } on Object catch (error) {
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final worksites = ref.watch(allWorksitesProvider).value ?? const [];
    final result = _result;

    return PageBody(
      padding: const EdgeInsets.all(Insets.gutter),
      children: [
        const InfoNote(
          'Per ogni giornata dichiarata: chi era in cantiere e con quali '
          'abilitazioni valide a quella data, non a oggi.',
          icon: Icons.gavel_outlined,
        ),
        gapSections,
        SurfaceCard(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(title: 'Cosa estrarre'),
              InkWell(
                borderRadius: BorderRadius.circular(Radii.chip),
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(DateTime.now().year - 5),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _range = picked);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      const IconBadge(
                        icon: Icons.date_range_outlined,
                        size: 36,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Periodo', style: theme.textTheme.bodyLarge),
                            Text(
                              _range == null
                                  ? 'Da scegliere'
                                  : '${formatDay(_range!.start)} – '
                                        '${formatDay(_range!.end)}',
                              style: theme.textTheme.bodySmall?.tabular,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_calendar_outlined, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Insets.gap),
              DropdownButtonFormField<String>(
                initialValue: _worksiteId,
                decoration: const InputDecoration(
                  labelText: 'Cantiere (tutti se vuoto)',
                ),
                items: worksites
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text('${item.code} · ${item.name}'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) => setState(() => _worksiteId = value),
              ),
              const SizedBox(height: Insets.gutter),
              FilledButton.icon(
                onPressed: _range == null || _loading ? null : _extract,
                icon: const Icon(Icons.search, size: 18),
                label: Text(_loading ? 'Estrazione…' : 'Estrai'),
              ),
            ],
          ),
        ),
        gapSections,
        if (_loading) const LoadingList(rows: 2),
        if (_error != null)
          ErrorState(title: 'Estrazione non riuscita', detail: _error!),
        if (result != null && result.isEmpty)
          const EmptyState(
            icon: Icons.event_note_outlined,
            title: 'Nessuna giornata dichiarata',
            message: 'Nel periodo scelto non risultano report.',
          ),
        if (result != null && result.isNotEmpty)
          ...result.map(
            (day) => Padding(
              padding: const EdgeInsets.only(bottom: Insets.gap),
              child: SurfaceCard(
                padding: EdgeInsets.zero,
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  leading: const IconBadge(
                    icon: Icons.event_available_outlined,
                    size: 36,
                  ),
                  title: Text(
                    '${formatDay(day.reportDate)} · ${day.worksiteCode}',
                    style: theme.textTheme.titleSmall?.tabular,
                  ),
                  subtitle: Text('${day.crew.length} in cantiere'),
                  children: day.crew
                      .map((person) {
                        final uncovered = person.certifications.isEmpty;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: IconBadge(
                            icon: uncovered
                                ? Icons.gpp_maybe_outlined
                                : Icons.verified_outlined,
                            tone: uncovered ? Tone.caution : Tone.positive,
                            size: 36,
                          ),
                          title: Text(
                            '${person.displayName} · '
                            '${formatHours(person.hours)} ore',
                          ),
                          subtitle: Text(
                            uncovered
                                ? 'Nessuna abilitazione valida quel giorno'
                                : person.certifications
                                      .map((item) => item.kind)
                                      .join(', '),
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CertificationDialog extends StatefulWidget {
  const _CertificationDialog({
    required this.members,
    required this.documents,
    this.existing,
  });

  final List<OrganizationMemberDto> members;
  final List<DocumentDto> documents;
  final CertificationDto? existing;

  @override
  State<_CertificationDialog> createState() => _CertificationDialogState();
}

class _CertificationDialogState extends State<_CertificationDialog> {
  static const List<String> _kinds = [
    'Patentino motosega',
    'Abilitazione trattore',
    'Corso DPI e sicurezza',
    'Primo soccorso',
    'Antincendio',
    'Tree climbing',
  ];

  late String? _userId = widget.existing?.userId;
  late String _kind = widget.existing?.kind ?? _kinds.first;
  late final _issuerController = TextEditingController(
    text: widget.existing?.issuer ?? '',
  );
  late DateTime _validFrom = widget.existing?.validFrom ?? DateTime.now();
  late DateTime? _expiresOn = widget.existing?.expiresOn;
  late String? _documentId = widget.existing?.documentId;

  @override
  void dispose() {
    _issuerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kinds = {..._kinds, _kind}.toList(growable: false);

    return AlertDialog(
      title: Text(widget.existing == null ? 'Nuova abilitazione' : 'Modifica'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _userId,
              decoration: const InputDecoration(labelText: 'Persona'),
              items: widget.members
                  .map(
                    (member) => DropdownMenuItem(
                      value: member.userId,
                      child: Text(member.displayName),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() => _userId = value),
            ),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Abilitazione'),
              items: kinds
                  .map(
                    (kind) => DropdownMenuItem(value: kind, child: Text(kind)),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() => _kind = value!),
            ),
            TextField(
              controller: _issuerController,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Ente rilasciante'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Valida dal'),
              subtitle: Text(formatDay(_validFrom)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () async {
                final picked = await _pickDate(context, _validFrom);
                if (picked != null) {
                  setState(() => _validFrom = picked);
                }
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Scade il'),
              subtitle: Text(
                _expiresOn == null ? 'Non scade' : formatDay(_expiresOn!),
              ),
              trailing: _expiresOn == null
                  ? const Icon(Icons.edit_calendar_outlined)
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _expiresOn = null),
                    ),
              onTap: () async {
                final picked = await _pickDate(
                  context,
                  _expiresOn ?? DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _expiresOn = picked);
                }
              },
            ),
            DropdownButtonFormField<String>(
              initialValue: _documentId,
              decoration: const InputDecoration(
                labelText: 'Attestato allegato',
              ),
              items: widget.documents
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.title),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() => _documentId = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () {
            final userId = _userId;
            if (userId == null) {
              return;
            }
            final issuer = _issuerController.text.trim();
            Navigator.pop(
              context,
              CertificationDto(
                id: widget.existing?.id ?? '',
                userId: userId,
                displayName: '',
                kind: _kind,
                issuer: issuer.isEmpty ? null : issuer,
                validFrom: _validFrom,
                expiresOn: _expiresOn,
                documentId: _documentId,
                isValidToday: true,
              ),
            );
          },
          child: const Text('Salva'),
        ),
      ],
    );
  }

  static Future<DateTime?> _pickDate(BuildContext context, DateTime initial) =>
      showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(DateTime.now().year - 30),
        lastDate: DateTime(DateTime.now().year + 30),
      );
}
