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

Per la versione web serve `web/sqlite3.wasm`: il database locale è SQLite
compilato in WebAssembly. È già nella repository; si rigenera con

```bash
cd src/mobile/silvae_app
dart run sqflite_common_ffi_web:setup --force && rm -f web/sqflite_sw.js
```

## Anagrafica e primo accesso

Su un database vuoto nessuno appartiene a un'organizzazione e `GET /api/me`
risponde 403 a chiunque. La prima organizzazione, con il suo amministratore,
nasce da `POST /api/bootstrap/organization`, che richiede insieme un token
Supabase valido e l'header `X-Bootstrap-Secret` uguale a
`SILVAE_BOOTSTRAP_SECRET`. Senza quella variabile l'endpoint è chiuso. La
decisione è in
[`docs/adr/004-bootstrap-organizzazione.md`](docs/adr/004-bootstrap-organizzazione.md),
la procedura in [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md).

Da lì l'anagrafica si scrive via API. Commesse, cantieri e assegnazioni sono
riservati ad `Administrator` e `Coordinator`; i membri dell'organizzazione al
solo `Administrator`.

| Metodo | Percorso | Cosa fa |
| --- | --- | --- |
| `GET` | `/api/organization/members` | elenca chi appartiene all'organizzazione |
| `PUT` | `/api/organization/members/{userId}` | aggiunge una persona o ne cambia ruolo e nome |
| `DELETE` | `/api/organization/members/{userId}` | la toglie, insieme alle sue assegnazioni |
| `GET` `POST` | `/api/job-orders` | elenca e crea commesse |
| `PATCH` | `/api/job-orders/{id}` | rinomina, cambia cliente, chiude o riapre |
| `GET` | `/api/worksites` | i cantieri assegnati; con `?includeInactive=true` anche i chiusi, per chi coordina |
| `POST` | `/api/worksites` | crea un cantiere, con o senza commessa |
| `GET` `PATCH` | `/api/worksites/{id}` | scheda con la squadra; rinomina, sposta di commessa, chiude o riapre |
| `PUT` `DELETE` | `/api/worksites/{id}/assignments/{userId}` | assegna o toglie un operatore |

L'identificativo di una persona è quello del suo utente Supabase: l'API concede
l'accesso a un account che esiste, non lo crea. L'ultimo amministratore non può
essere né degradato né rimosso.

## Rapportino

Il rapportino contiene cantiere, data, note, squadra con le ore, lavorazioni
eseguite e checklist di sicurezza, e percorre gli stati `Draft`, `Submitted`,
`Approved` e `Reopened` registrando in un audit chi lo ha mosso e quando. Le
regole sono in
[`docs/adr/005-contenuto-del-rapportino.md`](docs/adr/005-contenuto-del-rapportino.md).

Quello che accade in cantiere passa dalla coda di sincronizzazione, perché deve
funzionare senza rete: `POST /api/sync/push` accetta le operazioni `upsert` e
`submit`, entrambe con versione attesa e identificativo che le rende ripetibili
senza duplicati. L'upsert sostituisce il contenuto del rapportino; una lista
assente dal payload lascia intatta quella già registrata, una lista vuota la
cancella.

Quello che accade in ufficio è online e passa da endpoint diretti.

| Metodo | Percorso | Cosa fa |
| --- | --- | --- |
| `GET` | `/api/daily-reports/{id}` | scheda con squadra, attività, sicurezza e audit |
| `POST` | `/api/daily-reports/{id}/submit` | invia il rapportino |
| `POST` | `/api/daily-reports/{id}/approve` | approva, riservato ad `Administrator` e `Coordinator` |
| `POST` | `/api/daily-reports/{id}/reopen` | riapre un rapportino inviato o approvato |

Un rapportino senza squadra non può essere inviato, una persona non può
comparire due volte, le ore stanno fra 0 escluso e 24 e una voce di sicurezza
non conforme richiede una nota.

L'app non compila ancora questi campi: le schermate arrivano dopo, e fino ad
allora il rapportino sincronizzato dal telefono resta quello minimo.

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
