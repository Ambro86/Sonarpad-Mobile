import 'package:flutter_test/flutter_test.dart';
import 'package:sonarpad_mobile_starter/services/aifa_service.dart';

void main() {
  test('AIFA registry parser reads semicolon CSV and deduplicates drug names', () {
    const csv = '\ufeffAIC;Denominazione Medicinale;Principio Attivo\r\n'
        '001;Aspirina;Acido acetilsalicilico\r\n'
        '002;Aspirina;Acido acetilsalicilico\r\n'
        '003;Zirtec;Cetirizina\r\n';

    expect(
      AifaDrugRegistryCsvParser.parseNames(csv),
      equals(const ['Aspirina', 'Zirtec']),
    );
  });

  test('AIFA registry parser handles quoted delimiters and comma CSV', () {
    const csv = 'AIC,Nome farmaco,Descrizione\n'
        '001,"Acido, Test","campo, con virgola"\n'
        '002,Brufen,Altro\n';

    expect(
      AifaDrugRegistryCsvParser.parseNames(csv),
      equals(const ['Acido, Test', 'Brufen']),
    );
  });
}
