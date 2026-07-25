# ADR 003 — Outbox offline e sincronizzazione

- Stato: accettata
- Data: 2026-07-25

## Contesto

Il lavoro sul campo non può dipendere dalla connettività e i retry non devono
duplicare i rapportini.

## Decisione

La creazione di un rapportino e della relativa operazione outbox avviene nella
stessa transazione SQLite. Gli ID di entità e operazione sono UUID generati sul
dispositivo.

Il push invia `operationId`, tenant, entità, versione attesa e payload. Il
backend conserva l'operazione processata con una chiave univoca
`(organizationId, operationId)`. Un retry restituisce il risultato originale.
Una versione attesa diversa da quella corrente produce HTTP 409 e non applica
una strategia last-write-wins.

Il pull è incrementale rispetto al tempo server dell'ultimo pull completato.
Una modifica locale ancora in outbox non viene sovrascritta dal pull.

## Conseguenze

Gli stati `device`, `processing`, `synced` ed `error` sono persistenti e visibili
alla UI. I conflitti restano espliciti e potranno ricevere una UX dedicata nel
Milestone 2.
