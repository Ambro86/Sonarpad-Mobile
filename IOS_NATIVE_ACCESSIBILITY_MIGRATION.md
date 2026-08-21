# Sonarpad Mobile — accessibilità liste iOS e modello UI condiviso

Data: 18 agosto 2026

## Stato

La prima migrazione UIKit ha confermato su dispositivo che VoiceOver attraversa correttamente le liste e che lo scroll a tre dita torna a funzionare. La seconda fase elimina la necessità di mantenere una descrizione iOS separata dalla descrizione Android.

## Architettura attuale

Le superfici scorrevoli usano un modello Dart condiviso (`AccessibleListRow`, `AccessibleListSection`, `UniversalAccessibleList` e gli equivalenti grid). Lo stesso modello viene consumato da due renderer:

- UIKit su iOS in modalità predefinita (`UITableView` / `UICollectionView`).
- Flutter su Android.

Servizi, stato, callback, preferiti, player, API, database e navigazione restano in Dart.

Il bridge centrale è `lib/widgets/universal_accessible_view.dart`; `lib/widgets/native_ios_accessible_view.dart` è mantenuto soltanto come re-export compatibile. UIKit resta implementato in `ios/Runner/SonarpadNativeAccessibleView.swift`.

## Un solo interruttore globale

`SONARPAD_ACCESSIBLE_RENDERER` accetta:

- `native` (default): modello condiviso + UIKit su iOS.
- `flutter`: modello condiviso + Flutter anche su iOS.
- `legacy`: vecchie definizioni Flutter per confronto/rollback.

Questo permette di testare una futura correzione Apple/Flutter senza modificare le schermate.

## Eventi condivisi

Entrambi i renderer emettono gli stessi eventi Dart:

- `activate`
- `toggle`
- `slider`
- `picker`
- `textChanged`
- `customAction`
- `refresh`

Di conseguenza il wiring funzionale di una schermata è unico. Il modello supporta anche callback direttamente sulle righe.

## Focus condiviso

`AccessibleListController` supporta `scrollTo` e `focusTo` sia con UIKit sia con il renderer Flutter. `initialFocusId` appartiene allo stesso contratto. Restano quindi coperti i fix già verificati per segnalibro Documenti e giorno corrente del Calendario.

## Copertura

L'audit individua 65 file Dart con superfici scorrevoli principali. Tutti e 65 hanno un percorso tramite il modello condiviso. Nessuna schermata decide direttamente se usare UIKit: la decisione iOS è confinata al renderer centrale.

## Android

La cartella `android/` e i file `pubspec.yaml` / `pubspec.lock` non vengono modificati dal refactoring. Android continua a usare Flutter; in modalità normale riceve però dati e azioni dallo stesso modello Dart usato dal renderer UIKit di iOS.

La modalità `legacy` conserva il comportamento Flutter precedente come rete di sicurezza durante i test di regressione.

## Regola di sviluppo

Nuove funzioni e nuovi elementi vanno aggiunti al modello condiviso. Non creare nuovi rami `if (iOS)` nelle schermate. Il contratto automatico in `test/universal_accessible_renderer_contract_test.dart` controlla questa regola.
