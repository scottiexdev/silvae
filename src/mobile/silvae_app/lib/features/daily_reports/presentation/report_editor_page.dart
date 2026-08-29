import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silvae_api_client/silvae_api_client.dart';
import 'package:silvae_app/app/dependencies.dart';
import 'package:silvae_app/app/theme.dart';
import 'package:silvae_app/app/ui.dart';
import 'package:silvae_app/core/photos/photo_capture.dart';
import 'package:silvae_app/features/daily_reports/domain/daily_report.dart';
import 'package:silvae_app/features/daily_reports/presentation/report_list_page.dart'
    show formatDay, formatHours, statusTone, translateStatus;
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
      return Scaffold(
        appBar: AppBar(title: const Text('Report')),
        body: const Padding(
          padding: EdgeInsets.all(Insets.gutter),
          child: LoadingList(rows: 3),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_editable ? 'Compila il report' : 'Report in sola lettura'),
        actions: [
          if (_editable)
            Padding(
              padding: const EdgeInsets.only(right: Insets.gap),
              child: FilledButton.tonalIcon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Salva'),
              ),
            ),
        ],
      ),
      body: PageBody(
        children: [
          _StatusBanner(report: _report!),
          gapSections,
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
          gapSections,
          _CrewSection(
            crew: _content.crew,
            members: members.value ?? const [],
            enabled: _editable,
            onChanged: (crew) => _change(_content.copyWith(crew: crew)),
          ),
          gapSections,
          _ActivitiesSection(
            activities: _content.activities,
            enabled: _editable,
            onChanged: (activities) =>
                _change(_content.copyWith(activities: activities)),
          ),
          gapSections,
          _SafetySection(
            checks: _content.safetyChecks,
            enabled: _editable,
            onChanged: (checks) =>
                _change(_content.copyWith(safetyChecks: checks)),
          ),
          gapSections,
          _PhotosSection(
            reportId: widget.reportId,
            photos: _content.photos,
            enabled: _editable,
            onChanged: (photos) => _change(_content.copyWith(photos: photos)),
          ),
          gapSections,
          _Section(
            title: 'Note',
            subtitle: 'Quel che non sta nelle righe qui sopra',
            children: [
              TextField(
                controller: _notesController,
                enabled: _editable,
                maxLines: 4,
                maxLength: 4000,
                onChanged: (_) => _dirty = true,
                decoration: const InputDecoration(
                  hintText: 'Imprevisti, mezzi fermi, accessi negati…',
                ),
              ),
            ],
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
    final theme = Theme.of(context);
    final tone = statusTone(report.status);

    return SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: Icons.assignment_outlined, tone: tone),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translateStatus(report.status),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Facts([
                  (Icons.tag, 'Versione ${report.version}'),
                  if (report.signature != null)
                    (Icons.how_to_reg_outlined, report.signature!),
                ]),
              ],
            ),
          ),
        ],
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

    return _Section(
      title: 'Dove e quando',
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
        const SizedBox(height: Insets.gap),
        _Line(
          leading: const IconBadge(icon: Icons.event_outlined, size: 36),
          title: 'Giornata',
          subtitle: formatDay(reportDate),
          trailing: enabled
              ? const Icon(Icons.edit_calendar_outlined, size: 20)
              : null,
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
    final theme = Theme.of(context);

    return _Section(
      title: 'Squadra e ore',
      trailing: StatusPill(
        label: '${formatHours(_total)} ore',
        tone: crew.isEmpty ? Tone.caution : Tone.positive,
      ),
      onAdd: enabled && members.isNotEmpty ? () => _add(context) : null,
      addTooltip: 'Aggiungi una persona',
      children: crew.isEmpty
          ? const [
              _Nothing('Nessuno in squadra: il report non si può inviare.'),
            ]
          : crew
                .map(
                  (line) => _Line(
                    leading: IconBadge(
                      icon: Icons.person_outline,
                      size: 36,
                      tone: line.note == null ? Tone.neutral : Tone.info,
                    ),
                    title: _nameOf(line.userId),
                    subtitle: line.note,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${formatHours(line.hours)} h',
                          style: theme.textTheme.titleSmall?.tabular,
                        ),
                        if (enabled)
                          IconButton(
                            tooltip: 'Togli dalla squadra',
                            icon: const Icon(Icons.close, size: 18),
                            visualDensity: VisualDensity.compact,
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
      addTooltip: 'Aggiungi una lavorazione',
      children: activities.isEmpty
          ? const [_Nothing('Nessuna lavorazione registrata.')]
          : List.generate(activities.length, (index) {
              final activity = activities[index];
              return _Line(
                leading: const IconBadge(icon: Icons.forest_outlined, size: 36),
                title: activity.description,
                subtitle: activity.quantity == null
                    ? null
                    : '${formatHours(activity.quantity!)} '
                              '${activity.unit ?? ''}'
                          .trim(),
                trailing: enabled
                    ? IconButton(
                        tooltip: 'Togli la lavorazione',
                        icon: const Icon(Icons.close, size: 18),
                        visualDensity: VisualDensity.compact,
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
    final done = checks.where((item) => item.isCompliant).length;
    final findings = checks.where((item) => !item.isCompliant).length;

    return _Section(
      title: 'Checklist di sicurezza',
      trailing: StatusPill(
        label: findings > 0
            ? '$findings non conformi'
            : '$done su ${safetyChecklist.length}',
        tone: findings > 0
            ? Tone.caution
            : done == safetyChecklist.length
            ? Tone.positive
            : Tone.neutral,
      ),
      children: safetyChecklist
          .map((entry) {
            final line = checks
                .where((item) => item.code == entry.code)
                .firstOrNull;
            final failed = line != null && !line.isCompliant;
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: line?.isCompliant ?? false,
              title: Text(entry.label),
              subtitle: failed
                  ? Text(
                      'Non conforme: ${line.note}',
                      style: TextStyle(
                        color: toneColors(context, Tone.caution).foreground,
                      ),
                    )
                  : null,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
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
      subtitle: 'Restano sul dispositivo: dall\'ufficio non si vedono.',
      onAdd: enabled ? () => _capture(context, ref) : null,
      addTooltip: 'Aggiungi una foto',
      children: photos.isEmpty
          ? const [_Nothing('Nessuna foto allegata.')]
          : [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: photos
                    .map(
                      (photo) => _PhotoTile(
                        photo: photo,
                        onRemove: enabled
                            ? () => onChanged(
                                photos
                                    .where(
                                      (item) =>
                                          item.localReference !=
                                          photo.localReference,
                                    )
                                    .toList(growable: false),
                              )
                            : null,
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
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

/// Una foto vale la sua immagine, non il nome del file: il riquadro mostra lo
/// scatto e, sopra, se porta con sé la posizione.
class _PhotoTile extends ConsumerWidget {
  const _PhotoTile({required this.photo, this.onRemove});

  static const double _size = 104;

  final PhotoLine photo;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.chip),
            child: ColoredBox(
              color: colors.surfaceContainerHigh,
              child: FutureBuilder<Uint8List?>(
                future: ref
                    .read(reportRepositoryProvider)
                    .getPhotoBytes(photo.localReference),
                builder: (context, snapshot) {
                  final bytes = snapshot.data;
                  if (bytes == null) {
                    return Icon(
                      Icons.image_not_supported_outlined,
                      color: colors.onSurfaceVariant,
                    );
                  }
                  return Image.memory(bytes, fit: BoxFit.cover);
                },
              ),
            ),
          ),
          Positioned(
            left: 6,
            bottom: 6,
            child: Tooltip(
              message: photo.hasPosition
                  ? '${photo.latitude!.toStringAsFixed(5)}, '
                        '${photo.longitude!.toStringAsFixed(5)}'
                  : 'Senza posizione',
              child: StatusPill(
                label: photo.hasPosition ? 'GPS' : 'No GPS',
                tone: photo.hasPosition ? Tone.positive : Tone.neutral,
              ),
            ),
          ),
          if (onRemove != null)
            Positioned(
              right: 2,
              top: 2,
              child: IconButton.filled(
                tooltip: 'Togli la foto',
                iconSize: 14,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor: colors.scrim.withValues(alpha: .55),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(26, 26),
                ),
                icon: const Icon(Icons.close),
                onPressed: onRemove,
              ),
            ),
        ],
      ),
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

/// Una parte del report: intestazione, azione che la riguarda e le sue righe,
/// tutto dentro la stessa scheda così si capisce dove finisce.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.subtitle,
    this.trailing,
    this.onAdd,
    this.addTooltip = 'Aggiungi',
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? trailing;
  final VoidCallback? onAdd;
  final String addTooltip;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: title,
            subtitle: subtitle,
            trailing: trailing,
            onAdd: onAdd,
            addTooltip: addTooltip,
          ),
          ...children,
        ],
      ),
    );
  }
}

/// Quel che una sezione dice quando è ancora vuota.
class _Nothing extends StatelessWidget {
  const _Nothing(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(message, style: theme.textTheme.bodySmall),
    );
  }
}

/// Una riga dentro una sezione: niente scheda dentro la scheda, solo un
/// separatore sottile e il dato in chiaro.
class _Line extends StatelessWidget {
  const _Line({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.chip),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyLarge),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!, style: theme.textTheme.bodySmall),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
