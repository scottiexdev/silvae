import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silvae_app/app/dependencies.dart';
import 'package:silvae_app/app/ui.dart';
import 'package:silvae_app/features/authentication/presentation/login_page.dart';
import 'package:silvae_app/features/home/presentation/home_shell.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(authStateProvider)
        .when(
          data: (signedIn) => signedIn ? const HomeShell() : const LoginPage(),
          loading: () => const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BrandMark(size: 44),
                  SizedBox(height: 24),
                  SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ),
            ),
          ),
          error: (error, stackTrace) => Scaffold(
            body: Center(
              child: ErrorState(
                title: 'Sessione non disponibile',
                detail: error,
              ),
            ),
          ),
        );
  }
}
