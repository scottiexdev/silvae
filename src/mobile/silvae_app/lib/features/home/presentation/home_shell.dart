import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silvae_app/app/dependencies.dart';
import 'package:silvae_app/app/silvae_app.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.forest, color: silvaeGreen),
            const SizedBox(width: 8),
            Text(sections[current].title),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sincronizza',
            onPressed: _syncing ? null : _synchronize,
            icon: _syncing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: 'Esci',
            onPressed: () => ref.read(authGatewayProvider).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(
        index: current,
        children: sections
            .map((section) => section.page)
            .toList(growable: false),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: current,
        onDestinationSelected: (index) => setState(() => _section = index),
        destinations: sections
            .map(
              (section) => NavigationDestination(
                icon: Icon(section.icon),
                label: section.title,
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  static List<_Section> _sectionsFor({required bool isOffice}) => [
    const _Section('Report', Icons.description_outlined, ReportListPage()),
    if (isOffice) ...[
      const _Section('Ufficio', Icons.inbox_outlined, OfficePage()),
      const _Section('Anagrafica', Icons.folder_outlined, RegistryPage()),
      const _Section('Sicurezza', Icons.verified_user_outlined, SafetyPage()),
    ] else
      const _Section('Cantieri', Icons.terrain_outlined, WorksitesPage()),
  ];
}

final class _Section {
  const _Section(this.title, this.icon, this.page);

  final String title;
  final IconData icon;
  final Widget page;
}
