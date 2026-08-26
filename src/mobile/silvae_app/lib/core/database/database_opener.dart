// Sceglie l'implementazione di SQLite in base alla piattaforma. `sqflite` non
// ha alcuna implementazione web: senza questa scelta `LocalDatabase.open()`
// lancerebbe un'eccezione all'avvio, prima di disegnare la UI.
export 'database_opener_io.dart'
    if (dart.library.js_interop) 'database_opener_web.dart';
