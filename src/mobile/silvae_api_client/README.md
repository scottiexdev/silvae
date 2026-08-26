# Silvae API client

Package Dart tipizzato che segue il contratto OpenAPI dell'API Silvae.

I file sotto `lib/src` sono **scritti a mano**. Il piano prevede di generarli
da OpenAPI, ma il generatore non è mai stato attivato: `dart-dio` produce un
package basato su `built_value`, con una struttura e una superficie diverse da
queste, quindi eseguire `scripts/generate-api-client.sh` oggi sostituirebbe il
client e romperebbe tutti i punti di chiamata dell'app.

Nel frattempo l'allineamento è garantito dal controllo `contract` in CI, che
confronta il documento pubblicato dall'API con `docs/openapi.json`: il
contratto non può cambiare senza un aggiornamento deliberato dell'istantanea,
che è il momento in cui va aggiornato anche questo package.
