import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/utils/gs1_parser.dart';

void main() {
  group('Gs1Parser Tests', () {
    test('Parse DataMatrix with ]d2 and <GS>', () {
      final input = ']d201080320890012362101234567890<GS>1727103010112345678<GS>716098765432';
      final parsed = Gs1Parser.parse(input);
      
      expect(parsed.gtin, '08032089001236');
      expect(parsed.serial, '01234567890');
      expect(parsed.expiry, '271030');
      expect(parsed.batch, '112345678');
      expect(parsed.aic, '098765432');
      expect(parsed.hasValidAic, isTrue);
    });

    test('Parse DataMatrix with ASCII 29', () {
      final input = ']d201080320890012362101234567890\u001D1727103010112345678\u001D716098765432';
      final parsed = Gs1Parser.parse(input);
      
      expect(parsed.gtin, '08032089001236');
      expect(parsed.serial, '01234567890');
      expect(parsed.expiry, '271030');
      expect(parsed.batch, '112345678');
      expect(parsed.aic, '098765432');
    });

    test('GTIN 0803 without AI 716 does NOT produce AIC', () {
      final input = '01080320890012361727103010112345678';
      final parsed = Gs1Parser.parse(input);
      
      expect(parsed.gtin, '08032089001236');
      expect(parsed.aic, isNull);
      expect(parsed.hasValidAic, isFalse);
    });

    test('Campi in ordine diverso', () {
      final input = '716098765432<GS>172710300108032089001236';
      final parsed = Gs1Parser.parse(input);
      
      expect(parsed.aic, '098765432');
      expect(parsed.expiry, '271030');
      expect(parsed.gtin, '08032089001236');
    });

    test('AIC letto parzialmente se separatore presente in anticipo', () {
      final input = '71612345<GS>0108032089001236';
      final parsed = Gs1Parser.parse(input);
      
      expect(parsed.hasValidAic, isFalse); 
      expect(parsed.gtin, '08032089001236');
    });

    test('716 dentro lotto senza separatore NON deve essere letto come AIC', () {
      // AI 10 (Lotto) seguito da numeri che sembrano 716...
      // Poiché 10 è a lunghezza variabile, se non c'è <GS> consuma fino alla fine.
      final input = '010803208900123610AB716123456789';
      final parsed = Gs1Parser.parse(input);
      
      expect(parsed.gtin, '08032089001236');
      expect(parsed.batch, 'AB716123456789'); // Il lotto assorbe tutto
      expect(parsed.hasValidAic, isFalse);
      expect(parsed.aic, isNull);
    });

    test('716 con extra caratteri prima del separatore NON deve essere accettato', () {
      final input = '716012345678XYZ<GS>17251231';
      final parsed = Gs1Parser.parse(input);
      
      expect(parsed.hasValidAic, isFalse);
    });

    test('716 seguito da altri dati senza separatore NON deve essere accettato', () {
      final input = '71601234567817251231';
      final parsed = Gs1Parser.parse(input);
      
      expect(parsed.hasValidAic, isFalse);
    });

    test('AIC deve iniziare per 0 per essere considerato valido', () {
      final input = '716112345678';
      final parsed = Gs1Parser.parse(input);
      
      expect(parsed.aic, isNull);
      expect(parsed.hasValidAic, isFalse);
    });

    test('GTIN senza mapping non deve ingannare e produrre validAic', () {
      final input = '0108032089001236';
      final parsed = Gs1Parser.parse(input);
      
      expect(parsed.gtin, '08032089001236');
      expect(parsed.hasValidAic, isFalse);
    });
  });
}
