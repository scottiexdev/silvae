import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silvae_api_client/silvae_api_client.dart';
import 'package:silvae_app/app/dependencies.dart';
import 'package:silvae_app/core/photos/photo_capture.dart';
import 'package:silvae_app/features/daily_reports/domain/daily_report.dart';
import 'package:silvae_app/features/daily_reports/presentation/report_list_page.dart'
    show formatDay, formatHours, translateStatus;
import 'package:silvae_app/features/worksites/domain/worksite.dart';

/// La compilazione del report: cantiere, data, squadra con le ore,
/// lavorazioni, checklist di sicurezza, foto e note. Ogni salvataggio finisce
/// prima sul dispositivo e poi in coda.
class ReportEditorPage extends ConsumerStatefulWidget {
  const ReportEditorPage({required this.reportId, super.key});

  final String reportId;

  @override
  ConsumerState<ReportEditorPage> createState() => _ReportEditorPageState();
}

class _ReportEditorPageState extends ConsumerState<ReportEditorPage> {
  final _notesController = TextEditingController();

  DailyReport? _report;
  String? _worksiteId;
  DateTime _reportDate = DateTime.now();
  ReportContent _content = const ReportContent();
  bool _loading = true;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final report = await ref
        .read(reportRepositoryProvider)
        .getReport(widget.reportId);
    if (!mounted || report == null) {
      return;
    }
    setState(() {
      _report = report;
      _worksiteId = report.worksiteId;
      _reportDate = report.reportDate;
      _content = report.content;
      _notesController.text = report.notes ?? '';
      _loading = false;
    });
  }

  bool get _editable => _report?.isEditable ?? false;

  void _change(ReportContent content) {
    setState(() {
      _content = content;
      _dirty = true;
    });
  }

  Future<void> _save({bool silent = false}) async {
    final report = _report;
    final worksiteId = _worksiteId;
    if (report == null || worksiteId == null) {
      return;
    }

    await ref
        .read(reportRepositoryProvider)
        .updateOffline(
          reportId: report.id,
          worksiteId: worksiteId,
          reportDate: _reportDate,
          expectedVersion: report.version,
          notes: _notesController.text,
          content: _content,
        );
    _dirty = false;
    ref
      ..invalidate(dailyReportsProvider)
      ..invalidate(reportProvider(report.id));
    unawaited(ref.read(syncSchedulerProvider).syncNow());
    await _load();

    if (!silent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report salvato sul dispositivo.')),
      );
    }
  }

  Future<void> _submit() async {
    final report = _report;
    if (report == null) {
      return;
    }
    if (_content.crew.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aggiungi almeno una persona in squadra.'),
        ),
      );
      return;
    }

    final signature = await showDialog<String>(
      context: context,
      builder: (context) => const _SignatureDialog(),
    );
    if (signature == null) {
      return;
    }

    if (_dirty) {
      await _save(silent: true);
    }
    final current = _report;
    if (current == null) {
      return;
    }

    await ref
        .read(reportRepositoryProvider)
        .submitOffline(
          reportId: current.id,
          expectedVersion: current.version,
          signature: signature,
        );
    ref.invalidate(dailyReportsProvider);
    unawaited(ref.read(syncSchedulerProvider).syncNow());

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final worksites = ref.watch(worksitesProvider).value ?? const <Worksite>[];
    final members = ref.watch(organizationMembersProvider);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_editable ? 'Compila il report' : 'Report in sola lettura'),
        actions: [
          if (_editable)
            TextButton(onPressed: _save, child: const Text('Salva')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _StatusBanner(report: _report!),
          const SizedBox(height: 16),
          _WorksiteAndDate(
            worksites: worksites,
            worksiteId: _worksiteId,
            reportDate: _reportDate,
            enabled: _editable,
            onWorksiteChanged: (value) => setState(() {
              _worksiteId = value;
              _dirty = true;
            }),
            onDateChanged: (value) => setState(() {
              _reportDate = value;
              _dirty = true;
            }),
          ),
          const SizedBox(height: 24),
          _CrewSection(
            crew: _content.crew,
            members: members.value ?? const [],
            enabled: _editable,
            onChanged: (crew) => _change(_content.copyWith(crew: crew)),
          ),
          const SizedBox(height: 24),
          _ActivitiesSection(
            activities: _content.activities,
            enabled: _editable,
            onChanged: (activities) =>
                _change(_content.copyWith(activities: activities)),
          ),
          const SizedBox(height: 24),
          _SafetySection(
            checks: _content.safetyChecks,
            enabled: _editable,
            onChanged: (checks) =>
                _change(_content.copyWith(safetyChecks: checks)),
          ),
          const SizedBox(height: 24),
          _PhotosSection(
            reportId: widget.reportId,
            photos: _content.photos,
            enabled: _editable,
            onChanged: (photos) => _change(_content.copyWith(photos: photos)),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _notesController,
            enabled: _editable,
            maxLines: 4,
            maxLength: 4000,
            onChanged: (_) => _dirty = true,
            decoration: const InputDecoration(
              labelText: 'Note',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      floatingActionButton: _editable
          ? FloatingActionButton.extended(
              onPressed: _submit,
              icon: const Icon(Icons.send),
              label: const Text('Invia'),
            )
          : null,
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.report});

  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.assignment_outlined),
        title: Text(translateStatus(report.status)),
        subtitle: Text(
          report.signature == null
              ? 'Versione ${report.version}'
              : 'Versione ${report.version} · confermato da ${report.signature}',
        ),
      ),
    );
  }
}

class _WorksiteAndDate extends StatelessWidget {
  const _WorksiteAndDate({
    required this.worksites,
    required this.worksiteId,
    required this.reportDate,
    required this.enabled,
    required this.onWorksiteChanged,
    required this.onDateChanged,
  });

  final List<Worksite> worksites;
  final String? worksiteId;
  final DateTime reportDate;
  final bool enabled;
  final ValueChanged<String> onWorksiteChanged;
  final ValueChanged<DateTime> onDateChanged;

  @override
  Widget build(BuildContext context) {
    // Un report può puntare a un cantiere non più assegnato: in quel caso il
    // menu non contiene il suo id e il campo resta vuoto invece di scegliere
    // un cantiere al posto dell'operatore.
    final known = worksites.any((item) => item.id == worksiteId);

    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: known ? worksiteId : null,
          decoration: const InputDecoration(labelText: 'Cantiere'),
          items: worksites
              .map(
                (item) =>
                    DropdownMenuItem(value: item.id, child: Text(item.label)),
              )
              .toList(growable: false),
          onChanged: enabled ? (value) => onWorksiteChanged(value!) : null,
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event),
          title: const Text('Data'),
          subtitle: Text(formatDay(reportDate)),
          trailing: enabled ? const Icon(Icons.edit_calendar) : null,
          onTap: enabled
              ? () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: reportDate,
                    firstDate: DateTime(reportDate.year - 1),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    onDateChanged(picked);
                  }
                }
              : null,
        ),
      ],
    );
  }
}

class _CrewSection extends StatelessWidget {
  const _CrewSection({
    required this.crew,
    required this.members,
    required this.enabled,
    required this.onChanged,
  });

  final List<CrewLine> crew;
  final List<OrganizationMemberDto> members;
  final bool enabled;
  final ValueChanged<List<CrewLine>> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Squadra e ore',
      trailing: Text('${formatHours(_total)} ore'),
      onAdd: enabled && members.isNotEmpty ? () => _add(context) : null,
      children: crew.isEmpty
          ? const [Text('Nessuno in squadra: il report non si può inviare.')]
          : crew
                .map(
                  (line) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_nameOf(line.userId)),
                    subtitle: line.note == null ? null : Text(line.note!),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${formatHours(line.hours)} h'),
                        if (enabled)
                          IconButton(
                            tooltip: 'Togli dalla squadra',
                            icon: const Icon(Icons.close),
                            onPressed: () => onChanged(
                              crew
                                  .where((item) => item.userId != line.userId)
                                  .toList(growable: false),
                            ),
                          ),
                      ],
                    ),
                    onTap: enabled ? () => _add(context, existing: line) : null,
                  ),
                )
                .toList(growable: false),
    );
  }

  double get _total => crew.fold(0, (total, line) => total + line.hours);

  String _nameOf(String userId) {
    for (final member in members) {
      if (member.userId == userId) {
        return member.displayName;
      }
    }
    return 'Persona non in anagrafica';
  }

  Future<void> _add(BuildContext context, {CrewLine? existing}) async {
    final line = await showDialog<CrewLine>(
      context: context,
      builder: (context) => _CrewDialog(
        members: members,
        existing: existing,
        alreadyInCrew: crew
            .map((item) => item.userId)
            .where((id) => id != existing?.userId)
            .toSet(),
      ),
    );
    if (line == null) {
      return;
    }
    onChanged([...crew.where((item) => item.userId != line.userId), line]);
  }
}

class _CrewDialog extends StatefulWidget {
  const _CrewDialog({
    required this.members,
    required this.alreadyInCrew,
    this.existing,
  });

  final List<OrganizationMemberDto> members;
  final Set<String> alreadyInCrew;
  final CrewLine? existing;

  @override
  State<_CrewDialog> createState() => _CrewDialogState();
}

class _CrewDialogState extends State<_CrewDialog> {
  late String? _userId = widget.existing?.userId;
  late final _hoursController = TextEditingController(
    text: widget.existing == null ? '8' : formatHours(widget.existing!.hours),
  );
  late final _noteController = TextEditingController(
    text: widget.existing?.note ?? '',
  );

  @override
  void dispose() {
    _hoursController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectable = widget.members
        .where((member) => !widget.alreadyInCrew.contains(member.userId))
        .toList(growable: false);

    return AlertDialog(
      title: const Text('Ore della persona'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _userId,
            decoration: const InputDecoration(labelText: 'Persona'),
            items: selectable
                .map(
                  (member) => DropdownMenuItem(
                    value: member.userId,
                    child: Text(member.displayName),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) => setState(() => _userId = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hoursController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Ore'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Nota (facoltativa)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(onPressed: _confirm, child: const Text('Conferma')),
      ],
    );
  }

  void _confirm() {
    final userId = _userId;
    final hours = double.tryParse(
      _hoursController.text.trim().replaceAll(',', '.'),
    );
    // Il dominio rifiuta ore fuori dalla giornata: intercettarlo qui evita di
    // scoprirlo al momento della sincronizzazione, ore dopo e senza rete.
    if (userId == null || hours == null || hours <= 0 || hours > 24) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scegli la persona e indica ore fra 0 e 24.'),
        ),
      );
      return;
    }

    final note = _noteController.text.trim();
    Navigator.pop(
      context,
      CrewLine(userId: userId, hours: hours, note: note.isEmpty ? null : note),
    );
  }
}

class _ActivitiesSection extends StatelessWidget {
  const _ActivitiesSection({
    required this.activities,
    required this.enabled,
    required this.onChanged,
  });

  final List<ActivityLine> activities;
  final bool enabled;
  final ValueChanged<List<ActivityLine>> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Lavorazioni',
      onAdd: enabled ? () => _add(context) : null,
      children: activities.isEmpty
          ? const [Text('Nessuna lavorazione registrata.')]
          : List.generate(activities.length, (index) {
              final activity = activities[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(activity.description),
                subtitle: activity.quantity == null
                    ? null
                    : Text(
                        '${formatHours(activity.quantity!)} '
                                '${activity.unit ?? ''}'
                            .trim(),
                      ),
                trailing: enabled
                    ? IconButton(
                        tooltip: 'Togli la lavorazione',
                        icon: const Icon(Icons.close),
                        onPressed: () => onChanged([
                          ...activities.sublist(0, index),
                          ...activities.sublist(index + 1),
                        ]),
                      )
                    : null,
              );
            }),
    );
  }

  Future<void> _add(BuildContext context) async {
    final activity = await showDialog<ActivityLine>(
      context: context,
      builder: (context) => const _ActivityDialog(),
    );
    if (activity != null) {
      onChanged([...activities, activity]);
    }
  }
}

class _ActivityDialog extends StatefulWidget {
  const _ActivityDialog();

  @override
  State<_ActivityDialog> createState() => _ActivityDialogState();
}

class _ActivityDialogState extends State<_ActivityDialog> {
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Lavorazione'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _descriptionController,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Descrizione',
              hintText: 'Sfalcio, potatura, abbattimento…',
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Quantità'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _unitController,
                  maxLength: 16,
                  decoration: const InputDecoration(labelText: 'Unità'),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () {
            final description = _descriptionController.text.trim();
            if (description.isEmpty) {
              return;
            }
            final unit = _unitController.text.trim();
            Navigator.pop(
              context,
              ActivityLine(
                description: description,
                quantity: double.tryParse(
                  _quantityController.text.trim().replaceAll(',', '.'),
                ),
                unit: unit.isEmpty ? null : unit,
              ),
            );
          },
          child: const Text('Aggiungi'),
        ),
      ],
    );
  }
}

class _SafetySection extends StatelessWidget {
  const _SafetySection({
    required this.checks,
    required this.enabled,
    required this.onChanged,
  });

  final List<SafetyLine> checks;
  final bool enabled;
  final ValueChanged<List<SafetyLine>> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Checklist di sicurezza',
      children: safetyChecklist
          .map((entry) {
            final line = checks
                .where((item) => item.code == entry.code)
                .firstOrNull;
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: line?.isCompliant ?? false,
              title: Text(entry.label),
              subtitle: line != null && !line.isCompliant
                  ? Text('Non conforme: ${line.note}')
                  : null,
              tristate: false,
              onChanged: enabled
                  ? (value) => _toggle(context, entry.code, isCompliant: value!)
                  : null,
            );
          })
          .toList(growable: false),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    String code, {
    required bool isCompliant,
  }) async {
    final others = checks
        .where((item) => item.code != code)
        .toList(growable: false);

    if (isCompliant) {
      onChanged([...others, SafetyLine(code: code, isCompliant: true)]);
      return;
    }

    // Il dominio rifiuta una non conformità senza spiegazione: chi legge il
    // report a mesi di distanza deve sapere cosa mancava.
    final note = await showDialog<String>(
      context: context,
      builder: (context) => const _NoteDialog(
        title: 'Non conformità',
        hint: 'Cosa mancava e perché si è lavorato lo stesso',
      ),
    );
    if (note == null) {
      return;
    }
    onChanged([
      ...others,
      SafetyLine(code: code, isCompliant: false, note: note),
    ]);
  }
}

class _PhotosSection extends ConsumerWidget {
  const _PhotosSection({
    required this.reportId,
    required this.photos,
    required this.enabled,
    required this.onChanged,
  });

  final String reportId;
  final List<PhotoLine> photos;
  final bool enabled;
  final ValueChanged<List<PhotoLine>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Section(
      title: 'Foto',
      onAdd: enabled ? () => _capture(context, ref) : null,
      children: photos.isEmpty
          ? const [Text('Nessuna foto allegata.')]
          : photos
                .map(
                  (photo) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _Thumbnail(localReference: photo.localReference),
                    title: Text(photo.caption ?? photo.localReference),
                    subtitle: Text(
                      photo.hasPosition
                          ? '${photo.latitude!.toStringAsFixed(5)}, '
                                '${photo.longitude!.toStringAsFixed(5)}'
                          : 'Senza posizione',
                    ),
                    trailing: enabled
                        ? IconButton(
                            tooltip: 'Togli la foto',
                            icon: const Icon(Icons.close),
                            onPressed: () => onChanged(
                              photos
                                  .where(
                                    (item) =>
                                        item.localReference !=
                                        photo.localReference,
                                  )
                                  .toList(growable: false),
                            ),
                          )
                        : null,
                  ),
                )
                .toList(growable: false),
    );
  }

  Future<void> _capture(BuildContext context, WidgetRef ref) async {
    final fromCamera = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Scatta una foto'),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Scegli dalla galleria'),
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
    if (fromCamera == null) {
      return;
    }

    final photo = await PhotoCapture().capture(fromCamera: fromCamera);
    if (photo == null) {
      return;
    }

    // Il riferimento porta l'istante dello scatto: due foto con lo stesso nome
    // di file, cosa normale sul telefono, si sovrascriverebbero a vicenda.
    final reference =
        '${photo.capturedAt.millisecondsSinceEpoch}-${photo.fileName}';
    await ref
        .read(reportRepositoryProvider)
        .addPhoto(reportId: reportId, bytes: photo.bytes, fileName: reference);
    onChanged([
      ...photos,
      PhotoLine(
        localReference: reference,
        latitude: photo.latitude,
        longitude: photo.longitude,
        capturedAt: photo.capturedAt,
      ),
    ]);
  }
}

class _Thumbnail extends ConsumerWidget {
  const _Thumbnail({required this.localReference});

  final String localReference;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Uint8List?>(
      future: ref.read(reportRepositoryProvider).getPhotoBytes(localReference),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return const Icon(Icons.image_not_supported_outlined);
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.memory(bytes, width: 48, height: 48, fit: BoxFit.cover),
        );
      },
    );
  }
}

class _SignatureDialog extends StatefulWidget {
  const _SignatureDialog();

  @override
  State<_SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<_SignatureDialog> {
  final _controller = TextEditingController();
  bool _confirmed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Conferma del caposquadra'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            maxLength: 200,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Nome e cognome'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _confirmed,
            title: const Text(
              'Confermo che ore, lavorazioni e sicurezza sono corrette.',
            ),
            onChanged: (value) => setState(() => _confirmed = value ?? false),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _confirmed && _controller.text.trim().isNotEmpty
              ? () => Navigator.pop(context, _controller.text.trim())
              : null,
          child: const Text('Invia'),
        ),
      ],
    );
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        maxLength: 500,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _controller.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Registra'),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.trailing,
    this.onAdd,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ?trailing,
            if (onAdd != null)
              IconButton(
                tooltip: 'Aggiungi',
                onPressed: onAdd,
                icon: const Icon(Icons.add_circle_outline),
              ),
          ],
        ),
        const Divider(),
        ...children,
      ],
    );
  }
}
