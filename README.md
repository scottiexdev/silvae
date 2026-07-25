# Silvae

Silvae è una piattaforma offline-first per la gestione di squadre e cantieri di
manutenzione verde e forestale.

## Struttura

- `src/backend`: API ASP.NET Core organizzata secondo Clean Architecture.
- `src/mobile/silvae_app`: client Flutter per web, Android e iOS.
- `tests`: test di dominio, applicativi e di integrazione.
- `docs`: piano, decisioni architetturali e documentazione di prodotto.

## Prerequisiti

- .NET SDK 10
- Flutter stable

## Verifica locale

```bash
dotnet build Silvae.sln
dotnet test Silvae.sln

cd src/mobile/silvae_app
flutter analyze
flutter test
flutter build web
```

Il piano di implementazione è disponibile in
[`docs/implementation-plan.md`](docs/implementation-plan.md).
