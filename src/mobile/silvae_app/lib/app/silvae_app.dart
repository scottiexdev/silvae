import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF246B45)),
        scaffoldBackgroundColor: const Color(0xFFF6F8F5),
        inputDecorationTheme: const InputDecorationTheme(filled: true),
        useMaterial3: true,
      ),
      routerConfig: configured ? _configuredRouter : _configurationRouter,
    );
  }
}

class _ConfigurationPage extends StatelessWidget {
  const _ConfigurationPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.forest, color: Color(0xFF246B45), size: 56),
                SizedBox(height: 16),
                Text(
                  'Silvae',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text(
                  'Configura Supabase, API e organizzazione tramite '
                  'le variabili --dart-define descritte nel README.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
