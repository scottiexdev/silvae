import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silvae_api_client/silvae_api_client.dart';
import 'package:silvae_app/app/dependencies.dart';
import 'package:silvae_app/app/theme.dart';
import 'package:silvae_app/app/ui.dart';
import 'package:silvae_app/core/files/file_transfer.dart';
import 'package:silvae_app/features/daily_reports/presentation/report_list_page.dart'
    show formatDay;

/// L'archivio dei documenti. Senza cantiere mostra tutto quello
/// dell'organizzazione; con un cantiere, le sue autorizzazioni.
class DocumentsPage extends ConsumerWidget {
  const DocumentsPage({super.key, this.worksiteId});

  final String? worksiteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(documentsProvider(worksiteId));
    final canManage = ref.watch(isOfficeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: documents.when(
        data: (items) => items.isEmpty
            ? const Center(
                child: EmptyState(
                  icon: Icons.folder_open_outlined,
                  title: 'Archivio vuoto',
                  message:
                      'Autorizzazioni, attestati e perizie caricati qui '
                      'restano consultabili anche dal cantiere.',
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
                        child: _DocumentCard(
                          document: item,
                          canManage: canManage,
                          onDownload: () => _download(context, ref, item),
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
          child: ErrorState(title: 'Archivio non leggibile', detail: error),
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              heroTag: 'upload-document-${worksiteId ?? 'all'}',
              onPressed: () => _upload(context, ref),
              icon: const Icon(Icons.upload_file),
              label: const Text('Carica'),
            )
          : null,
    );
  }

  Future<void> _upload(BuildContext context, WidgetRef ref) async {
    final picked = await const FileTransfer().pick();
    if (picked == null || !context.mounted) {
      return;
    }

    final draft = await showDialog<_DocumentDraft>(
      context: context,
      builder: (context) => _DocumentDialog(fileName: picked.name),
    );
    if (draft == null || !context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(apiClientProvider)
          .uploadDocument(
            title: draft.title,
            category: draft.category,
            fileName: picked.name,
            bytes: picked.bytes,
            worksiteId: worksiteId,
            issuedOn: draft.issuedOn,
            expiresOn: draft.expiresOn,
          );
      ref.invalidate(documentsProvider(worksiteId));
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Caricamento non riuscito: $error')),
      );
    }
  }

  Future<void> _download(
    BuildContext context,
    WidgetRef ref,
    DocumentDto document,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await ref.read(apiClientProvider).downloadDocument(document);
      await const FileTransfer().save(file);
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Download non riuscito: $error')),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    DocumentDto document,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminare "${document.title}"?'),
        content: const Text('Il file viene tolto dall\'archivio.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(apiClientProvider).deleteDocument(document.id);
      ref.invalidate(documentsProvider(worksiteId));
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Eliminazione non riuscita: $error')),
      );
    }
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.canManage,
    required this.onDownload,
    required this.onDelete,
  });

  final DocumentDto document;
  final bool canManage;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expired = document.isExpired;

    return SurfaceCard(
      onTap: onDownload,
      accent: expired ? toneColors(context, Tone.danger).foreground : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
            icon: expired
                ? Icons.event_busy_outlined
                : _iconFor(document.category),
            tone: expired ? Tone.danger : Tone.neutral,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(document.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Facts([
                  (Icons.sell_outlined, document.category),
                  (
                    Icons.data_usage_outlined,
                    '${(document.sizeBytes / 1024).round()} kB',
                  ),
                ]),
                const SizedBox(height: 8),
                StatusPill(
                  label: document.expiresOn == null
                      ? 'Senza scadenza'
                      : expired
                      ? 'Scaduto il ${formatDay(document.expiresOn!)}'
                      : 'Scade il ${formatDay(document.expiresOn!)}',
                  tone: document.expiresOn == null
                      ? Tone.neutral
                      : expired
                      ? Tone.danger
                      : Tone.positive,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Scarica',
            icon: const Icon(Icons.download_outlined, size: 20),
            onPressed: onDownload,
          ),
          if (canManage)
            IconButton(
              tooltip: 'Elimina',
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }

  static IconData _iconFor(String category) => switch (category) {
    'Autorizzazione' => Icons.verified_outlined,
    'Attestato' => Icons.workspace_premium_outlined,
    'Perizia' => Icons.biotech_outlined,
    'Contratto' => Icons.handshake_outlined,
    _ => Icons.description_outlined,
  };
}

final class _DocumentDraft {
  const _DocumentDraft({
    required this.title,
    required this.category,
    this.issuedOn,
    this.expiresOn,
  });

  final String title;
  final String category;
  final DateTime? issuedOn;
  final DateTime? expiresOn;
}

class _DocumentDialog extends StatefulWidget {
  const _DocumentDialog({required this.fileName});

  final String fileName;

  @override
  State<_DocumentDialog> createState() => _DocumentDialogState();
}

class _DocumentDialogState extends State<_DocumentDialog> {
  late final _titleController = TextEditingController(text: widget.fileName);
  String _category = 'Autorizzazione';
  DateTime? _issuedOn;
  DateTime? _expiresOn;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Documento'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Titolo'),
            ),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items:
                  const [
                        'Autorizzazione',
                        'Attestato',
                        'Perizia',
                        'Contratto',
                        'Altro',
                      ]
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(growable: false),
              onChanged: (value) => setState(() => _category = value!),
            ),
            _DateField(
              label: 'Rilasciato il',
              value: _issuedOn,
              onChanged: (value) => setState(() => _issuedOn = value),
            ),
            _DateField(
              label: 'Scade il',
              value: _expiresOn,
              onChanged: (value) => setState(() => _expiresOn = value),
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
            final title = _titleController.text.trim();
            if (title.isEmpty) {
              return;
            }
            Navigator.pop(
              context,
              _DocumentDraft(
                title: title,
                category: _category,
                issuedOn: _issuedOn,
                expiresOn: _expiresOn,
              ),
            );
          },
          child: const Text('Carica'),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value == null ? 'Non indicata' : formatDay(value!)),
      trailing: value == null
          ? const Icon(Icons.edit_calendar_outlined)
          : IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => onChanged(null),
            ),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(DateTime.now().year - 20),
          lastDate: DateTime(DateTime.now().year + 20),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
    );
  }
}
