import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/aifa_pdf_parser.dart';

void main() {
  test('posologia uses the leaflet block matching the selected package', () {
    final text = [
      'BUSCOPAN 10 mg compresse rivestite',
      '1. Che cos\'è BUSCOPAN e a cosa serve',
      'Indicazioni delle compresse rivestite.',
      '2. Cosa deve sapere prima di prendere BUSCOPAN',
      'Avvertenze delle compresse rivestite.',
      '3. Come prendere BUSCOPAN',
      'Posologia corretta per le compresse rivestite. '
          'Questo testo rappresenta il blocco orale e deve essere scelto '
          'quando la confezione selezionata contiene compresse rivestite.',
      'Se prende più BUSCOPAN di quanto deve',
      'Sovradosaggio compresse.',
      '4. Possibili effetti indesiderati',
      'Effetti delle compresse.',
      '5. Come conservare BUSCOPAN',
      'Conservazione compresse.',
      'BUSCOPAN 20 mg/ml soluzione iniettabile',
      '1. Che cos\'è BUSCOPAN e a cosa serve',
      'Indicazioni della soluzione iniettabile.',
      '2. Cosa deve sapere prima di usare BUSCOPAN',
      'Avvertenze della soluzione iniettabile.',
      '3. Come usare BUSCOPAN',
      'Posologia sbagliata della soluzione iniettabile. '
          'Questo testo non deve essere mostrato quando sono state scelte '
          'le compresse rivestite nella lista delle confezioni.',
      '4. Possibili effetti indesiderati',
      'Effetti della soluzione iniettabile.',
      '5. Come conservare BUSCOPAN',
      'Conservazione soluzione iniettabile.',
    ].join('\n');

    final result = AifaPdfParser.extractSectionTextForTest(
      text,
      AifaSectionType.posologia,
      'BUSCOPAN 10 mg COMPRESSA RIVESTITA - SCOPOLAMINA BUTILBROMURO',
    );

    expect(result, contains('Posologia corretta per le compresse rivestite'));
    expect(result, isNot(contains('soluzione iniettabile')));
    expect(result, isNot(contains('Se prende più BUSCOPAN di quanto deve')));
  });
}
