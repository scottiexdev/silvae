import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silvae_api_client/silvae_api_client.dart';
import 'package:silvae_app/app/dependencies.dart';
import 'package:silvae_app/app/theme.dart';
import 'package:silvae_app/app/ui.dart';
import 'package:silvae_app/features/documents/presentation/documents_page.dart';
import 'package:silvae_app/features/registry/presentation/registry_page.dart'
    show translateRole;

final _worksiteDetailProvider =
    FutureProvider.family<WorksiteDetailDto, String>(
      (ref, worksiteId) => ref.watch(apiClientProvider).getWorksite(worksiteId),
    );

/// Il cantiere con la sua squadra e i suoi documenti: le autorizzazioni
/// stanno dove serve mostrarle, cioè accanto al cantiere.
class WorksiteDetailPage extends ConsumerWidget {
  const WorksiteDetailPage({required this.worksiteId, super.key});

  final String worksiteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final detail = ref.watch(_worksiteDetailProvider(worksiteId));

    return Scaffold(
      appBar: AppBar(title: const Text('Cantiere')),
      body: detail.when(
        data: (item) => PageBody(
          padding: const EdgeInsets.all(Insets.gutter),
          children: [
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconBadge(
                        icon: Icons.terrain_outlined,
                        tone: item.worksite.isActive
                            ? Tone.positive
                            : Tone.neutral,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.worksite.name,
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.worksite.jobOrderName ??
                                  'Commessa non assegnata',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: item.worksite.isActive,
                        onChanged: (value) => _setActive(context, ref, value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Facts([
                    (Icons.tag, item.worksite.code),
                    (
                      Icons.place_outlined,
                      item.worksite.address ?? 'Indirizzo non indicato',
                    ),
                  ]),
                ],
              ),
            ),
            gapSections,
            SurfaceCard(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    title: 'Squadra assegnata',
                    trailing: StatusPill(
                      label: '${item.assignments.length}',
                      tone: item.assignments.isEmpty
                          ? Tone.caution
                          : Tone.neutral,
                    ),
                    onAdd: () => _assign(context, ref, item),
                    addTooltip: 'Assegna una persona',
                  ),
                  if (item.assignments.isEmpty)
                    Text(
                      'Nessuno assegnato: nessuno vedrà questo cantiere.',
                      style: theme.textTheme.bodySmall,
                    )
                  else
                    ...item.assignments.map(
                      (member) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const IconBadge(
                              icon: Icons.person_outline,
                              size: 36,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member.displayName,
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                  Text(
                                    translateRole(member.role),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Togli dal cantiere',
                              icon: const Icon(Icons.close, size: 18),
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  _unassign(context, ref, member.userId),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            gapSections,
            const SectionHeader(
              title: 'Documenti e autorizzazioni',
              subtitle: 'Quelli da mostrare a chi li chiede sul posto',
            ),
            SizedBox(height: 360, child: DocumentsPage(worksiteId: worksiteId)),
          ],
        ),
        loading: () => const Padding(
          padding: EdgeInsets.all(Insets.gutter),
          child: LoadingList(rows: 3),
        ),
        error: (error, stackTrace) => Center(
          child: ErrorState(title: 'Cantiere non leggibile', detail: error),
        ),
      ),
    );
  }

  Future<void> _setActive(BuildContext context, WidgetRef ref, bool isActive) =>
      _run(
        context,
        ref,
        () => ref
            .read(apiClientProvider)
            .updateWorksite(worksiteId, isActive: isActive),
      );

  Future<void> _assign(
    BuildContext context,
    WidgetRef ref,
    WorksiteDetailDto detail,
  ) async {
    final members = ref.read(organizationMembersProvider).value ?? const [];
    final assigned = detail.assignments.map((item) => item.userId).toSet();
    final selectable = members
        .where((member) => !assigned.contains(member.userId))
        .toList(growable: false);
    if (selectable.isEmpty) {
      return;
    }

    final choice = await showModalBottomSheet<OrganizationMemberDto>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: Insets.gutter),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
              child: Text(
                'Chi lavora qui',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ...selectable.map(
              (member) => ListTile(
                leading: const IconBadge(icon: Icons.person_outline, size: 36),
                title: Text(member.displayName),
                subtitle: Text(translateRole(member.role)),
                onTap: () => Navigator.pop(context, member),
              ),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) {
      return;
    }

    await _run(
      context,
      ref,
      () => ref
          .read(apiClientProvider)
          .assignWorksiteMember(worksiteId, choice.userId),
    );
  }

  Future<void> _unassign(BuildContext context, WidgetRef ref, String userId) =>
      _run(
        context,
        ref,
        () => ref
            .read(apiClientProvider)
            .unassignWorksiteMember(worksiteId, userId),
      );

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      ref
        ..invalidate(_worksiteDetailProvider(worksiteId))
        ..invalidate(allWorksitesProvider)
        ..invalidate(worksitesProvider);
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Operazione non riuscita: $error')),
      );
    }
  }
}
