"""Compare Dart/PHP outputs with the exact HTML saved by the optional local audit.
Usage: py -X utf8 tool/audit_news_php_quality.py AUDIT_DIRECTORY
The coverage measures available selected-body prose, not subscription completeness.
"""
import hashlib
import json
import re
import sys
from pathlib import Path
from urllib.parse import urlsplit
from bs4 import BeautifulSoup

base = Path(sys.argv[1])
rows = [json.loads(line) for line in (base / 'results.jsonl').read_text(encoding='utf-8').splitlines() if line.strip()]

def normalized(text):
    return ' '.join(re.findall(r'\w+', text.casefold()))

def same_url(left, right):
    a, b = urlsplit(left), urlsplit(right)
    return a.hostname == b.hostname and a.path.rstrip('/') == b.path.rstrip('/')

def structured_bodies(value, url):
    found = []
    if isinstance(value, dict):
        identity = value.get('url') or value.get('mainEntityOfPage') or value.get('@id')
        if isinstance(identity, dict): identity = identity.get('@id') or identity.get('url')
        if isinstance(value.get('articleBody'), str) and isinstance(identity, str) and same_url(identity, url):
            found.append(value['articleBody'])
        for child in value.values(): found.extend(structured_bodies(child, url))
    elif isinstance(value, list):
        for child in value: found.extend(structured_bodies(child, url))
    return found

report = []
for row in rows:
    responses = row.get('php', [])
    php = next((p for p in responses if p.get('ok')), responses[0] if responses else {})
    item = {key: row.get(key) for key in ('source', 'title', 'resolved', 'language', 'elapsed_ms')}
    item.update(php_ok=php.get('ok', False), provider=php.get('provider'),
                text_length=php.get('text_length', 0), dart_length=row.get('dart_length', 0),
                selector=php.get('extraction_selector'), flags=[])
    if not php.get('ok'):
        item['flags'].append('backend_unavailable')
        item['dart_fallback'] = 'error' if row.get('error') else 'rss_summary' if row.get('summary_only') else 'local_reader'
        report.append(item)
        continue
    text = php.get('markdown', '')
    if php.get('format') == 'text' and text.strip() != row.get('dart_text', ''):
        item['flags'].append('dart_text_changed')
    final_url = php.get('final_url') or row['resolved']
    fixture = base / 'html' / (hashlib.sha256(final_url.encode()).hexdigest() + '.' + str(php.get('browser_profile')) + '.html')
    if not fixture.exists():
        item['flags'].append('no_exact_html_reference')
        report.append(item)
        continue
    soup = BeautifulSoup(fixture.read_bytes(), 'html.parser')
    bodies = []
    if php.get('extraction_method') == 'structured_data':
        for script in soup.select('script[type="application/ld+json"],script#__NEXT_DATA__'):
            try: bodies.extend(structured_bodies(json.loads(script.string or script.get_text()), final_url))
            except (ValueError, TypeError): pass
        if bodies:
            markup = max(bodies, key=len)
            ref = BeautifulSoup(markup, 'html.parser').get_text(' ', strip=True)
            reference = [part.strip() for part in re.split(r'(?<=[.!?])\s+|\n+', ref) if len(part.strip()) >= 80]
        else: reference = []
    elif php.get('extraction_method') == 'html' and item['selector']:
        for noise in soup.select('script,style,noscript,nav,footer,aside,form,button,iframe,[hidden],[aria-hidden=true],[class*=related],[class*=recommended],.newsletter,.blz_card_hdblog,.discover_button,.twitter-tweet,.instagram-media,.p-dealLink,.ti-potrebbe-interessare,.post-most-view,.card-news-vertical,.container-carosuel-news'):
            if noise.parent is not None: noise.decompose()
        reference = []
        for root in soup.select(item['selector']):
            for paragraph in root.find_all(['p', 'blockquote', 'li', 'div']):
                if paragraph.find(['p', 'blockquote', 'li', 'div']): continue
                value = paragraph.get_text(' ', strip=True)
                if len(value) >= 80: reference.append(value)
    else: reference = []
    reference = list(dict.fromkeys(reference))
    reference = [p for p in reference if not re.match(r'^(?:Copyright|©|Riproduzione riservata|Scegli .*fonte preferita|Vuoi navigare senza pubblicità)', p, re.I)]
    plain = normalized(text)
    if reference:
        matched = [normalized(p) in plain for p in reference]
        total = sum(len(p) for p in reference)
        covered = sum(len(p) for p, ok in zip(reference, matched) if ok)
        item.update(reference_paragraphs=len(reference), matched_paragraphs=sum(matched),
                    available_prose_coverage=round(covered / total, 4),
                    first_paragraph_retained=matched[0], last_paragraph_retained=matched[-1])
        if covered / total < 0.95: item['flags'].append('review_missing_or_filtered_prose')
    else: item['flags'].append('reference_not_measurable')
    report.append(item)

(base / 'quality.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print('Checked', len(report), 'articles; PHP successes', sum(r['php_ok'] for r in report))
for row in report:
    if 'review_missing_or_filtered_prose' in row['flags']:
        print(row['source'], row.get('available_prose_coverage'), row['selector'], row['resolved'])
