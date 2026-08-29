import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silvae_api_client/silvae_api_client.dart';
import 'package:silvae_app/app/dependencies.dart';
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
          TabBar(
            tabs: [
              Tab(text: 'Abilitazioni'),
              Tab(text: 'In scadenza'),
              Tab(text: 'Ispezione'),
            ],
          ),
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
      body: certifications.when(
        data: (items) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: items.isEmpty
              ? const [Text('Nessuna abilitazione registrata.')]
              : items
                    .map(
                      (item) => Card(
                        child: ListTile(
                          title: Text(item.displayName),
                          subtitle: Text(_validity(item)),
                          leading: Icon(
                            item.isValidToday
                                ? Icons.verified_outlined
                                : Icons.gpp_bad_outlined,
                            color: item.isValidToday
                                ? Colors.green
                                : Colors.red,
                          ),
                          trailing: IconButton(
                            tooltip: 'Elimina',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(context, ref, item),
                          ),
                          onTap: () => _edit(context, ref, item),
                        ),
                      ),
                    )
                    .toList(growable: false),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Abilitazioni non leggibili: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-certification',
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Nuova abilitazione'),
      ),
    );
  }

  static String _validity(CertificationDto item) =>
      '${item.kind}\n'
      'Valida dal ${formatDay(item.validFrom)}'
      '${item.expiresOn == null ? ', senza scadenza' : ' al ${formatDay(item.expiresOn!)}'}';

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

class _ExpiringTab extends ConsumerWidget {
  const _ExpiringTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expiring = ref.watch(expiringCertificationsProvider);

    return expiring.when(
      data: (items) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Abilitazioni già scadute o in scadenza nei prossimi 60 '
                'giorni. Un operatore senza abilitazione valida non può fare '
                'la lavorazione che richiede.',
              ),
            ),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Nessuna abilitazione in scadenza.'),
            )
          else
            ...items.map(
              (item) => Card(
                child: ListTile(
                  leading: Icon(
                    Icons.warning_amber,
                    color: item.isValidToday ? Colors.orange : Colors.red,
                  ),
                  title: Text('${item.displayName} · ${item.kind}'),
                  subtitle: Text(
                    item.daysToExpiry == null
                        ? 'Senza scadenza'
                        : item.daysToExpiry! < 0
                        ? 'Scaduta da ${-item.daysToExpiry!} giorni'
                        : 'Scade fra ${item.daysToExpiry} giorni',
                  ),
                ),
              ),
            ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          Center(child: Text('Scadenze non leggibili: $error')),
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
    final worksites = ref.watch(allWorksitesProvider).value ?? const [];
    final result = _result;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Per ogni giornata dichiarata: chi era in cantiere e con quali '
              'abilitazioni valide a quella data, non a oggi.',
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.date_range),
          title: const Text('Periodo'),
          subtitle: Text(
            _range == null
                ? 'Da scegliere'
                : '${formatDay(_range!.start)} – ${formatDay(_range!.end)}',
          ),
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
        ),
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
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _range == null || _loading ? null : _extract,
          icon: const Icon(Icons.search),
          label: const Text('Estrai'),
        ),
        const SizedBox(height: 16),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_error != null) Text('Estrazione non riuscita: $_error'),
        if (result != null && result.isEmpty)
          const Text('Nessuna giornata dichiarata nel periodo.'),
        if (result != null)
          ...result.map(
            (day) => Card(
              child: ExpansionTile(
                title: Text(
                  '${formatDay(day.reportDate)} · ${day.worksiteCode}',
                ),
                subtitle: Text('${day.crew.length} in cantiere'),
                children: day.crew
                    .map(
                      (person) => ListTile(
                        title: Text(
                          '${person.displayName} · '
                          '${formatHours(person.hours)} ore',
                        ),
                        subtitle: Text(
                          person.certifications.isEmpty
                              ? 'Nessuna abilitazione valida quel giorno'
                              : person.certifications
                                    .map((item) => item.kind)
                                    .join(', '),
                        ),
                        leading: Icon(
                          person.certifications.isEmpty
                              ? Icons.gpp_maybe_outlined
                              : Icons.verified_outlined,
                          color: person.certifications.isEmpty
                              ? Colors.orange
                              : Colors.green,
                        ),
                      ),
                    )
                    .toList(growable: false),
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
