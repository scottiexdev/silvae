# Silvae — note per lo sviluppo

Piattaforma multi-tenant offline-first per cantieri di manutenzione verde e
forestale. Il piano completo è in [`docs/implementation-plan.md`](docs/implementation-plan.md).

## Stato

Milestone 0 e 1 complete. Il ciclo offline funziona ed è coperto da test:
creazione e modifica del rapportino sul dispositivo, outbox, push/pull
idempotente, conflitti, sincronizzazione automatica con attesa crescente.

**Nessuno l'ha però mai visto girare davvero.** L'API non espone endpoint di
scrittura per organizzazioni, commesse e cantieri, quindi su un database vuoto
`GET /api/me` risponde 403 e la schermata dei rapportini non ha nulla su cui
lavorare. Sbloccare questo è il prossimo passo e il prerequisito della
Milestone 2.

Lo stack di pubblicazione (Render + Supabase) è pronto e verificato in CI, ma
non è mai stato eseguito: non esiste ancora un progetto Supabase.

## Decisioni aperte

- **Bootstrap del primo amministratore.** Un utente Supabase appena registrato
  non appartiene a nessuna organizzazione, ma gli endpoint di anagrafica
  richiedono di esserne già amministratori. Le uscite valutate: endpoint
  protetto da un segreto di deploy, inviti, oppure la prima riga inserita a
  mano una tantum. Non ancora scelta.
- **Client Dart generato.** Il piano lo prevede, ma non è mai stato attivato:
  vedi sotto.

## Trappole note

Sono tutte cose che hanno già rotto la CI almeno una volta.

- **Nomi dei test in PascalCase**, senza underscore: `CA1707` è un errore, non
  un avviso, perché `TreatWarningsAsErrors` è attivo.
- **Non formattare Dart a mano.** `dart format` non solo spezza le righe
  lunghe, le *riunisce* quando ci stanno: contare le colonne non basta.
  Eseguirlo e basta.
- **`flutter analyze` fallisce anche sui semplici `info`**, non solo sugli
  errori.
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
