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

## Prima prova interattiva

L'API non espone ancora endpoint di scrittura per organizzazioni, commesse e
cantieri: su un database vuoto `GET /api/me` risponde 403 e la schermata dei
rapportini resta inutilizzabile. In Development l'avvio inserisce quindi i dati
minimi, purché sia valorizzata `SILVAE_SEED_USER_ID` con l'id dell'utente
Supabase, cioè il claim `sub` del suo token.

1. Creare un progetto Supabase e, in **Authentication → Users**, un utente con
   email e password.
2. Copiarne l'id e avviare l'API con `SILVAE_SEED_USER_ID` valorizzata.
3. Avviare il client passando `SILVAE_ORGANIZATION_ID` con l'organizzazione di
   prova, che ha sempre lo stesso id:

```text
5117ae00-0000-4000-8000-000000000001
```

L'app mostrerà due cantieri sotto la commessa `C-2026-001`, sui quali si può
creare un rapportino, modificarlo e sincronizzarlo.

Il seed non fa nulla se l'organizzazione di prova esiste già, quindi riavviare
l'API non duplica niente e non sovrascrive quanto fatto nella prova precedente.
Fuori da Development non viene mai eseguito: creare da sé una membership da
amministratore significherebbe fabbricare un accesso.

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

## Pubblicazione

Il repository contiene `render.yaml`, che definisce due servizi Render:

- `silvae-api`, Web Service Docker per l'API ASP.NET Core;
- `silvae-web`, Static Site che builda il client Flutter Web.

Il database e l'identità restano su Supabase. L'API applica le migrazioni EF
Core all'avvio e, senza `ConnectionStrings__Silvae`, rifiuta di partire fuori
da Development e Testing.

La procedura completa, con le variabili da inserire nel pannello Render, è in
[`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md).

## File derivati

Le migrazioni EF Core e `docs/openapi.json` sono prodotti da strumenti, non
scritti a mano. Per rigenerarli si avvia a mano il workflow `tools` da GitHub
Actions, che li rigenera e li committa sul branch da cui è partito. Serve
quando cambia il modello di dominio o il contratto HTTP.

Due controlli in CI impediscono la deriva: `dotnet ef
migrations has-pending-model-changes` verifica che il modello e le migrazioni
coincidano, e il confronto fra il documento pubblicato dall'API e
`docs/openapi.json` verifica che il contratto non cambi di nascosto.

Rigenerazione del client Dart (richiede Node.js):

```bash
./scripts/generate-api-client.sh
```

Il contratto è esposto a `/openapi/v1.json`. Il piano completo è in
[`docs/implementation-plan.md`](docs/implementation-plan.md).
