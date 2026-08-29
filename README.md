# Silvae

Silvae è una piattaforma multi-tenant e offline-first per squadre impegnate in
cantieri di manutenzione verde e forestale: login Supabase, anagrafica,
compilazione del report di cantiere offline con foto geolocalizzate, outbox e
sincronizzazione idempotente, vista d'ufficio con export e archivio delle
abilitazioni.

Nell'interfaccia e nel codice recente il documento giornaliero si chiama
**report**. Gli ADR scritti prima lo chiamano «rapportino»: è la stessa cosa.

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

## L'app

Le sezioni dipendono dal ruolo letto da `GET /api/me`. Chi lavora in cantiere
vede **Report** e **Cantieri**; amministratori e coordinatori vedono anche
**Ufficio**, **Anagrafica** e **Sicurezza**. Il ruolo decide cosa l'app mostra,
non cosa concede: quello lo decide il backend, che lo rilegge dalla membership
a ogni richiesta.

- **Report**: quel che c'è sul dispositivo, con lo stato della sincronizzazione
  e la compilazione completa. Un report modificato anche altrove non si
  sovrascrive da solo: apre una schermata che mette a confronto le due versioni,
  entrambe già sul dispositivo, e chiede quale tenere.
- **Cantieri**: i cantieri assegnati, con le autorizzazioni da mostrare a chi le
  chiede sul posto.
- **Ufficio**: tutti i report dell'organizzazione, filtrabili per commessa,
  cantiere, persona in squadra, periodo e stato, con approvazione, riapertura ed
  export negli stessi filtri.
- **Anagrafica**: commesse, cantieri, squadra e archivio dei documenti.
- **Sicurezza**: abilitazioni delle persone, avvisi di scadenza ed estrazione
  per l'ispezione.

Su Android e iOS l'app chiede fotocamera e posizione la prima volta che si
allega una foto. Il permesso negato non blocca niente: la foto viene allegata
senza coordinate.

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

## Report di cantiere

Il report contiene cantiere, data, note, squadra con le ore, lavorazioni
eseguite, checklist di sicurezza e foto geolocalizzate, e percorre gli stati
`Draft`, `Submitted`, `Approved` e `Reopened` registrando in un audit chi lo ha
mosso e quando. Le regole sono in
[`docs/adr/005-contenuto-del-rapportino.md`](docs/adr/005-contenuto-del-rapportino.md).

L'invio richiede la conferma del caposquadra: chi invia digita il proprio nome
e conferma che ore, lavorazioni e sicurezza sono corrette. Riaprire il report
cancella la conferma, perché copriva il contenuto di allora.

Delle foto il server registra la scheda — riferimento sul dispositivo,
posizione e istante dello scatto — mentre i byte restano sul telefono, come
previsto dalla strategia offline. Il caricamento su storage a oggetti arriva
quando servirà vedere le foto dall'ufficio.

Quello che accade in cantiere passa dalla coda di sincronizzazione, perché deve
funzionare senza rete: `POST /api/sync/push` accetta le operazioni `upsert` e
`submit`, entrambe con versione attesa e identificativo che le rende ripetibili
senza duplicati. L'upsert sostituisce il contenuto del report; una lista
assente dal payload lascia intatta quella già registrata, una lista vuota la
cancella. Il payload di `submit` porta invece la sola conferma del caposquadra.

Quello che accade in ufficio è online e passa da endpoint diretti.

| Metodo | Percorso | Cosa fa |
| --- | --- | --- |
| `GET` | `/api/daily-reports` | elenco filtrabile per `jobOrderId`, `worksiteId`, `crewUserId`, `from`, `to`, `status` |
| `GET` | `/api/daily-reports/export.csv` | rendicontazione tabellare, una riga per persona e giornata |
| `GET` | `/api/daily-reports/export.pdf` | la stessa rendicontazione da stampare |
| `GET` | `/api/daily-reports/{id}` | scheda con squadra, attività, sicurezza, foto e audit |
| `POST` | `/api/daily-reports/{id}/submit` | invia il report, con la conferma nel corpo |
| `POST` | `/api/daily-reports/{id}/approve` | approva, riservato ad `Administrator` e `Coordinator` |
| `POST` | `/api/daily-reports/{id}/reopen` | riapre un report inviato o approvato |

Un report senza squadra o senza conferma non può essere inviato, una persona
non può comparire due volte, le ore stanno fra 0 escluso e 24 e una voce di
sicurezza non conforme richiede una nota.

## Abilitazioni e archivio

La validità di un'abilitazione è un intervallo, non uno stato corrente:
un'ispezione su lavori di otto mesi fa chiede se l'operatore era abilitato
*quel giorno*.

| Metodo | Percorso | Cosa fa |
| --- | --- | --- |
| `GET` `POST` | `/api/certifications` | elenca e registra le abilitazioni |
| `PUT` `DELETE` | `/api/certifications/{id}` | corregge o rimuove |
| `GET` | `/api/certifications/expiring?withinDays=60` | scadute e in scadenza |
| `GET` | `/api/certifications/inspection?from=&to=&worksiteId=` | per ogni giornata dichiarata, chi c'era e con quali abilitazioni valide a quella data |
| `GET` `POST` | `/api/documents` | archivio: autorizzazioni di cantiere e attestati |
| `GET` | `/api/documents/{id}/content` | scarica il file |
| `DELETE` | `/api/documents/{id}` | lo toglie dall'archivio |

I documenti stanno in Postgres con un tetto di 10 MB per file: sono poche
decine di PDF per organizzazione e così non servono né storage a oggetti né URL
firmati. Se l'archivio cresce, il contenuto passa allo storage e nel database
resta la chiave.

## Verifica

```bash
dotnet build Silvae.sln
dotnet test Silvae.sln

cd src/mobile/silvae_app
dart format --output=none --set-exit-if-changed lib test ../silvae_api_client/lib
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
