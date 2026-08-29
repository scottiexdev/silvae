import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silvae_api_client/silvae_api_client.dart';
import 'package:silvae_app/app/dependencies.dart';
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
    final detail = ref.watch(_worksiteDetailProvider(worksiteId));

    return Scaffold(
      appBar: AppBar(title: const Text('Cantiere')),
      body: detail.when(
        data: (item) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                title: Text('${item.worksite.code} · ${item.worksite.name}'),
                subtitle: Text(
                  '${item.worksite.jobOrderName ?? 'Commessa non assegnata'}\n'
                  '${item.worksite.address ?? 'Indirizzo non indicato'}',
                ),
                isThreeLine: true,
                trailing: Switch(
                  value: item.worksite.isActive,
                  onChanged: (value) => _setActive(context, ref, value),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Squadra assegnata',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Assegna una persona',
                  icon: const Icon(Icons.person_add_alt),
                  onPressed: () => _assign(context, ref, item),
                ),
              ],
            ),
            const Divider(),
            if (item.assignments.isEmpty)
              const Text('Nessuno assegnato: nessuno vedrà questo cantiere.')
            else
              ...item.assignments.map(
                (member) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(member.displayName),
                  subtitle: Text(translateRole(member.role)),
                  trailing: IconButton(
                    tooltip: 'Togli dal cantiere',
                    icon: const Icon(Icons.close),
                    onPressed: () => _unassign(context, ref, member.userId),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              'Documenti e autorizzazioni',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            SizedBox(height: 360, child: DocumentsPage(worksiteId: worksiteId)),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Cantiere non leggibile: $error')),
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
          children: selectable
              .map(
                (member) => ListTile(
                  title: Text(member.displayName),
                  subtitle: Text(translateRole(member.role)),
                  onTap: () => Navigator.pop(context, member),
                ),
              )
              .toList(growable: false),
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
