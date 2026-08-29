import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silvae_app/app/dependencies.dart';
import 'package:silvae_app/app/theme.dart';
import 'package:silvae_app/app/ui.dart';
import 'package:silvae_app/features/certifications/presentation/safety_page.dart';
import 'package:silvae_app/features/daily_reports/presentation/report_list_page.dart';
import 'package:silvae_app/features/office/presentation/office_page.dart';
import 'package:silvae_app/features/registry/presentation/registry_page.dart';
import 'package:silvae_app/features/worksites/presentation/worksites_page.dart';

/// La cornice dell'app: le sezioni disponibili dipendono dal ruolo, la
/// sincronizzazione e l'uscita restano sempre a portata di mano.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  int _section = 0;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Un tentativo all'apertura: se la rete è tornata mentre l'app era
    // chiusa, la coda si svuota senza che l'operatore debba accorgersene.
    WidgetsBinding.instance.addPostFrameCallback((_) => _synchronize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_synchronize());
    }
  }

  Future<void> _synchronize() async {
    if (_syncing) {
      return;
    }
    setState(() => _syncing = true);
    await ref.read(syncSchedulerProvider).syncNow();
    ref
      ..invalidate(worksitesProvider)
      ..invalidate(dailyReportsProvider);
    if (mounted) {
      setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOffice = ref.watch(isOfficeProvider);
    final sections = _sectionsFor(isOffice: isOffice);
    final current = _section < sections.length ? _section : 0;
    // Su un monitor la barra in basso è a mezzo metro dagli occhi e dal
    // pollice: la stessa navigazione sta meglio in colonna.
    final wide = MediaQuery.sizeOf(context).width >= wideLayout;

    final body = IndexedStack(
      index: current,
      children: sections.map((section) => section.page).toList(growable: false),
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: Insets.gutter,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandMark(size: 28, showName: false),
            const SizedBox(width: 12),
            Text(sections[current].title),
          ],
        ),
        actions: [
          _SyncButton(syncing: _syncing, onPressed: _synchronize),
          IconButton(
            tooltip: 'Esci',
            onPressed: () => ref.read(authGatewayProvider).signOut(),
            icon: const Icon(Icons.logout, size: 20),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: current,
                  onDestinationSelected: (index) =>
                      setState(() => _section = index),
                  labelType: NavigationRailLabelType.all,
                  destinations: sections
                      .map(
                        (section) => NavigationRailDestination(
                          icon: Icon(section.icon),
                          selectedIcon: Icon(section.selectedIcon),
                          label: Text(section.title),
                        ),
                      )
                      .toList(growable: false),
                ),
                VerticalDivider(
                  width: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: current,
              onDestinationSelected: (index) =>
                  setState(() => _section = index),
              destinations: sections
                  .map(
                    (section) => NavigationDestination(
                      icon: Icon(section.icon),
                      selectedIcon: Icon(section.selectedIcon),
                      label: section.title,
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }

  static List<_Section> _sectionsFor({required bool isOffice}) => [
    const _Section(
      'Report',
      Icons.description_outlined,
      Icons.description,
      ReportListPage(),
    ),
    if (isOffice) ...[
      const _Section(
        'Ufficio',
        Icons.inbox_outlined,
        Icons.inbox,
        OfficePage(),
      ),
      const _Section(
        'Anagrafica',
        Icons.folder_outlined,
        Icons.folder,
        RegistryPage(),
      ),
      const _Section(
        'Sicurezza',
        Icons.verified_user_outlined,
        Icons.verified_user,
        SafetyPage(),
      ),
    ] else
      const _Section(
        'Cantieri',
        Icons.terrain_outlined,
        Icons.terrain,
        WorksitesPage(),
      ),
  ];
}

/// La sincronizzazione in corso si vede girare: senza, un tocco a vuoto non si
/// distingue da uno riuscito.
class _SyncButton extends StatelessWidget {
  const _SyncButton({required this.syncing, required this.onPressed});

  final bool syncing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: syncing ? 'Sincronizzazione in corso' : 'Sincronizza',
      onPressed: syncing ? null : onPressed,
      icon: syncing
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sync, size: 20),
    );
  }
}

final class _Section {
  const _Section(this.title, this.icon, this.selectedIcon, this.page);

  final String title;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
}
