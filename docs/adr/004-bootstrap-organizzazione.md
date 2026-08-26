# ADR 004 — Bootstrap della prima organizzazione

- Stato: accettata
- Data: 2026-08-26

## Contesto

Gli endpoint di anagrafica richiedono di essere già amministratori
dell'organizzazione su cui si scrive. Un utente appena registrato su Supabase
non appartiene invece ad alcuna organizzazione: `GET /api/me` gli risponde 403
e non esiste alcun modo, dall'interno del modello dei ruoli, di creare la prima
membership. Su un database vuoto il prodotto non è raggiungibile da nessuno.

Le uscite valutate erano tre: un endpoint protetto da un segreto di deploy, un
sistema di inviti, oppure la prima riga inserita a mano nel database.

Gli inviti non risolvono il problema: presuppongono un amministratore che
inviti. L'inserimento manuale funziona ma non è verificabile in CI e richiede
l'accesso SQL al progetto Supabase ogni volta che nasce un tenant.

## Decisione

`POST /api/bootstrap/organization` crea l'organizzazione e rende amministratore
l'utente autenticato che ha effettuato la chiamata. Richiede due cose insieme:
un JWT Supabase valido e l'header `X-Bootstrap-Secret` uguale alla variabile
d'ambiente `SILVAE_BOOTSTRAP_SECRET`.

Il segreto non configurato chiude l'endpoint con 403: è la condizione normale
di un ambiente già inizializzato, e un ambiente che non ha ancora deciso di
essere inizializzato non deve poterlo essere da chiunque possieda un account.
Il confronto avviene a tempo costante.

L'identità dell'amministratore viene dal token, mai dal corpo della richiesta:
il segreto autorizza l'operazione, non dice chi la compie.

## Conseguenze

Il segreto vive solo nella configurazione del servizio, allo stesso livello
della connection string, e chi lo possiede è chi ha configurato l'ambiente.
Chi lo ottenesse potrebbe creare organizzazioni nuove, ma non entrare in quelle
esistenti: le membership restano governate dai ruoli.

Dopo il bootstrap l'amministratore aggiunge le persone con
`PUT /api/organization/members/{userId}`, usando l'identificativo dell'utente
Supabase, che deve essersi già registrato. Il passaggio è scomodo e resta tale
finché non esistono gli inviti, previsti più avanti: questa decisione non li
sostituisce, li precede.

Un'organizzazione non può restare senza amministratori: l'ultimo non può essere
né degradato né rimosso. Senza quel vincolo l'unico modo di rientrare sarebbe
il segreto di deploy, che sul telefono di chi resta non c'è.
