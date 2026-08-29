import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silvae_api_client/silvae_api_client.dart';
import 'package:silvae_app/app/dependencies.dart';
import 'package:silvae_app/features/documents/presentation/documents_page.dart';
import 'package:silvae_app/features/registry/presentation/worksite_detail_page.dart';

/// Commesse, cantieri, squadra e archivio: l'anagrafica che finora si
/// popolava soltanto chiamando l'API.
class RegistryPage extends StatelessWidget {
  const RegistryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Commesse'),
              Tab(text: 'Cantieri'),
              Tab(text: 'Squadra'),
              Tab(text: 'Archivio'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _JobOrdersTab(),
                _WorksitesTab(),
                _MembersTab(),
                DocumentsPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JobOrdersTab extends ConsumerWidget {
  const _JobOrdersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobOrders = ref.watch(jobOrdersProvider);

    return Scaffold(
      body: jobOrders.when(
        data: (items) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: items.isEmpty
              ? const [Text('Nessuna commessa.')]
              : items
                    .map(
                      (item) => Card(
                        child: ListTile(
                          title: Text('${item.code} · ${item.name}'),
                          subtitle: Text(
                            item.customer ?? 'Committente non indicato',
                          ),
                          trailing: item.isActive
                              ? null
                              : const Chip(label: Text('Chiusa')),
                          onTap: () => _edit(context, ref, item),
                        ),
                      ),
                    )
                    .toList(growable: false),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Anagrafica non leggibile: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-job-order',
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Nuova commessa'),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    JobOrderDto? existing,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<_JobOrderDraft>(
      context: context,
      builder: (context) => _JobOrderDialog(existing: existing),
    );
    if (result == null) {
      return;
    }

    final client = ref.read(apiClientProvider);
    try {
      if (existing == null) {
        await client.createJobOrder(
          code: result.code,
          name: result.name,
          customer: result.customer,
        );
      } else {
        await client.updateJobOrder(
          existing.id,
          name: result.name,
          customer: result.customer ?? '',
          isActive: result.isActive,
        );
      }
      ref.invalidate(jobOrdersProvider);
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Non salvata: $error')));
    }
  }
}

final class _JobOrderDraft {
  const _JobOrderDraft({
    required this.code,
    required this.name,
    required this.isActive,
    this.customer,
  });

  final String code;
  final String name;
  final String? customer;
  final bool isActive;
}

class _JobOrderDialog extends StatefulWidget {
  const _JobOrderDialog({this.existing});

  final JobOrderDto? existing;

  @override
  State<_JobOrderDialog> createState() => _JobOrderDialogState();
}

class _JobOrderDialogState extends State<_JobOrderDialog> {
  late final _codeController = TextEditingController(
    text: widget.existing?.code ?? '',
  );
  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final _customerController = TextEditingController(
    text: widget.existing?.customer ?? '',
  );
  late bool _isActive = widget.existing?.isActive ?? true;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _customerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return AlertDialog(
      title: Text(isEditing ? 'Modifica commessa' : 'Nuova commessa'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _codeController,
            // Il codice identifica la commessa nei documenti già emessi:
            // cambiarlo dopo scollegherebbe quel che è già stato stampato.
            enabled: !isEditing,
            maxLength: 64,
            decoration: const InputDecoration(labelText: 'Codice'),
          ),
          TextField(
            controller: _nameController,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Descrizione'),
          ),
          TextField(
            controller: _customerController,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Committente'),
          ),
          if (isEditing)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isActive,
              title: const Text('Commessa aperta'),
              onChanged: (value) => setState(() => _isActive = value),
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
            final code = _codeController.text.trim();
            final name = _nameController.text.trim();
            if (code.isEmpty || name.isEmpty) {
              return;
            }
            Navigator.pop(
              context,
              _JobOrderDraft(
                code: code,
                name: name,
                customer: _customerController.text.trim(),
                isActive: _isActive,
              ),
            );
          },
          child: const Text('Salva'),
        ),
      ],
    );
  }
}

class _WorksitesTab extends ConsumerWidget {
  const _WorksitesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worksites = ref.watch(allWorksitesProvider);

    return Scaffold(
      body: worksites.when(
        data: (items) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: items.isEmpty
              ? const [Text('Nessun cantiere.')]
              : items
                    .map(
                      (item) => Card(
                        child: ListTile(
                          title: Text('${item.code} · ${item.name}'),
                          subtitle: Text(
                            item.jobOrderName ?? 'Commessa non assegnata',
                          ),
                          trailing: item.isActive
                              ? const Icon(Icons.chevron_right)
                              : const Chip(label: Text('Chiuso')),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) =>
                                  WorksiteDetailPage(worksiteId: item.id),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Anagrafica non leggibile: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-worksite',
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo cantiere'),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final jobOrders = ref.read(jobOrdersProvider).value ?? const [];
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<_WorksiteDraft>(
      context: context,
      builder: (context) => _WorksiteDialog(jobOrders: jobOrders),
    );
    if (result == null) {
      return;
    }

    try {
      await ref
          .read(apiClientProvider)
          .createWorksite(
            code: result.code,
            name: result.name,
            address: result.address,
            jobOrderId: result.jobOrderId,
          );
      ref
        ..invalidate(allWorksitesProvider)
        ..invalidate(worksitesProvider);
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Non salvato: $error')));
    }
  }
}

final class _WorksiteDraft {
  const _WorksiteDraft({
    required this.code,
    required this.name,
    this.address,
    this.jobOrderId,
  });

  final String code;
  final String name;
  final String? address;
  final String? jobOrderId;
}

class _WorksiteDialog extends StatefulWidget {
  const _WorksiteDialog({required this.jobOrders});

  final List<JobOrderDto> jobOrders;

  @override
  State<_WorksiteDialog> createState() => _WorksiteDialogState();
}

class _WorksiteDialogState extends State<_WorksiteDialog> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  String? _jobOrderId;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuovo cantiere'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _codeController,
              maxLength: 64,
              decoration: const InputDecoration(labelText: 'Codice'),
            ),
            TextField(
              controller: _nameController,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Descrizione'),
            ),
            TextField(
              controller: _addressController,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Indirizzo'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _jobOrderId,
              decoration: const InputDecoration(
                labelText: 'Commessa (facoltativa)',
              ),
              items: widget.jobOrders
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text('${item.code} · ${item.name}'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() => _jobOrderId = value),
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
            final code = _codeController.text.trim();
            final name = _nameController.text.trim();
            if (code.isEmpty || name.isEmpty) {
              return;
            }
            final address = _addressController.text.trim();
            Navigator.pop(
              context,
              _WorksiteDraft(
                code: code,
                name: name,
                address: address.isEmpty ? null : address,
                jobOrderId: _jobOrderId,
              ),
            );
          },
          child: const Text('Salva'),
        ),
      ],
    );
  }
}

class _MembersTab extends ConsumerWidget {
  const _MembersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(organizationMembersProvider);

    return Scaffold(
      body: members.when(
        data: (items) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Qui non si creano account: si dà accesso a chi si è già '
                  'registrato. L\'identificativo è quello del suo utente.',
                ),
              ),
            ),
            ...items.map(
              (item) => Card(
                child: ListTile(
                  title: Text(item.displayName),
                  subtitle: Text(translateRole(item.role)),
                  trailing: IconButton(
                    tooltip: 'Togli dall\'organizzazione',
                    icon: const Icon(Icons.person_remove_outlined),
                    onPressed: () => _remove(context, ref, item),
                  ),
                  onTap: () => _edit(context, ref, item),
                ),
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Squadra non leggibile: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-member',
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Aggiungi persona'),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    OrganizationMemberDto? existing,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<OrganizationMemberDto>(
      context: context,
      builder: (context) => _MemberDialog(existing: existing),
    );
    if (result == null) {
      return;
    }

    try {
      await ref
          .read(apiClientProvider)
          .upsertOrganizationMember(
            userId: result.userId,
            displayName: result.displayName,
            role: result.role,
          );
      ref.invalidate(organizationMembersProvider);
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Non salvata: $error')));
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    OrganizationMemberDto member,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Togliere ${member.displayName}?'),
        content: const Text(
          'Perde l\'accesso e le assegnazioni ai cantieri. I report che ha '
          'già compilato restano.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Togli'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(apiClientProvider).removeOrganizationMember(member.userId);
      ref.invalidate(organizationMembersProvider);
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Non rimossa: $error')));
    }
  }
}

class _MemberDialog extends StatefulWidget {
  const _MemberDialog({this.existing});

  final OrganizationMemberDto? existing;

  @override
  State<_MemberDialog> createState() => _MemberDialogState();
}

class _MemberDialogState extends State<_MemberDialog> {
  late final _userIdController = TextEditingController(
    text: widget.existing?.userId ?? '',
  );
  late final _nameController = TextEditingController(
    text: widget.existing?.displayName ?? '',
  );
  late String _role = widget.existing?.role ?? 'Worker';

  @override
  void dispose() {
    _userIdController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Aggiungi persona' : 'Modifica persona',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _userIdController,
            enabled: widget.existing == null,
            decoration: const InputDecoration(
              labelText: 'Identificativo utente',
              hintText: '00000000-0000-0000-0000-000000000000',
            ),
          ),
          TextField(
            controller: _nameController,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Nome e cognome'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Ruolo'),
            items:
                const ['Administrator', 'Coordinator', 'CrewLeader', 'Worker']
                    .map(
                      (role) => DropdownMenuItem(
                        value: role,
                        child: Text(translateRole(role)),
                      ),
                    )
                    .toList(growable: false),
            onChanged: (value) => setState(() => _role = value!),
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
            final userId = _userIdController.text.trim();
            final name = _nameController.text.trim();
            if (userId.isEmpty || name.isEmpty) {
              return;
            }
            Navigator.pop(
              context,
              OrganizationMemberDto(
                userId: userId,
                displayName: name,
                role: _role,
              ),
            );
          },
          child: const Text('Salva'),
        ),
      ],
    );
  }
}

String translateRole(String role) => switch (role) {
  'Administrator' => 'Amministratore',
  'Coordinator' => 'Coordinatore',
  'CrewLeader' => 'Caposquadra',
  'Worker' => 'Operatore',
  _ => role,
};
