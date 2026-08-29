import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silvae_app/app/dependencies.dart';
import 'package:silvae_app/app/theme.dart';
import 'package:silvae_app/app/ui.dart';
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
      data: (items) => items.isEmpty
          ? const Center(
              child: EmptyState(
                icon: Icons.terrain_outlined,
                title: 'Nessun cantiere assegnato',
                message:
                    'Finché l\'ufficio non ti assegna a un cantiere qui non '
                    'compare niente.',
              ),
            )
          : PageBody(
              padding: const EdgeInsets.all(Insets.gutter),
              children: [
                const InfoNote(
                  'Apri un cantiere per avere le sue autorizzazioni a portata '
                  'di mano, anche senza rete.',
                  icon: Icons.folder_open_outlined,
                ),
                gapSections,
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: Insets.gap),
                    child: _WorksiteCard(worksite: item),
                  ),
                ),
              ],
            ),
      loading: () => const Padding(
        padding: EdgeInsets.all(Insets.gutter),
        child: LoadingList(),
      ),
      error: (error, stackTrace) => Center(
        child: ErrorState(title: 'Cantieri non leggibili', detail: error),
      ),
    );
  }
}

class _WorksiteCard extends StatelessWidget {
  const _WorksiteCard({required this.worksite});

  final Worksite worksite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SurfaceCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => _WorksiteDocumentsPage(worksite: worksite),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconBadge(icon: Icons.terrain_outlined),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(worksite.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      worksite.jobOrderName ?? 'Commessa non assegnata',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Facts([
            (Icons.tag, worksite.code),
            (
              Icons.place_outlined,
              worksite.address ?? 'Indirizzo non indicato',
            ),
          ]),
        ],
      ),
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
