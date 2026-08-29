import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silvae_app/app/dependencies.dart';
import 'package:silvae_app/features/documents/presentation/documents_page.dart';
import 'package:silvae_app/features/worksites/domain/worksite.dart';

/// I cantieri assegnati all'operatore, con le autorizzazioni da mostrare a chi
/// le chiede sul posto.
class WorksitesPage extends ConsumerWidget {
  const WorksitesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worksites = ref.watch(worksitesProvider);

    return worksites.when(
      data: (items) => ListView(
        padding: const EdgeInsets.all(16),
        children: items.isEmpty
            ? const [Text('Nessun cantiere assegnato.')]
            : items
                  .map(
                    (item) => Card(
                      child: ListTile(
                        title: Text(item.name),
                        subtitle: Text(
                          '${item.code}\n'
                          '${item.jobOrderName ?? 'Commessa non assegnata'}\n'
                          '${item.address ?? 'Indirizzo non indicato'}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) =>
                                _WorksiteDocumentsPage(worksite: item),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          Center(child: Text('Cantieri non leggibili: $error')),
    );
  }
}

class _WorksiteDocumentsPage extends StatelessWidget {
  const _WorksiteDocumentsPage({required this.worksite});

  final Worksite worksite;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(worksite.name)),
      body: DocumentsPage(worksiteId: worksite.id),
    );
  }
}
