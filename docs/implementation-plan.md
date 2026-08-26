# Silvae — Piano di implementazione

## 1. Obiettivo

Silvae è un SaaS multi-tenant per cooperative e aziende che coordinano squadre operative impegnate in cantieri di manutenzione verde e forestale.

Il primo obiettivo è sostituire il rapportino cartaceo con un flusso mobile affidabile anche senza connessione:

1. l'operatore accede all'app;
2. consulta i cantieri assegnati;
3. apre o riprende il rapportino giornaliero;
4. registra squadra, ore, attività, checklist di sicurezza e foto;
5. salva tutto localmente anche offline;
6. sincronizza i dati quando torna disponibile la rete;
7. l'ufficio consulta ed esporta il rapportino.

## 2. Principi

- Offline-first: il salvataggio locale non dipende dalla rete.
- Mobile-first: Android e iOS sono le piattaforme iniziali supportate.
- Multi-tenant dalla prima versione.
- Monolite modulare prima di eventuali servizi distribuiti.
- Clean Architecture pragmatica: dipendenze rivolte verso il dominio, senza classi cerimoniali prive di comportamento.
- API-first: OpenAPI è il contratto tra backend e client.
- Sicurezza e audit integrati nel modello, non aggiunti successivamente.
- Le funzionalità AI entrano solo dopo la validazione dei flussi core.

## 3. Stack

### Backend

- .NET 10 LTS
- ASP.NET Core Web API
- Entity Framework Core con provider Npgsql
- PostgreSQL gestito da Supabase
- Supabase Auth per identità e token JWT
- Supabase Storage per foto e documenti
- OpenAPI per documentazione e generazione del client Dart
- xUnit, FluentAssertions e Testcontainers per i test

### Client

- Flutter
- Riverpod per stato applicativo e dependency injection
- GoRouter per navigazione
- Dio e client generato da OpenAPI per HTTP
- Drift/SQLite per persistenza locale
- Freezed e json_serializable per modelli e union type
- supabase_flutter per autenticazione
- Firebase Cloud Messaging per notifiche push

Le versioni esatte dei package saranno fissate nei rispettivi lock file durante lo scaffolding.

## 4. Confini architetturali

### Backend

```text
Silvae.Api
    ├── Silvae.Application
    └── Silvae.Infrastructure

Silvae.Infrastructure
    └── Silvae.Application

Silvae.Application
    └── Silvae.Domain

Silvae.Domain
    └── nessuna dipendenza applicativa
```

- `Domain`: entità, value object, invarianti ed eventi di dominio.
- `Application`: use case, porte, autorizzazione applicativa e orchestrazione.
- `Infrastructure`: EF Core, Supabase, storage, autenticazione e servizi esterni.
- `Api`: endpoint HTTP, middleware, dependency injection e OpenAPI.

L'organizzazione interna sarà per feature dove possibile, evitando cartelle globali contenenti decine di handler scollegati.

### Flutter

```text
lib/
├── app/
├── core/
│   ├── auth/
│   ├── database/
│   ├── network/
│   ├── sync/
│   └── files/
└── features/
    ├── authentication/
    ├── worksites/
    ├── daily_reports/
    ├── time_tracking/
    ├── safety/
    └── attachments/
```

Ogni feature può contenere:

```text
feature/
├── domain/
├── application/
├── data/
└── presentation/
```

I DTO generati da OpenAPI rimangono nel layer `data` e vengono convertiti nei modelli del dominio client.

## 5. Modello multi-tenant e sicurezza

- Ogni record aziendale appartiene a una `Organization`.
- L'utente può appartenere a una o più organizzazioni con ruoli distinti.
- Il backend ricava organizzazione e identità dal contesto autenticato; non si fida di valori arbitrari inviati dal client.
- I ruoli iniziali sono `Administrator`, `Coordinator`, `CrewLeader` e `Worker`.
- Tutte le modifiche rilevanti conservano autore e timestamp.
- Il client non accede direttamente alle tabelle PostgreSQL.
- Supabase Auth è usato dal client; l'API valida i JWT.
- Upload e download degli allegati avvengono tramite URL firmati e autorizzati dal backend.

## 6. Strategia offline e sincronizzazione

SQLite è la fonte immediata per l'interfaccia Flutter. Le scritture dell'utente aggiornano prima il database locale e inseriscono un'operazione nella outbox.

```text
UI → use case → repository locale → SQLite
                              └──→ outbox

outbox → API di sincronizzazione → PostgreSQL → conferma → SQLite
```

Ogni operazione sincronizzabile contiene almeno:

- `operationId`, generato dal client;
- `organizationId`;
- `entityId`, generato prima del salvataggio locale;
- tipo di entità e tipo di operazione;
- versione attesa dell'entità;
- payload;
- data di creazione locale;
- numero di tentativi e ultimo errore;
- stato `pending`, `processing`, `synced` o `failed`.

Il backend registra gli `operationId` elaborati per rendere sicuri i retry. I conflitti non vengono risolti con il solo confronto dei timestamp: ogni aggregate sincronizzabile usa una versione incrementale e una politica esplicita.

Le foto vengono conservate inizialmente sul dispositivo, compresse secondo una configurazione controllata e caricate separatamente dai dati del rapportino.

## 7. Contratto API

ASP.NET Core produce il documento OpenAPI. Da questo viene generato un package Dart tipizzato contenente DTO e chiamate HTTP.

```text
Endpoint .NET
    → openapi.json
    → generatore
    → client Dart
    → adapter/repository Flutter
```

Il codice generato:

- non viene modificato manualmente;
- non viene usato direttamente dai widget;
- può essere rigenerato con un singolo comando ripetibile;
- viene verificato in CI per individuare contratti non aggiornati.

## 8. Struttura prevista della repository

```text
silvae/
├── src/
│   ├── backend/
│   │   ├── Silvae.Api/
│   │   ├── Silvae.Application/
│   │   ├── Silvae.Domain/
│   │   └── Silvae.Infrastructure/
│   └── mobile/
│       ├── silvae_app/
│       └── silvae_api_client/
├── tests/
│   ├── Silvae.Domain.Tests/
│   ├── Silvae.Application.Tests/
│   ├── Silvae.IntegrationTests/
│   └── mobile/
├── docs/
│   ├── adr/
│   └── product/
├── scripts/
├── Silvae.sln
└── README.md
```

## 9. Roadmap

### Milestone 0 — Fondazioni — completata

- Creare solution .NET e progetti con dipendenze corrette.
- Creare applicazione Flutter per Android e iOS.
- Configurare formattazione, analisi statica, test e CI.
- Configurare ambienti locali senza inserire segreti nella repository.
- Aggiungere health check e primo test di integrazione PostgreSQL.
- Pubblicare OpenAPI e generare il primo client Dart.
- Scrivere gli ADR per stack, autenticazione e strategia offline.

**Completata quando:** backend, test e app Flutter compilano in CI; il client generato chiama un endpoint autenticato di prova.

### Milestone 1 — Primo vertical slice — completata

- Autenticazione Supabase.
- Organizzazioni, utenti e ruoli.
- Anagrafica minima di commesse e cantieri.
- Elenco dei cantieri assegnati all'operatore.
- Creazione e modifica del rapportino giornaliero.
- Database SQLite locale.
- Outbox e primo ciclo push/pull.
- Stato visibile `salvato sul dispositivo` / `sincronizzato` / `errore`.

**Completata quando:** su un telefono in modalità aereo è possibile creare un rapportino, chiudere e riaprire l'app, ritrovare i dati e sincronizzarli una sola volta al ritorno della rete.

### Milestone 2 — Rapportino MVP

**Blocker urgente, scoperto in fase di primo deploy (2026-08-26):** il
database locale usa `sqflite`, che su Flutter Web non ha alcuna
implementazione — `getDatabasesPath()`/`openDatabase()` lanciano
un'eccezione non gestita all'avvio, prima ancora di disegnare la UI. Il
sito statico `silvae-web` costruito da `scripts/render-build-web.sh` e
pubblicato su Render è quindi **inutilizzabile così com'è**: mostra una
pagina bianca a ogni utente. Va risolto prima di considerare qualunque
altro punto di questa milestone, aggiungendo il supporto web al database
locale (es. `sqflite_common_ffi_web`, o un backend alternativo condizionato
su `kIsWeb`) in
[`local_database.dart`](../src/mobile/silvae_app/lib/core/database/local_database.dart).
Nota anche la tensione con la sezione 12, che rinvia esplicitamente il
supporto web Flutter: il Blueprint Render lo dà per scontato, la roadmap
no — va riconciliato quando si risolve il blocker.

Prerequisito non previsto originariamente, ora risolto: l'anagrafica è
scrivibile. Il bootstrap della prima organizzazione (ADR 004), i membri, le
commesse, i cantieri e le assegnazioni sono endpoint autorizzati per ruolo, e
un ambiente vuoto si popola via HTTP. Mancano le schermate corrispondenti:
oggi ci si passa chiamando l'API.

Il contenuto del rapportino esiste sul backend: squadra con le ore,
lavorazioni, checklist di sicurezza, stati e audit di chi li ha mossi
(ADR 005). Restano l'interfaccia e le parti che dipendono da scelte ancora
aperte.

- Schermate di anagrafica per commesse, cantieri e squadre.
- Schermata di compilazione del rapportino: squadra, ore, attività e
  checklist.
- Foto geolocalizzate.
- Firma o conferma del caposquadra.
- Gestione esplicita dei conflitti.

**Completata quando:** un rapportino reale della cooperativa può essere compilato integralmente senza carta.

### Milestone 3 — Ufficio e rendicontazione

- Vista coordinatore dei rapportini.
- Ricerca e filtri per commessa, cantiere, squadra e data.
- Correzione o riapertura controllata.
- Export PDF e formato tabellare concordato con la cooperativa.
- Archivio documenti e autorizzazioni del cantiere.
- Competenze e certificazioni per persona: patentino motosega, abilitazione
  trattore, corso DPI e sicurezza, con ente rilasciante, data di rilascio,
  scadenza e attestato allegato.
- Avvisi sulle certificazioni in scadenza ed estrazione per ispezione.

La validità di una certificazione va conservata come intervallo, non come stato
corrente. Un'ispezione su lavori di otto mesi fa chiede se l'operatore era
abilitato in quella data, non se lo è oggi: uno schema che tiene soltanto
`scadenza` risponde alla domanda sbagliata e va corretto quando i dati storici
esistono già.

**Completata quando:** l'ufficio può produrre la rendicontazione richiesta partendo esclusivamente dai dati di Silvae e, davanti a un ente finanziatore o a un RSPP, mostrare le certificazioni valide degli operatori presenti in cantiere alle date dichiarate.

### Milestone 4 — Pianificazione e comunicazione

- Calendario e mappa dei cantieri.
- Competenze richieste dal cantiere.
- Assegnazione delle squadre, con verifica delle competenze e blocco esplicito
  quando un operatore non è abilitato alla lavorazione prevista.
- Disponibilità, ferie e orari.
- Notifiche push.
- Comandi testuali o vocali interpretati dall'AI, con conferma umana prima dell'invio.

Questa milestone inizia solo dopo l'uso reale e il feedback sull'MVP.

## 10. Strategia di test

- Test di dominio per invarianti e transizioni di stato.
- Test applicativi per autorizzazioni e use case.
- Test di integrazione dell'API contro PostgreSQL reale tramite container.
- Contract test per OpenAPI e client Dart generato.
- Test Flutter di repository, use case e stato Riverpod.
- Widget test per i flussi critici.
- Test manuali ed end-to-end su dispositivi Android e iOS reali.
- Scenari obbligatori: modalità aereo, chiusura forzata, token scaduto, upload interrotto, retry e doppio invio.

## 11. Osservabilità e gestione errori

- Logging strutturato con correlation ID.
- Un identificativo di sync collega operazione mobile e richiesta backend.
- Errori tecnici separati dai messaggi mostrati all'operatore.
- Metriche minime: sync riusciti/falliti, durata, dimensione outbox e upload falliti.
- Crash reporting attivato prima del pilot con utenti reali.

## 12. Decisioni rinviate

- Portale web amministrativo separato.
- Provider definitivo per mappe.
- Firma con valore legale.
- Fatturazione e gestione abbonamenti.
- Motore di job distribuito.
- Funzionalità AI successive alla pianificazione.
- Supporto desktop e web Flutter.
- Espansione internazionale.

Queste scelte verranno prese sulla base dei requisiti emersi dal pilot, non anticipate nell'MVP.

## 13. Primo backlog implementativo

1. Scaffolding della repository e build ripetibile.
2. ADR 001: architettura e dipendenze.
3. ADR 002: autenticazione Supabase con API ASP.NET Core.
4. ADR 003: protocollo offline e sincronizzazione.
5. Endpoint `GET /api/me`.
6. Generazione del client Dart dall'OpenAPI.
7. Login Flutter e persistenza sicura della sessione.
8. Entità `Organization`, `UserMembership`, `Worksite` e `DailyReport`.
9. Elenco cantieri locale/remoto.
10. Creazione offline del primo rapportino.
11. Outbox e sincronizzazione idempotente.
12. Test end-to-end in modalità aereo.

Il vertical slice verrà esteso soltanto dopo aver dimostrato questo ciclo completo.
