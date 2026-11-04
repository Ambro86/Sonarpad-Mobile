import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/l10n/app_localizations.dart';
import 'package:sonarpad_mobile_starter/screens/italiaonline_screen.dart';

void main() {
  testWidgets('phone mode exposes phone entry and hides the irrelevant location', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ItaliaOnlineScreen(),
    ));
    expect(find.text('Località, indirizzo (opzionale)'), findsOneWidget);
    await tester.tap(find.text('Cerca per numero di telefono'));
    await tester.pumpAndSettle();
    expect(find.text('Numero di telefono, completo di prefisso'), findsOneWidget);
    expect(find.text('Località, indirizzo (opzionale)'), findsNothing);
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.keyboardType, TextInputType.phone);
    await tester.enterText(find.byType(TextField).first, 'abc');
    await tester.tap(find.text('Cerca'));
    await tester.pumpAndSettle();
    expect(find.byType(ItaliaOnlineResultsScreen), findsNothing);
    expect(find.text('Inserisci un numero di telefono italiano valido.'), findsOneWidget);
  });
}
