# Silvae — note per lo sviluppo

Piattaforma multi-tenant offline-first per cantieri di manutenzione verde e
forestale. Il piano completo è in [`docs/implementation-plan.md`](docs/implementation-plan.md).

## Stato

Milestone 0, 1, 2 e 3 complete.

**Si dice «report», non «rapportino».** Vale per l'interfaccia e per il codice;
gli ADR e le parti più vecchie del piano dicono ancora «rapportino» ed è la
stessa cosa. Il tipo resta `DailyReport`.

Il ciclo offline funziona ed è coperto da test: creazione e modifica del report
sul dispositivo, outbox, push/pull idempotente, conflitti, sincronizzazione
automatica con attesa crescente.

L'anagrafica è scrivibile e ha le sue schermate: bootstrap della prima
organizzazione, membri, commesse, cantieri e assegnazioni, tutto con
autorizzazione per ruolo.

Il report si compila dall'app per intero: squadra con le ore, lavorazioni,
checklist di sicurezza, foto geolocalizzate, note, conferma del caposquadra e
transizioni `Draft` → `Submitted` → `Approved` → `Reopened` con l'audit di chi
le ha fatte (ADR 005). L'invio passa dalla coda perché avviene in cantiere;
approvazione e riapertura hanno endpoint diretti.

L'ufficio ha la sua vista: elenco filtrabile per commessa, cantiere, persona in
squadra, periodo e stato, approvazione e riapertura, export CSV e PDF sugli
stessi filtri. Ci sono le abilitazioni delle persone con validità a intervallo,
gli avvisi di scadenza, l'estrazione per l'ispezione e l'archivio dei documenti.

**Delle foto il server tiene solo la scheda**: riferimento sul dispositivo,
posizione e istante. I byte restano nel database locale, come previsto dalla
sezione 6 del piano. Nessuno le vede dall'ufficio finché non esiste il
caricamento su storage a oggetti.

L'app gira su Flutter Web: il database locale sceglie l'implementazione per
piattaforma, verificato in un browser fino alla schermata di accesso. La build
web passa anche con fotocamera, posizione e scelta file.

Il progetto Supabase esiste (`rodlenfqlzhuthbmgtrh.supabase.co`) e ha lo
schema migrato. C'è un'organizzazione di prova, `ScottieOrgTest`
(`d64f5091-7885-48f6-9d57-7aeb7cde37ed`), con un utente amministratore
(`scottie`), inserita direttamente via SQL invece che tramite
`POST /api/bootstrap/organization`, per evitare di maneggiare il segreto di
deploy. Il database resta comunque privo di Row Level Security su tutte le
tabelle: va abilitata con delle policy prima di esporre l'app a chiunque
abbia solo la chiave pubblica.

Il frontend Flutter Web non è ancora stato ripubblicato con
`SILVAE_ORGANIZATION_ID` valorizzato su questa organizzazione, quindi nessuno
l'ha ancora visto girare davvero con dati veri end-to-end nel browser. Manca
anche il modo di provarlo in locale, perché senza Supabase non esiste
un'identità: servirebbe un'autenticazione di sviluppo ristretta a
`Development`.

## Decisioni aperte

- **Client Dart generato.** Il piano lo prevede, ma non è mai stato attivato:
  vedi sotto.
- **Checklist di sicurezza.** Le voci arrivano dal dispositivo identificate da
  un codice, e l'elenco è una costante in
  [`daily_report.dart`](src/mobile/silvae_app/lib/features/daily_reports/domain/daily_report.dart),
  uguale per tutti. Non esiste ancora una checklist per organizzazione che dica
  quali voci siano obbligatorie.
- **Tracciato della rendicontazione.** CSV e PDF ricalcano il foglio presenze
  cartaceo, una riga per persona e giornata. Non è ancora stato confrontato con
  chi lo compila oggi in cooperativa.
- **Foto e documenti nel database.** Le foto stanno nel SQLite del dispositivo
  e non salgono mai; i documenti dell'archivio stanno in Postgres con un tetto
  di 10 MB. Entrambi passano allo storage a oggetti quando servirà vedere le
  foto dall'ufficio o quando l'archivio crescerà.
- **RLS disabilitata su Supabase.** Tutte le tabelle sono esposte alla chiave
  pubblica `sb_publishable_` senza alcuna policy: chi la prende dal bundle web
  può interrogare Postgres direttamente, bypassando l'autorizzazione per
  ruolo dell'API .NET. Vanno scritte delle policy (verosimilmente "deny all"
  su `anon`/`authenticated`, dato che oggi l'unico accesso legittimo passa
  dalla connection string dell'API, non da questa chiave) prima di esporre
  l'app a chiunque.

## Trappole note

Sono tutte cose che hanno già rotto la CI almeno una volta.

- **Le chiavi le genera il dominio, non il database.** Ogni entità con `Id`
  `Guid` va dichiarata `ValueGeneratedNever()`: senza, EF vede una chiave già
  valorizzata, conclude che la riga esiste e prova un UPDATE invece di un
  INSERT. Il sintomo arriva al primo aggiornamento di un aggregato con figli:
  `Attempted to update or delete an entity that does not exist in the store`.
- **Nomi dei test in PascalCase**, senza underscore: `CA1707` è un errore, non
  un avviso, perché `TreatWarningsAsErrors` è attivo.
- **Non formattare Dart a mano.** `dart format` non solo spezza le righe
  lunghe, le *riunisce* quando ci stanno: contare le colonne non basta.
  Eseguirlo e basta.
- **`flutter analyze` fallisce anche sui semplici `info`**, non solo sugli
  errori.
- **Sul web il database locale non usa il worker condiviso.**
  `databaseFactoryFfiWeb` fallisce l'apertura con `unsupported result null`:
  il `sqflite_sw.js` precompilato non risponde alla `openDatabase` di
  `sqflite_common`. Si usa `databaseFactoryFfiWebNoWebWorker`, che gira
  sull'isolate principale. Serve `web/sqlite3.wasm`, che produce
  `dart run sqflite_common_ffi_web:setup`: senza, l'app web muore all'avvio.
- **Le migrazioni EF sono codice generato** e `.editorconfig` le esenta dagli
  analizzatori, altrimenti una migrazione appena prodotta non compila
  (`CA1861`). Il `Dockerfile` deve quindi copiare `.editorconfig`, altrimenti
  la build del container applica regole diverse da quelle della build normale.
- **`scripts/generate-api-client.sh` non è utilizzabile.** Il generatore
  `dart-dio` produrrebbe un package `built_value` incompatibile con il client
  scritto a mano in `src/mobile/silvae_api_client`, e romperebbe tutti i punti
  di chiamata. L'allineamento è garantito dal job `contract`.
- **Il PDF ha bisogno dei font nel container.** QuestPDF disegna con Skia, che
  su Linux li cerca attraverso fontconfig: il `Dockerfile` installa
  `fontconfig` e `fonts-dejavu-core`. Il job `container` non se ne
  accorgerebbe, perché avvia l'immagine e chiede solo `/api/health`: a
  proteggere l'export c'è un test di integrazione che ne verifica i byte.
- **Riverpod 3 non ha più `StateProvider`.** Uno stato scrivibile è un
  `NotifierProvider` con la sua `Notifier`; `.notifier).state = ...` non
  compila più. È così che si scrive `reportFilterProvider`.
- **Lo schema SQLite dei test è quello dell'app.**
  `LocalDatabase.createSchema` è pubblico apposta: la copia scritta a mano che
  c'era prima si è scollegata al primo campo aggiunto e i test hanno smesso di
  provare quel che gira sul telefono.
- **Le operazioni in coda sullo stesso report si passano la versione.** Una
  `synchronize()` legge la outbox tutta insieme, ma ogni push confermato alza
  la versione dell'entità: l'operazione successiva va inviata con quella nuova,
  sia in memoria dentro il ciclo sia sulle righe ancora in coda
  (`markSynced`). Senza, ogni invio compilato offline dopo una modifica arriva
  in conflitto.

## File generati

Migrazioni EF e `docs/openapi.json` non si scrivono a mano. In locale servono
`dotnet ef`; altrimenti c'è il workflow `tools`, avviabile a mano da GitHub
Actions, che li rigenera e li committa sul branch da cui parte.

**Le migrazioni non si rigenerano più.** Vale da quando esiste un ambiente
pubblicato: `silvae-api` applica `MigrateAsync()` all'avvio, e Postgres tiene
in `__EFMigrationsHistory` gli id già applicati. Sostituire una migrazione con
una rigenerata le dà un id nuovo, EF la crede da applicare e ricrea tabelle che
esistono già — l'avvio muore con `relation "organizations" already exists` e
Render tiene su l'istanza vecchia, quindi il deploy sembra sano mentre serve
codice di ieri. È già successo il 2026-08-26. Da qui in avanti ogni modifica al
modello aggiunge una migrazione incrementale.

Nessun job di CI copre questo caso: `container` avvia l'immagine senza
connection string, quindi le migrazioni non girano, e gli altri partono da un
database vuoto. Nessuno prova ad aggiornare un database che ha già lo schema
precedente.

Due controlli in CI impediscono la deriva: `has-pending-model-changes` verifica
che modello e migrazioni coincidano, e un confronto verifica che il contratto
pubblicato dall'API corrisponda a `docs/openapi.json`.

## Verifica

```bash
dotnet build Silvae.sln && dotnet test Silvae.sln

cd src/mobile/silvae_app
dart format --output=none --set-exit-if-changed lib test ../silvae_api_client/lib
flutter analyze
flutter test
```

La CI ha quattro job: `backend`, `contract`, `mobile`, `container`.
Quest'ultimo builda l'immagine e verifica che risponda su `/api/health`.

## Scelte da non rimettere in discussione senza motivo

- Il **bootstrap del primo amministratore** passa da un endpoint protetto dal
  segreto di deploy `SILVAE_BOOTSTRAP_SECRET` (ADR 004). Gli inviti verranno
  dopo, non al posto suo.
- **L'ultimo amministratore non si degrada e non si rimuove**: senza
  amministratori l'organizzazione si riaprirebbe solo con il segreto di
  deploy, che sul telefono di chi resta non c'è.
- L'**upsert del rapportino sostituisce il contenuto**, non lo fonde. Una lista
  assente dal payload significa «non toccare», una lista vuota cancella
  (ADR 005).
- L'**invio del rapportino passa dalla coda** come le modifiche; approvazione e
  riapertura no. La prima cosa succede in cantiere, le altre in ufficio.
- Il legame cantiere→commessa è **facoltativo**: un cantiere può essere
  censito prima che la commessa sia formalizzata.
- Le modifiche successive allo stesso rapportino **confluiscono
  nell'operazione già in coda** invece di accodarne una seconda: due upsert
  con la stessa versione attesa produrrebbero un conflitto garantito. Vale solo
  fra `upsert`: un `submit` già in coda viene dopo e resta dov'è.
- Un **409 non si ritenta**: l'operazione esce dalla coda con stato
  `conflict`. La risolve una persona scegliendo fra le due versioni, che sono
  entrambe già sul dispositivo — il pull mette da parte la copia del server
  invece di scartarla — così la decisione si prende anche senza rete.
- La **conferma del caposquadra è un nome digitato**, non un disegno. Una firma
  con valore legale resta fra le decisioni rinviate, e un tratto a schermo non
  è più probante. Riaprire il report la cancella: copriva il contenuto di
  allora.
- La **correzione d'ufficio passa dalla riapertura**, non da un endpoint di
  modifica dedicato: il report torna in mano al cantiere e si corregge con la
  stessa schermata e la stessa coda, con l'audit che tiene il percorso.
- La **validità di un'abilitazione è un intervallo**, mai uno stato corrente.
  L'ispezione chiede chi era abilitato *quel giorno*.
- La sincronizzazione **non ascolta la connettività di sistema**: un'interfaccia
  di rete attiva non dice che l'API sia raggiungibile, mentre un tentativo
  riuscito lo dimostra.
