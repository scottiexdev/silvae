import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AuthGateway {
  bool get signedIn;

  Stream<bool> get authChanges;

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();
}

final class SupabaseAuthGateway implements AuthGateway {
  const SupabaseAuthGateway(this._client);

  final SupabaseClient _client;

  @override
  bool get signedIn => _client.auth.currentSession != null;

  @override
  Stream<bool> get authChanges async* {
    yield signedIn;
    yield* _client.auth.onAuthStateChange.map((event) => event.session != null);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
