#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
L10N = ROOT / 'lib' / 'l10n'

TEXTS = {
    'it': {
        'pyannoteCandidateValidation5x10m': 'Valida step 2 + padding 0,35 su 5 spezzoni da 10 minuti',
        'pyannoteCandidateValidationPreparing': 'Validazione pyannote in corso su 5 spezzoni del film...',
        'pyannoteCandidateValidationPassed': 'Validazione completata: step 2 + padding 0,35 ha superato i criteri di sicurezza. Controlla il log per i dettagli.',
        'pyannoteCandidateValidationFailed': 'Validazione completata: step 2 + padding 0,35 non ha superato tutti i criteri di sicurezza. Controlla il log per i dettagli.',
    },
    'en': {
        'pyannoteCandidateValidation5x10m': 'Validate step 2 + 0.35 padding on five 10-minute clips',
        'pyannoteCandidateValidationPreparing': 'Running pyannote validation on five clips from the film...',
        'pyannoteCandidateValidationPassed': 'Validation completed: step 2 + 0.35 padding passed the safety criteria. Check the log for details.',
        'pyannoteCandidateValidationFailed': 'Validation completed: step 2 + 0.35 padding did not pass all safety criteria. Check the log for details.',
    },
    'es': {
        'pyannoteCandidateValidation5x10m': 'Validar paso 2 + margen 0,35 en cinco fragmentos de 10 minutos',
        'pyannoteCandidateValidationPreparing': 'Ejecutando la validación de pyannote en cinco fragmentos de la película...',
        'pyannoteCandidateValidationPassed': 'Validación completada: paso 2 + margen 0,35 superó los criterios de seguridad. Consulta el registro para más detalles.',
        'pyannoteCandidateValidationFailed': 'Validación completada: paso 2 + margen 0,35 no superó todos los criterios de seguridad. Consulta el registro para más detalles.',
    },
    'fr': {
        'pyannoteCandidateValidation5x10m': 'Valider le pas 2 + marge 0,35 sur cinq extraits de 10 minutes',
        'pyannoteCandidateValidationPreparing': 'Validation pyannote en cours sur cinq extraits du film...',
        'pyannoteCandidateValidationPassed': 'Validation terminée : pas 2 + marge 0,35 a satisfait aux critères de sécurité. Consultez le journal pour les détails.',
        'pyannoteCandidateValidationFailed': 'Validation terminée : pas 2 + marge 0,35 n’a pas satisfait à tous les critères de sécurité. Consultez le journal pour les détails.',
    },
    'de': {
        'pyannoteCandidateValidation5x10m': 'Schritt 2 + Padding 0,35 mit fünf 10-Minuten-Ausschnitten prüfen',
        'pyannoteCandidateValidationPreparing': 'Pyannote-Validierung mit fünf Filmausschnitten läuft...',
        'pyannoteCandidateValidationPassed': 'Validierung abgeschlossen: Schritt 2 + Padding 0,35 erfüllt die Sicherheitskriterien. Details stehen im Protokoll.',
        'pyannoteCandidateValidationFailed': 'Validierung abgeschlossen: Schritt 2 + Padding 0,35 erfüllt nicht alle Sicherheitskriterien. Details stehen im Protokoll.',
    },
    'pl': {
        'pyannoteCandidateValidation5x10m': 'Sprawdź krok 2 + margines 0,35 na pięciu 10-minutowych fragmentach',
        'pyannoteCandidateValidationPreparing': 'Trwa walidacja pyannote na pięciu fragmentach filmu...',
        'pyannoteCandidateValidationPassed': 'Walidacja zakończona: krok 2 + margines 0,35 spełnił kryteria bezpieczeństwa. Szczegóły są w dzienniku.',
        'pyannoteCandidateValidationFailed': 'Walidacja zakończona: krok 2 + margines 0,35 nie spełnił wszystkich kryteriów bezpieczeństwa. Szczegóły są w dzienniku.',
    },
    'cs': {
        'pyannoteCandidateValidation5x10m': 'Ověřit krok 2 + odsazení 0,35 na pěti 10minutových úsecích',
        'pyannoteCandidateValidationPreparing': 'Probíhá ověření pyannote na pěti úsecích filmu...',
        'pyannoteCandidateValidationPassed': 'Ověření dokončeno: krok 2 + odsazení 0,35 splnil bezpečnostní kritéria. Podrobnosti jsou v protokolu.',
        'pyannoteCandidateValidationFailed': 'Ověření dokončeno: krok 2 + odsazení 0,35 nesplnil všechna bezpečnostní kritéria. Podrobnosti jsou v protokolu.',
    },
    'pt': {
        'pyannoteCandidateValidation5x10m': 'Validar passo 2 + margem 0,35 em cinco trechos de 10 minutos',
        'pyannoteCandidateValidationPreparing': 'Executando a validação do pyannote em cinco trechos do filme...',
        'pyannoteCandidateValidationPassed': 'Validação concluída: passo 2 + margem 0,35 passou nos critérios de segurança. Consulte o log para detalhes.',
        'pyannoteCandidateValidationFailed': 'Validação concluída: passo 2 + margem 0,35 não passou em todos os critérios de segurança. Consulte o log para detalhes.',
    },
    'pt_BR': {
        'pyannoteCandidateValidation5x10m': 'Validar passo 2 + margem 0,35 em cinco trechos de 10 minutos',
        'pyannoteCandidateValidationPreparing': 'Executando a validação do pyannote em cinco trechos do filme...',
        'pyannoteCandidateValidationPassed': 'Validação concluída: passo 2 + margem 0,35 passou nos critérios de segurança. Consulte o log para detalhes.',
        'pyannoteCandidateValidationFailed': 'Validação concluída: passo 2 + margem 0,35 não passou em todos os critérios de segurança. Consulte o log para detalhes.',
    },
    'uk': {
        'pyannoteCandidateValidation5x10m': 'Перевірити крок 2 + відступ 0,35 на п’яти 10-хвилинних фрагментах',
        'pyannoteCandidateValidationPreparing': 'Виконується перевірка pyannote на п’яти фрагментах фільму...',
        'pyannoteCandidateValidationPassed': 'Перевірку завершено: крок 2 + відступ 0,35 пройшов критерії безпеки. Подробиці дивіться в журналі.',
        'pyannoteCandidateValidationFailed': 'Перевірку завершено: крок 2 + відступ 0,35 не пройшов усі критерії безпеки. Подробиці дивіться в журналі.',
    },
    'zh': {
        'pyannoteCandidateValidation5x10m': '在五个 10 分钟片段上验证步长 2 + 0.35 填充',
        'pyannoteCandidateValidationPreparing': '正在对影片的五个片段运行 pyannote 验证...',
        'pyannoteCandidateValidationPassed': '验证完成：步长 2 + 0.35 填充通过安全标准。详情请查看 Sonarpad 日志。',
        'pyannoteCandidateValidationFailed': '验证完成：步长 2 + 0.35 填充未通过全部安全标准。详情请查看 Sonarpad 日志。',
    },
    'zh_CN': {
        'pyannoteCandidateValidation5x10m': '在五个 10 分钟片段上验证步长 2 + 0.35 填充',
        'pyannoteCandidateValidationPreparing': '正在对影片的五个片段运行 pyannote 验证...',
        'pyannoteCandidateValidationPassed': '验证完成：步长 2 + 0.35 填充通过安全标准。详情请查看 Sonarpad 日志。',
        'pyannoteCandidateValidationFailed': '验证完成：步长 2 + 0.35 填充未通过全部安全标准。详情请查看 Sonarpad 日志。',
    },
}


def locale_for(path: Path, data: dict) -> str:
    return str(data.get('@@locale') or path.stem.removeprefix('app_'))


def patch_arb(path: Path) -> None:
    data = json.loads(path.read_text(encoding='utf-8'))
    locale = locale_for(path, data)
    values = TEXTS.get(locale, TEXTS['en'])
    changed = False
    for key, value in values.items():
        if data.get(key) != value:
            data[key] = value
            changed = True
        meta = '@' + key
        if meta not in data:
            data[meta] = {'description': f'Localized text for {key}.'}
            changed = True
    if changed:
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print(f'updated {path.relative_to(ROOT)} ({locale})')


def main() -> int:
    if not (ROOT / 'pubspec.yaml').exists():
        print(f'ERROR: project root not found at {ROOT}', file=sys.stderr)
        return 2
    arb_files = sorted(L10N.glob('app_*.arb'))
    if not arb_files:
        print('ERROR: no ARB files found', file=sys.stderr)
        return 2
    for path in arb_files:
        patch_arb(path)

    flutter = shutil.which('flutter')
    if not flutter:
        print('WARNING: flutter not found in PATH. Run "flutter gen-l10n" manually.')
        return 0
    print(f'> {flutter} gen-l10n')
    rc = subprocess.call([flutter, 'gen-l10n'], cwd=ROOT)
    if rc != 0:
        print('ERROR: flutter gen-l10n failed', file=sys.stderr)
        return rc
    print('Localization generation completed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
