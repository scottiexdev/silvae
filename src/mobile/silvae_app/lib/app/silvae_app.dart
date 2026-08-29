import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:silvae_app/app/theme.dart';
import 'package:silvae_app/app/ui.dart';
import 'package:silvae_app/features/authentication/presentation/auth_gate.dart';

final _configuredRouter = GoRouter(
  routes: [GoRoute(path: '/', builder: (context, state) => const AuthGate())],
);

final _configurationRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const _ConfigurationPage()),
  ],
);

class SilvaeApp extends StatelessWidget {
  const SilvaeApp({super.key, this.configured = false});

  final bool configured;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Silvae',
      debugShowCheckedModeBanner: false,
      theme: silvaeTheme(Brightness.light),
      darkTheme: silvaeTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: configured ? _configuredRouter : _configurationRouter,
    );
  }
}

class _ConfigurationPage extends StatelessWidget {
  const _ConfigurationPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Insets.gutter),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(child: BrandMark(size: 52)),
                  const SizedBox(height: Insets.section),
                  Text(
                    'Manca la configurazione',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configura Supabase, API e organizzazione tramite le '
                    'variabili --dart-define descritte nel README.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Insets.section),
                  const SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Variable('SILVAE_SUPABASE_URL'),
                        Divider(height: 24),
                        _Variable('SILVAE_SUPABASE_ANON_KEY'),
                        Divider(height: 24),
                        _Variable('SILVAE_API_BASE_URL'),
                        Divider(height: 24),
                        _Variable('SILVAE_ORGANIZATION_ID'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Variable extends StatelessWidget {
  const _Variable(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Icons.chevron_right,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SelectableText(
            name,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
