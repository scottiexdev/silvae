# Deploy Silvae su Render e Supabase

## Architettura

```text
silvae-web.onrender.com    Flutter Web statico (demo e ufficio)
          |
          v
silvae-api.onrender.com    ASP.NET Core .NET 10 su Docker
          |
          v
Supabase                   PostgreSQL, Auth e in futuro Storage
```

Il Blueprint `render.yaml` crea entrambi i servizi Render. Supabase resta
esterno e fornisce sia il database sia l'identità: l'API non emette token, si
limita a validare i JWT firmati da Supabase Auth.

L'app Android e iOS non passa da Render. Il sito statico serve per mostrare
Silvae da browser senza installare nulla; il canale di distribuzione mobile
verrà deciso separatamente.

## 1. Valori da Supabase

Dal progetto Supabase servono tre valori.

**Connection string.** In **Project Settings → Database → Connection string**,
formato .NET oppure URI. Preferire la modalità *session* del pooler: l'API
esegue le migrazioni EF Core all'avvio e la modalità *transaction* (porta 6543)
non supporta le prepared statement, quindi richiederebbe di disabilitarle in
Npgsql. Con la modalità session non serve alcuna configurazione aggiuntiva.

**Authority.** L'URL del progetto con il suffisso di Auth:

```text
https://<project>.supabase.co/auth/v1
```

**Publishable key.** In **Project Settings → API**, la chiave `sb_publishable_`.
È pensata per stare nel client e finisce nel bundle Flutter; non usare mai la
service-role key, che non deve lasciare il backend.

Nessuno di questi valori va salvato nel repository.

## 2. Creazione del Blueprint Render

Nel Dashboard Render:

1. aprire **Blueprints** e scegliere **New Blueprint Instance**;
2. collegare il repository GitHub `silvae`;
3. selezionare il branch `main` e il file `render.yaml`;
4. inserire le variabili richieste durante la creazione.

| Servizio | Variabile | Valore |
| --- | --- | --- |
| `silvae-api` | `ConnectionStrings__Silvae` | connection string Supabase |
| `silvae-api` | `Authentication__Authority` | `https://<project>.supabase.co/auth/v1` |
| `silvae-api` | `SILVAE_ALLOWED_ORIGINS` | `https://silvae-web.onrender.com` |
| `silvae-web` | `SILVAE_API_BASE_URL` | `https://silvae-api.onrender.com` |
| `silvae-web` | `SILVAE_SUPABASE_URL` | `https://<project>.supabase.co` |
| `silvae-web` | `SILVAE_SUPABASE_ANON_KEY` | chiave `sb_publishable_` |
| `silvae-web` | `SILVAE_ORGANIZATION_ID` | UUID dell'organizzazione |

`Authentication__Audience` vale già `authenticated` nel Blueprint e non va
inserita a mano.

Se Render cambia uno dei due nomi perché già occupato, completare la creazione
e correggere gli URL incrociati nelle pagine **Environment** dei due servizi.

## 3. Ordine e verifica

Attendere prima il deploy dell'API e verificare:

```text
https://silvae-api.onrender.com/api/health
```

Attendere poi la build dello Static Site e aprire
`https://silvae-web.onrender.com`. Al primo accesso l'API sul piano free può
impiegare circa un minuto a riattivarsi. Questo pesa meno che altrove perché
l'app è offline-first: il rapportino viene scritto su SQLite e la outbox
ritenta la sincronizzazione.

## 4. Comportamento dei deploy

- Ogni push su `main` avvia i deploy interessati.
- All'avvio l'API applica le migrazioni EF Core sul database Supabase.
- Senza `ConnectionStrings__Silvae` l'API rifiuta di partire fuori da
  Development e Testing: un deploy mal configurato fallisce subito invece di
  girare su un database in memoria.
- In Production CORS accetta soltanto le origin elencate in
  `SILVAE_ALLOWED_ORIGINS`, separabili con virgola o punto e virgola. Senza
  quella variabile ogni origin viene rifiutata.
- L'API si fida di `X-Forwarded-For` e `X-Forwarded-Proto` perché sta dietro
  al proxy di Render.

## 5. Segreti

Non inserire mai nel repository:

- la connection string Supabase;
- la service-role key;
- token amministrativi Render o Supabase.

Il bundle Flutter contiene soltanto URL pubblico dell'API, URL Supabase e
publishable key, tutti valori destinati al client.

## 6. Limiti noti

`SILVAE_ORGANIZATION_ID` è una `--dart-define`, quindi viene compilata dentro il
bundle: il sito statico serve una sola organizzazione e una seconda cooperativa
richiede una seconda build. Per il pilot va bene, ma è incompatibile con un
prodotto multi-tenant e va risolto scegliendo l'organizzazione a runtime, dalle
membership restituite da `GET /api/me`.
