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
        'pyannoteBenchmark10Min': 'Benchmark pyannote: primi 10 minuti',
        'pyannoteBenchmarkPreparing': 'Benchmark pyannote in corso sui primi 10 minuti...',
        'pyannoteBenchmarkCompleted': 'Benchmark completato. I risultati dettagliati sono stati registrati nel log di Sonarpad.',
    },
    'en': {
        'pyannoteBenchmark10Min': 'Pyannote benchmark: first 10 minutes',
        'pyannoteBenchmarkPreparing': 'Running pyannote benchmark on the first 10 minutes...',
        'pyannoteBenchmarkCompleted': 'Benchmark completed. Detailed results were recorded in the Sonarpad log.',
    },
    'es': {
        'pyannoteBenchmark10Min': 'Benchmark de pyannote: primeros 10 minutos',
        'pyannoteBenchmarkPreparing': 'Ejecutando el benchmark de pyannote en los primeros 10 minutos...',
        'pyannoteBenchmarkCompleted': 'Benchmark completado. Los resultados detallados se registraron en el log de Sonarpad.',
    },
    'fr': {
        'pyannoteBenchmark10Min': 'Benchmark pyannote : 10 premières minutes',
        'pyannoteBenchmarkPreparing': 'Benchmark pyannote en cours sur les 10 premières minutes...',
        'pyannoteBenchmarkCompleted': 'Benchmark terminé. Les résultats détaillés ont été enregistrés dans le journal de Sonarpad.',
    },
    'de': {
        'pyannoteBenchmark10Min': 'Pyannote-Benchmark: erste 10 Minuten',
        'pyannoteBenchmarkPreparing': 'Pyannote-Benchmark für die ersten 10 Minuten läuft...',
        'pyannoteBenchmarkCompleted': 'Benchmark abgeschlossen. Die detaillierten Ergebnisse wurden im Sonarpad-Protokoll gespeichert.',
    },
    'pl': {
        'pyannoteBenchmark10Min': 'Benchmark pyannote: pierwsze 10 minut',
        'pyannoteBenchmarkPreparing': 'Trwa benchmark pyannote dla pierwszych 10 minut...',
        'pyannoteBenchmarkCompleted': 'Benchmark zakończony. Szczegółowe wyniki zapisano w dzienniku Sonarpad.',
    },
    'cs': {
        'pyannoteBenchmark10Min': 'Benchmark pyannote: prvních 10 minut',
        'pyannoteBenchmarkPreparing': 'Probíhá benchmark pyannote pro prvních 10 minut...',
        'pyannoteBenchmarkCompleted': 'Benchmark dokončen. Podrobné výsledky byly zapsány do protokolu Sonarpad.',
    },
    'pt': {
        'pyannoteBenchmark10Min': 'Benchmark do pyannote: primeiros 10 minutos',
        'pyannoteBenchmarkPreparing': 'Executando benchmark do pyannote nos primeiros 10 minutos...',
        'pyannoteBenchmarkCompleted': 'Benchmark concluído. Os resultados detalhados foram registrados no log do Sonarpad.',
    },
    'pt_BR': {
        'pyannoteBenchmark10Min': 'Benchmark do pyannote: primeiros 10 minutos',
        'pyannoteBenchmarkPreparing': 'Executando benchmark do pyannote nos primeiros 10 minutos...',
        'pyannoteBenchmarkCompleted': 'Benchmark concluído. Os resultados detalhados foram registrados no log do Sonarpad.',
    },
    'uk': {
        'pyannoteBenchmark10Min': 'Тест швидкодії pyannote: перші 10 хвилин',
        'pyannoteBenchmarkPreparing': 'Виконується тест швидкодії pyannote для перших 10 хвилин...',
        'pyannoteBenchmarkCompleted': 'Тест завершено. Докладні результати записано в журнал Sonarpad.',
    },
    'zh': {
        'pyannoteBenchmark10Min': 'pyannote 基准测试：前 10 分钟',
        'pyannoteBenchmarkPreparing': '正在对前 10 分钟运行 pyannote 基准测试...',
        'pyannoteBenchmarkCompleted': '基准测试已完成。详细结果已记录到 Sonarpad 日志中。',
    },
    'zh_CN': {
        'pyannoteBenchmark10Min': 'pyannote 基准测试：前 10 分钟',
        'pyannoteBenchmarkPreparing': '正在对前 10 分钟运行 pyannote 基准测试...',
        'pyannoteBenchmarkCompleted': '基准测试已完成。详细结果已记录到 Sonarpad 日志中。',
    },
}


def locale_for(path: Path, data: dict) -> str:
    locale = str(data.get('@@locale') or '')
    if locale:
        return locale
    return path.stem.removeprefix('app_')


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


def ensure_ios_linker_settings(path: Path) -> None:
    text = path.read_text(encoding='utf-8') if path.exists() else '#include "Generated.xcconfig"\n'
    required = {
        'OTHER_LDFLAGS': '$(inherited) -Wl,-u,_OrtGetApiBase -Wl,-u,_OrtSessionOptionsAppendExecutionProvider_CoreML',
        'STRIP_INSTALLED_PRODUCT': 'NO',
        'STRIP_STYLE': 'non-global-symbols',
    }
    lines = text.splitlines()
    out = []
    seen = set()
    for line in lines:
        stripped = line.strip()
        key = stripped.split('=', 1)[0].strip() if '=' in stripped else None
        if key in required:
            if key == 'OTHER_LDFLAGS':
                existing = stripped.split('=', 1)[1].strip()
                needed = ['-Wl,-u,_OrtGetApiBase', '-Wl,-u,_OrtSessionOptionsAppendExecutionProvider_CoreML']
                for flag in needed:
                    if flag not in existing:
                        existing += ' ' + flag
                if '$(inherited)' not in existing:
                    existing = '$(inherited) ' + existing
                out.append(f'OTHER_LDFLAGS={existing}')
            else:
                out.append(f'{key}={required[key]}')
            seen.add(key)
        else:
            out.append(line)
    for key, value in required.items():
        if key not in seen:
            out.append(f'{key}={value}')
    path.write_text('\n'.join(out).rstrip() + '\n', encoding='utf-8')
    print(f'updated {path.relative_to(ROOT)}')


def run(cmd: list[str]) -> int:
    print('> ' + ' '.join(cmd))
    return subprocess.call(cmd, cwd=ROOT)


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

    ensure_ios_linker_settings(ROOT / 'ios' / 'Flutter' / 'Debug.xcconfig')
    ensure_ios_linker_settings(ROOT / 'ios' / 'Flutter' / 'Release.xcconfig')

    flutter = shutil.which('flutter')
    if not flutter:
        print('WARNING: flutter not found in PATH. Run "flutter gen-l10n" manually before commit.')
        return 0

    rc = run([flutter, 'gen-l10n'])
    if rc != 0:
        print('ERROR: flutter gen-l10n failed', file=sys.stderr)
        return rc
    print('Localization generation completed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
