# Silvae — note per lo sviluppo

Piattaforma multi-tenant offline-first per cantieri di manutenzione verde e
forestale. Il piano completo è in [`docs/implementation-plan.md`](docs/implementation-plan.md).

## Stato

Milestone 0 e 1 complete. Il ciclo offline funziona ed è coperto da test:
creazione e modifica del rapportino sul dispositivo, outbox, push/pull
idempotente, conflitti, sincronizzazione automatica con attesa crescente.

L'anagrafica è scrivibile: bootstrap della prima organizzazione, membri,
commesse, cantieri e assegnazioni, tutto con autorizzazione per ruolo. Un
database vuoto si popola via HTTP.

Il rapportino ha il suo contenuto: squadra con le ore, lavorazioni, checklist
di sicurezza, transizioni `Draft` → `Submitted` → `Approved` → `Reopened` e
audit di chi le ha fatte (ADR 005). L'invio passa dalla coda perché avviene in
cantiere; approvazione e riapertura hanno endpoint diretti.

Manca l'interfaccia. Né l'anagrafica né il rapportino nuovo hanno schermate:
tutto questo si esercita chiamando l'API, e l'app continua a sincronizzare il
rapportino minimo della Milestone 1.

L'app gira su Flutter Web: il database locale sceglie l'implementazione per
piattaforma, verificato in un browser fino alla schermata di accesso.

**Nessuno l'ha però mai visto girare davvero con dati veri.** Lo stack di pubblicazione
(Render + Supabase) è pronto e verificato in CI, ma non è mai stato eseguito:
non esiste ancora un progetto Supabase. Manca anche il modo di provarlo in
locale, perché senza Supabase non esiste un'identità: servirebbe
un'autenticazione di sviluppo ristretta a `Development`.

## Decisioni aperte

- **Client Dart generato.** Il piano lo prevede, ma non è mai stato attivato:
  vedi sotto.
- **Checklist di sicurezza.** Le voci arrivano dal dispositivo identificate da
  un codice; non esiste ancora una checklist per organizzazione che dica quali
  voci siano obbligatorie.

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

## File generati

Migrazioni EF e `docs/openapi.json` non si scrivono a mano. In locale servono
`dotnet ef`; altrimenti c'è il workflow `tools`, avviabile a mano da GitHub
Actions, che li rigenera e li committa sul branch da cui parte.

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
  con la stessa versione attesa produrrebbero un conflitto garantito.
- Un **409 non si ritenta**: l'operazione esce dalla coda con stato
  `conflict`.
- La sincronizzazione **non ascolta la connettività di sistema**: un'interfaccia
  di rete attiva non dice che l'API sia raggiungibile, mentre un tentativo
  riuscito lo dimostra.
