import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:silvae_app/features/home/presentation/home_page.dart';

final _router = GoRouter(
  routes: [GoRoute(path: '/', builder: (context, state) => const HomePage())],
);

class SilvaeApp extends StatelessWidget {
  const SilvaeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Silvae',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF246B45)),
        scaffoldBackgroundColor: const Color(0xFFF6F8F5),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
