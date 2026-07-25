# ADR 002 — Supabase Auth e API ASP.NET Core

- Stato: accettata
- Data: 2026-07-25

## Contesto

Il client necessita di sessioni mobile, mentre autorizzazioni e isolamento dei
tenant devono rimanere responsabilità dell'API.

## Decisione

Flutter effettua il login con `supabase_flutter` e invia l'access token
all'API. ASP.NET Core valida il JWT tramite authority Supabase e audience
`authenticated`.

L'identità deriva dal claim `sub`. L'organizzazione selezionata può provenire
dal claim `organization_id` o dall'header `X-Organization-Id`, ma viene sempre
confrontata con `UserMembership`: l'header seleziona un tenant, non concede
accesso.

Le chiavi pubblicabili, gli URL e le connection string arrivano
dall'ambiente. Nessun service-role key viene distribuito al client.

## Conseguenze

Il database non è raggiunto direttamente dall'app. Un utente appartenente a più
organizzazioni deve selezionarne una; con una sola membership l'API può
selezionarla automaticamente.
