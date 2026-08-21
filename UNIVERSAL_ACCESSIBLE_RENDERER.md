# Sonarpad Mobile — modello UI accessibile condiviso

Data: 18 agosto 2026

## Principio

Le schermate scorrevoli descrivono una sola volta contenuti e comportamento in Dart tramite:

- `AccessibleListRow`
- `AccessibleListSection`
- `UniversalAccessibleList`
- `AccessibleGridItem`
- `UniversalAccessibleGrid`

Il renderer è scelto centralmente in `lib/widgets/universal_accessible_view.dart`.

- iOS, modalità predefinita: UIKit (`UITableView` / `UICollectionView`).
- Android, modalità predefinita: Flutter, usando lo stesso modello Dart.
- Logica, dati e callback restano condivisi.

La cartella nativa `android/` non viene modificata.

## Modalità globali

La modalità si sceglie con un solo `dart-define`:

```text
SONARPAD_ACCESSIBLE_RENDERER=native
SONARPAD_ACCESSIBLE_RENDERER=flutter
SONARPAD_ACCESSIBLE_RENDERER=legacy
```

`native` è il default: modello condiviso; UIKit su iOS, Flutter su Android.

`flutter`: modello condiviso e renderer Flutter anche su iOS. Serve per verificare in futuro se Flutter/iOS hanno corretto il problema senza tornare al vecchio codice per schermata.

`legacy`: usa le definizioni Flutter precedenti al refactoring. È una rete di sicurezza e un riferimento di confronto, non il percorso da modificare per nuove funzioni.

Esempi:

```bash
flutter run --dart-define=SONARPAD_ACCESSIBLE_RENDERER=flutter
flutter run --dart-define=SONARPAD_ACCESSIBLE_RENDERER=legacy
```

## Regola per le modifiche future

Per aggiungere o cambiare un elemento di una lista/form, modificare il modello condiviso della schermata. Non aggiungere condizioni `Platform.isIOS`, `TargetPlatform.iOS` o `useNativeIosAccessibleViews` nelle schermate.

Gli eventi del renderer (`activate`, `toggle`, `slider`, `picker`, `textChanged`, `customAction`, `refresh`) vengono riportati allo stesso handler Dart sia da UIKit sia dal renderer Flutter.

`AccessibleListRow` supporta anche callback direttamente sulla riga (`onActivate`, `onValueChanged`, `onCustomAction`). Per una presentazione Flutter molto particolare è disponibile `flutterChild`: consente di mantenere un widget Material personalizzato senza duplicare identità, etichetta o wiring nativo dell'elemento.

## Focus e scrolling

`AccessibleListController` espone le stesse API indipendentemente dal renderer:

```dart
controller.scrollTo('row_id');
controller.focusTo('row_id');
```

Su iOS/renderer nativo le chiamate arrivano a UIKit. Sul renderer Flutter vengono gestite dal componente condiviso. `initialFocusId` è anch'esso parte del modello comune.

Questo mantiene nello stesso contratto casi come il paragrafo del segnalibro, il giorno corrente del calendario e i selettori che devono portare un elemento in vista.

## Compatibilità

`lib/widgets/native_ios_accessible_view.dart` resta come semplice re-export per compatibilità, ma il nuovo import da usare è:

```dart
import '../widgets/universal_accessible_view.dart';
```

Il test `test/universal_accessible_renderer_contract_test.dart` impedisce di reintrodurre nelle schermate riferimenti diretti al renderer iOS o ai vecchi nomi `NativeIos...`.
