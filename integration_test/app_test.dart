import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sonarpad_mobile_starter/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app should launch without crashing', (tester) async {
    // Lancia l'app principale
    await app.main();
    await tester.pumpAndSettle();

    // Se l'app non crascia durante main(), questo test passerà.
    // Verifichiamo che venga renderizzato qualcosa che non sia un errore vuoto.
    expect(find.byType(app.SonarpadApp), findsOneWidget);
  });
}
