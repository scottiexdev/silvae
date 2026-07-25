# ADR 001 — Monolite modulare e dipendenze

- Stato: accettata
- Data: 2026-07-25

## Contesto

Il primo prodotto deve evolvere rapidamente senza perdere i confini tra dominio,
casi d'uso, persistenza e trasporto HTTP.

## Decisione

Il backend è un monolite modulare .NET con dipendenze
`Api → Application ← Infrastructure` e `Application → Domain`.
Il dominio non dipende da framework. L'organizzazione interna segue le feature;
le astrazioni condivise restano limitate alle porte effettivamente usate.

Il client Flutter converte i DTO API in modelli locali e considera SQLite la
fonte immediata della UI.

## Conseguenze

Deployment e transazioni restano semplici. I confini sono verificabili dai
project reference e consentono in futuro di estrarre un modulo solo in presenza
di una necessità osservata.
