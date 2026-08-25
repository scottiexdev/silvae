# Silvae

Silvae è una piattaforma multi-tenant e offline-first per squadre impegnate in
cantieri di manutenzione verde e forestale. Questo repository contiene il primo
vertical slice: login Supabase, cantieri assegnati, rapportino locale, outbox e
sincronizzazione idempotente.

## Struttura

- `src/backend`: API ASP.NET Core secondo i confini Domain, Application,
  Infrastructure e Api.
- `src/mobile/silvae_app`: app Flutter Android/iOS con Riverpod, GoRouter,
  SQLite e Supabase Auth.
- `src/mobile/silvae_api_client`: client Dart tipizzato derivato da OpenAPI.
- `tests`: test di dominio, applicativi, API e persistenza locale.
- `docs/adr`: decisioni architetturali.

## Configurazione

Non inserire segreti nella repository. Copiare i nomi da `.env.example` e usare
variabili d'ambiente o .NET user-secrets.

Il backend usa PostgreSQL quando `ConnectionStrings__Silvae` è valorizzata;
senza connection string usa un database in-memory soltanto in `Development` o
`Testing` e rifiuta l'avvio negli altri ambienti. Configurare l'authority come
`https://<project>.supabase.co/auth/v1`.

Avvio API:

```bash
dotnet run --project src/backend/Silvae.Api
```

Avvio Flutter:

```bash
cd src/mobile/silvae_app
flutter run \
  --dart-define=SILVAE_SUPABASE_URL=https://PROJECT.supabase.co \
  --dart-define=SILVAE_SUPABASE_ANON_KEY=sb_publishable_VALUE \
  --dart-define=SILVAE_API_BASE_URL=https://API_HOST \
  --dart-define=SILVAE_ORGANIZATION_ID=ORGANIZATION_UUID
```

In assenza dei quattro valori l'app mostra una pagina di configurazione e non
prova ad aprire sessioni o database remoti.

## Verifica

```bash
dotnet build Silvae.sln
dotnet test Silvae.sln

cd src/mobile/silvae_app
flutter analyze
flutter test
```

## VS Code

Aprire la cartella repository con Code:

```bash
code E:\Coding\silvae
```

La repo include configurazioni in `.vscode` per build e avvio:

- `Backend API`: builda e avvia l'API ASP.NET Core su `http://localhost:5266`.
- `Flutter Web`: avvia il client Flutter su Chrome senza `--dart-define`, mostrando la pagina di configurazione.
- `Backend API + Flutter Web`: avvia backend e client insieme.
- `Flutter Web Configured`: chiede Supabase URL, anon key, API base URL e organization id.

Da `Terminal > Run Task...` sono disponibili anche `backend: build`,
`backend: test`, `flutter: pub get`, `flutter: analyze`, `flutter: test`,
`flutter: run web` e `flutter: run web configured`.

Prerequisiti locali: .NET SDK 10 (la versione minima è fissata in
`global.json`), Flutter SDK nel `PATH`, estensioni VS Code C# e Flutter/Dart.

Rigenerazione del client Dart (richiede Node.js):

```bash
./scripts/generate-api-client.sh
```

Il contratto è esposto a `/openapi/v1.json`. Il piano completo è in
[`docs/implementation-plan.md`](docs/implementation-plan.md).
