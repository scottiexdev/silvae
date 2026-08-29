import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silvae_api_client/silvae_api_client.dart';
import 'package:silvae_app/app/dependencies.dart';
import 'package:silvae_app/app/theme.dart';
import 'package:silvae_app/app/ui.dart';
import 'package:silvae_app/features/documents/presentation/documents_page.dart';
import 'package:silvae_app/features/registry/presentation/worksite_detail_page.dart';

/// Commesse, cantieri, squadra e archivio: l'anagrafica che finora si
/// popolava soltanto chiamando l'API.
class RegistryPage extends StatelessWidget {
  const RegistryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabStrip(['Commesse', 'Cantieri', 'Squadra', 'Archivio']),
          Expanded(
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
      backgroundColor: Colors.transparent,
      body: jobOrders.when(
        data: (items) => items.isEmpty
            ? Center(
                child: EmptyState(
                  icon: Icons.work_outline,
                  title: 'Nessuna commessa',
                  message:
                      'La commessa tiene insieme i cantieri di uno stesso '
                      'lavoro e il committente che lo paga.',
                  action: FilledButton.icon(
                    onPressed: () => _edit(context, ref, null),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Prima commessa'),
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
                        child: _RegistryCard(
                          icon: Icons.work_outline,
                          title: item.name,
                          subtitle: item.customer ?? 'Committente non indicato',
                          facts: [(Icons.tag, item.code)],
                          pill: item.isActive
                              ? null
                              : const StatusPill(
                                  label: 'Chiusa',
                                  tone: Tone.neutral,
                                ),
                          onTap: () => _edit(context, ref, item),
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
          child: ErrorState(title: 'Anagrafica non leggibile', detail: error),
        ),
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
      backgroundColor: Colors.transparent,
      body: worksites.when(
        data: (items) => items.isEmpty
            ? Center(
                child: EmptyState(
                  icon: Icons.terrain_outlined,
                  title: 'Nessun cantiere',
                  message:
                      'Il cantiere si può censire anche prima che la commessa '
                      'sia formalizzata.',
                  action: FilledButton.icon(
                    onPressed: () => _create(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Primo cantiere'),
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
                        child: _RegistryCard(
                          icon: Icons.terrain_outlined,
                          title: item.name,
                          subtitle:
                              item.jobOrderName ?? 'Commessa non assegnata',
                          facts: [
                            (Icons.tag, item.code),
                            if (item.address != null)
                              (Icons.place_outlined, item.address!),
                          ],
                          pill: item.isActive
                              ? null
                              : const StatusPill(
                                  label: 'Chiuso',
                                  tone: Tone.neutral,
                                ),
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
        loading: () => const Padding(
          padding: EdgeInsets.all(Insets.gutter),
          child: LoadingList(rows: 3),
        ),
        error: (error, stackTrace) => Center(
          child: ErrorState(title: 'Anagrafica non leggibile', detail: error),
        ),
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
      backgroundColor: Colors.transparent,
      body: members.when(
        data: (items) => PageBody(
          padding: const EdgeInsets.fromLTRB(
            Insets.gutter,
            Insets.gutter,
            Insets.gutter,
            Insets.bottom,
          ),
          children: [
            const InfoNote(
              'Qui non si creano account: si dà accesso a chi si è già '
              'registrato. L\'identificativo è quello del suo utente.',
              icon: Icons.badge_outlined,
            ),
            gapSections,
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: Insets.gap),
                child: _RegistryCard(
                  icon: _iconForRole(item.role),
                  tone: item.role == 'Administrator' ? Tone.info : Tone.neutral,
                  title: item.displayName,
                  subtitle: translateRole(item.role),
                  facts: const [],
                  trailing: IconButton(
                    tooltip: 'Togli dall\'organizzazione',
                    icon: const Icon(Icons.person_remove_outlined, size: 20),
                    onPressed: () => _remove(context, ref, item),
                  ),
                  onTap: () => _edit(context, ref, item),
                ),
              ),
            ),
          ],
        ),
        loading: () => const Padding(
          padding: EdgeInsets.all(Insets.gutter),
          child: LoadingList(rows: 3),
        ),
        error: (error, stackTrace) => Center(
          child: ErrorState(title: 'Squadra non leggibile', detail: error),
        ),
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

/// La riga dell'anagrafica: la stessa forma per commesse, cantieri e persone,
/// così scorrere da una linguetta all'altra non costa un riorientamento.
class _RegistryCard extends StatelessWidget {
  const _RegistryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.facts,
    this.tone = Tone.neutral,
    this.pill,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Tone tone;
  final String title;
  final String subtitle;
  final List<(IconData, String)> facts;
  final Widget? pill;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SurfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(icon: icon, tone: tone),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              ?pill,
              ?trailing,
              if (pill == null && trailing == null && onTap != null)
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
          if (facts.isNotEmpty) ...[const SizedBox(height: 14), Facts(facts)],
        ],
      ),
    );
  }
}

IconData _iconForRole(String role) => switch (role) {
  'Administrator' => Icons.shield_outlined,
  'Coordinator' => Icons.hub_outlined,
  'CrewLeader' => Icons.engineering_outlined,
  _ => Icons.person_outline,
};

String translateRole(String role) => switch (role) {
  'Administrator' => 'Amministratore',
  'Coordinator' => 'Coordinatore',
  'CrewLeader' => 'Caposquadra',
  'Worker' => 'Operatore',
  _ => role,
};
