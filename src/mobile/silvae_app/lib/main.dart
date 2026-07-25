import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silvae_app/app/dependencies.dart';
import 'package:silvae_app/app/silvae_app.dart';
import 'package:silvae_app/core/auth/auth_gateway.dart';
import 'package:silvae_app/core/auth/secure_session_storage.dart';
import 'package:silvae_app/core/database/local_database.dart';
import 'package:silvae_app/core/network/api_factory.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SILVAE_SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SILVAE_SUPABASE_ANON_KEY');
  const apiBaseUrl = String.fromEnvironment('SILVAE_API_BASE_URL');
  const organizationId = String.fromEnvironment('SILVAE_ORGANIZATION_ID');
  final configured =
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      apiBaseUrl.isNotEmpty &&
      organizationId.isNotEmpty;

  if (!configured) {
    runApp(const ProviderScope(child: SilvaeApp()));
    return;
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      localStorage: SecureSessionStorage(),
    ),
  );
  final client = Supabase.instance.client;
  final localDatabase = await LocalDatabase.open();
  final apiClient = createApiClient(
    baseUrl: apiBaseUrl,
    organizationId: organizationId,
    accessToken: () => client.auth.currentSession?.accessToken ?? '',
  );

  runApp(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(localDatabase),
        apiClientProvider.overrideWithValue(apiClient),
        organizationIdProvider.overrideWithValue(organizationId),
        authGatewayProvider.overrideWithValue(SupabaseAuthGateway(client)),
      ],
      child: const SilvaeApp(configured: true),
    ),
  );
}
