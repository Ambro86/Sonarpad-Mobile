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

  test('posologia filters tablet and suppository subsections', () {
    final text = [
      'BUSCOPAN 10 mg compresse rivestite e supposte',
      '1. Che cos\'è BUSCOPAN e a cosa serve',
      'Indicazioni.',
      '2. Cosa deve sapere prima di prendere BUSCOPAN',
      'Avvertenze.',
      '3. Come prendere BUSCOPAN',
      'La dose raccomandata per adulti e ragazzi oltre i 14 anni è:',
      'Compresse rivestite',
      '1-2 compresse rivestite 3 volte al giorno.',
      'Le compresse devono essere assunte intere.',
      'Supposte',
      '1 supposta 3 volte al giorno.',
      'Le supposte devono essere liberate dall\'involucro.',
      'Se prende più BUSCOPAN di quanto deve',
      'Sovradosaggio.',
      '4. Possibili effetti indesiderati',
      'Effetti.',
      '5. Come conservare BUSCOPAN',
      'Conservazione.',
    ].join('\n');

    final tabletResult = AifaPdfParser.extractSectionTextForTest(
      text,
      AifaSectionType.posologia,
      'BUSCOPAN 10 mg COMPRESSA RIVESTITA - SCOPOLAMINA BUTILBROMURO',
    );
    final suppositoryResult = AifaPdfParser.extractSectionTextForTest(
      text,
      AifaSectionType.posologia,
      'BUSCOPAN 10 mg SUPPOSTA - SCOPOLAMINA BUTILBROMURO',
    );

    expect(tabletResult, contains('1-2 compresse rivestite'));
    expect(tabletResult, isNot(contains('1 supposta')));
    expect(suppositoryResult, contains('1 supposta'));
    expect(suppositoryResult, isNot(contains('1-2 compresse rivestite')));
    expect(suppositoryResult, isNot(contains('Se prende più BUSCOPAN')));
  });
}
