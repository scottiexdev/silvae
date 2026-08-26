# ADR 005 — Contenuto del rapportino e transizioni di stato

- Stato: accettata
- Data: 2026-08-26

## Contesto

Il rapportino della Milestone 1 conteneva cantiere, data, note e nient'altro:
abbastanza per provare il ciclo offline, non per sostituire la carta. Il
contenuto vero è la squadra con le ore, le lavorazioni eseguite e la checklist
di sicurezza, e il documento deve percorrere gli stati `Draft`, `Submitted`,
`Approved` e `Reopened` lasciando traccia di chi lo ha mosso.

## Decisione

**Il rapportino è un aggregato.** Squadra, attività, voci di sicurezza e audit
appartengono al rapportino, si caricano con lui e si salvano con lui.

**L'upsert sostituisce il contenuto, non lo fonde.** Il dispositivo possiede la
versione offline del documento e la invia per intero. Una fusione lato server
contraddirebbe la outbox, che accorpa le modifiche successive allo stesso
rapportino in un'unica operazione: quello che arriva è già il risultato di
tutte le modifiche fatte in cantiere.

**Una lista assente dal payload significa «non toccare»; una lista presente,
anche vuota, sostituisce.** Un client che non conosce ancora una parte del
rapportino sincronizza il resto senza cancellarla. È la stessa distinzione
usata dalle modifiche parziali dell'anagrafica.

**L'invio passa dalla coda, l'approvazione no.** `submit` è un'operazione di
sincronizzazione come `upsert`, con la stessa versione attesa e la stessa
protezione contro i doppioni: il caposquadra chiude il rapportino in cantiere,
dove la rete non c'è. Approvazione e riapertura avvengono in ufficio, online, e
usano endpoint diretti; esiste anche un endpoint di invio, per chi lavora dal
browser.

**L'audit vive dentro l'aggregato ed è in sola aggiunta.** Ogni creazione,
modifica e transizione registra azione, autore, versione e istante. Nessun
metodo lo modifica o lo cancella.

**Le regole che il dominio impone**: un rapportino senza squadra non si invia,
la stessa persona non compare due volte, le ore stanno fra 0 escluso e 24, una
voce di sicurezza non conforme richiede una nota, e solo una bozza o un
rapportino riaperto si possono modificare.

## Conseguenze

Chi appartiene alla squadra deve appartenere all'organizzazione, verificato al
momento della sincronizzazione: le ore di un estraneo finirebbero nella
rendicontazione di un tenant che non lo conosce. Non è invece richiesto che sia
assegnato al cantiere, perché capita di dare una mano per un giorno solo.

La checklist di sicurezza non ha ancora un modello: il dispositivo invia le voci
che conosce, identificate da un codice. Quando esisterà una checklist per
organizzazione, i codici diventeranno il suo riferimento.

Foto geolocalizzate e firma del caposquadra restano fuori: richiedono
rispettivamente lo storage degli allegati e una scelta sul valore della firma,
entrambe ancora da fare.
