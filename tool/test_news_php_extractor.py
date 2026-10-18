"""Offline tests. Usage: py -X utf8 tool/test_news_php_extractor.py path/to/reader.php"""
import json
import subprocess
import sys
import types
import unittest
from pathlib import Path
from unittest.mock import patch

PHP = Path(sys.argv.pop(1))
source = PHP.read_text(encoding="utf-8-sig")
script = source.split("<<<'SONARPAD_CURL_PYTHON'\n", 1)[1].split("\nSONARPAD_CURL_PYTHON;", 1)[0]
reader = types.ModuleType("sonarpad_test_reader")
exec(compile(script, str(PHP) + ":embedded-python", "exec"), reader.__dict__)
URL = "https://example.org/selected"
FIRST = "Il primo paragrafo contiene informazioni precise sulla notizia scelta dal lettore. " * 3
LAST = "Il paragrafo finale conclude correttamente la notizia e deve restare presente nella lettura. " * 3


class ExtractorTests(unittest.TestCase):
    def extract(self, html, url=URL):
        reader.TRACE = []
        return reader.extract(url, '<html><h1>La notizia scelta dal lettore</h1>' + html + '</html>')

    def test_focused_body_beats_long_unrelated_wrapper(self):
        noise = "Notizia completamente diversa con molto testo estraneo. " * 200
        result = self.extract(f'<main><div class="article-body"><p>{FIRST}</p><p>{LAST}</p></div><section><p>{noise}</p></section></main>')
        self.assertIn(LAST.strip(), ' '.join(result['markdown'].split()))
        self.assertNotIn('completamente diversa', result['markdown'])

    def test_related_jsonld_never_replaces_selected_article(self):
        data = {'@type': 'NewsArticle', 'url': 'https://example.org/unrelated',
                'headline': 'La notizia scelta dal lettore', 'articleBody': 'WRONG ARTICLE. ' * 200}
        result = self.extract(f'<script type="application/ld+json">{json.dumps(data)}</script><article><p>{FIRST}</p><p>{LAST}</p></article>')
        self.assertNotIn('WRONG', result['markdown'])
        self.assertIn(FIRST.strip(), ' '.join(result['markdown'].split()))

    def test_matching_structured_full_body_beats_preview(self):
        data = {'@type': 'NewsArticle', 'mainEntityOfPage': {'@id': URL}, 'articleBody': FIRST + '\n\n' + LAST}
        result = self.extract(f'<script type="application/ld+json">{json.dumps(data)}</script><div class="article-body"><p>{FIRST}</p></div>')
        self.assertIn(LAST.strip(), ' '.join(result['markdown'].split()))
        self.assertEqual(result['extraction_method'], 'structured_data')

    def test_middle_related_heading_does_not_cut_remaining_body(self):
        result = self.extract(f'<article><p>{FIRST}</p><h2>Leggi anche</h2><div class="related-posts"><p>Unrelated story</p></div><p>{LAST}</p></article>')
        self.assertIn(LAST.strip(), ' '.join(result['markdown'].split()))
        self.assertNotIn('Unrelated story', result['markdown'])

    def test_hdblog_affiliate_cards_do_not_hide_prose(self):
        cards = '<div class="blz_card_hdblog"><a href="https://shop.example.org">' + ('Buy now ' * 200) + '</a></div>'
        result = self.extract(f'<section id="notice_content"><div class="content"><p>{FIRST}</p>{cards}<p>{LAST}</p></div></section>', 'https://www.hdblog.it/test/')
        self.assertIn(FIRST.strip(), ' '.join(result['markdown'].split()))
        self.assertIn(LAST.strip(), ' '.join(result['markdown'].split()))
        self.assertNotIn('Buy now', result['markdown'])

    def test_unicode_text_length_and_plain_format(self):
        result = self.extract(f'<article><p>{FIRST} Città, più, perché 📰, 3 &lt; 5 e valore_medio. Prezzo 280\x80.</p><p>{LAST}</p></article>')
        self.assertIn('3 < 5 e valore_medio', result['markdown'])
        self.assertIn('Prezzo 280€.', result['markdown'])
        self.assertEqual(result['text_length'], len(result['markdown']))
        self.assertEqual(result['format'], 'text')

    def test_bbc_separate_blocks_are_all_retained(self):
        result = self.extract(f'<article><div data-block="text"><p>{FIRST}</p></div><div data-block="text"><p>{LAST}</p></div><section><h2>Related topics</h2><p>Unrelated story</p></section></article>', 'https://www.bbc.co.uk/news/articles/selected')
        text = ' '.join(result['markdown'].split())
        self.assertIn(FIRST.strip(), text)
        self.assertIn(LAST.strip(), text)
        self.assertNotIn('Unrelated story', text)

    def test_prose_in_leaf_divs_is_retained(self):
        result = self.extract(f'<article><div>{FIRST}</div><div>{LAST}</div></article>')
        self.assertIn(LAST.strip(), ' '.join(result['markdown'].split()))

    def test_public_react_body_is_decoded_without_running_javascript(self):
        body = f'<p>{FIRST}</p><p>{LAST} Città 📰.</p>'
        reference = '["$","div",null,{"className":"PostStandard_post_content__test","children":[["$","div",null,{"dangerouslySetInnerHTML":{"__html":"$26"}}]]}]'
        chunks = ['26:T' + format(len(body.encode('utf-8')), 'x') + ',', body, reference]
        html = ''.join('<script>self.__next_f.push(' + json.dumps([1, chunk]) + ')</script>' for chunk in chunks)
        result = self.extract(html, 'https://www.micromega.net/selected/')
        self.assertIn(LAST.strip(), ' '.join(result['markdown'].split()))
        self.assertIn('Città 📰.', result['markdown'])
        self.assertEqual(result['extraction_method'], 'react_payload')

    def test_explicit_short_subscription_preview_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Anteprima'):
            self.extract(f'<article><p>{FIRST}</p><div class="paywall-wrapper">Subscribe</div></article>')

    def test_short_restricted_structured_article_is_marked_as_preview(self):
        data = {'@type': 'NewsArticle', 'url': URL, 'isAccessibleForFree': False, 'articleBody': FIRST + LAST}
        result = self.extract(f'<script type="application/ld+json">{json.dumps(data)}</script>')
        self.assertEqual(result['completeness'], 'preview_possible')
        code = r'''$s=file_get_contents($argv[1]); eval(substr($s,strpos($s,'function ')));
$r=json_decode(stream_get_contents(STDIN),true);
try { article_reader_validate($r,$r['url']); echo 'accepted'; }
catch(Throwable $e) { echo 'rejected'; }'''
        checked = subprocess.run(['php', '-r', code, str(PHP)], input=json.dumps(result), text=True, encoding='utf-8', capture_output=True, check=True, cwd=PHP.parent)
        self.assertEqual(checked.stdout, 'rejected')

    def test_non_public_destination_is_rejected(self):
        with patch.object(reader.socket, 'getaddrinfo', return_value=[(2, 1, 6, '', ('127.0.0.1', 443))]):
            with self.assertRaisesRegex(ValueError, 'non pubblica'):
                reader.public_target(URL)
        for url in ['file:///etc/passwd', 'https://user:password@example.org/', 'https://example.org:8080/']:
            with self.assertRaises(ValueError):
                reader.public_target(url)

    def test_redirect_cookies_are_preserved(self):
        received = []

        class Session:
            def __init__(self, **kwargs):
                self.cookies = kwargs.get('cookies') or {}
                received.append(dict(self.cookies))

            def __enter__(self):
                return self

            def __exit__(self, *args):
                pass

            def get(self, url, **kwargs):
                self.cookies['session'] = 'cookie-value'
                return types.SimpleNamespace(status_code=302 if len(received) == 1 else 200,
                    headers={'location': '/selected', 'content-type': 'text/html'})

        fake = types.SimpleNamespace(requests=types.SimpleNamespace(Session=Session), CurlOpt=types.SimpleNamespace(RESOLVE=1, PROXY=2))
        with patch.dict(sys.modules, {'curl_cffi': fake}), patch.object(reader, 'public_target', return_value=('example.org', 443, '93.184.216.34')):
            reader.TRACE = []
            reader.download(URL, 5)
        self.assertEqual(received[1], {'session': 'cookie-value'})

    def test_php_cleanup_keeps_mid_article_sections_and_unicode(self):
        text = FIRST * 6 + '\n\nLeggi anche\n\n' + LAST + '\n\n3 < 5, valore_medio, città 📰.'
        code = r'''$s=file_get_contents($argv[1]); eval(substr($s,strpos($s,'function ')));
$x=json_decode(stream_get_contents(STDIN),true);
$t=article_reader_clean_plain_text('https://example.org/selected',$x['text']);
echo json_encode(['text'=>$t,'length'=>text_length($t)],JSON_UNESCAPED_UNICODE);'''
        result = subprocess.run(['php', '-r', code, str(PHP)], input=json.dumps({'text': text}), text=True, encoding='utf-8', capture_output=True, check=True)
        data = json.loads(result.stdout)
        self.assertIn(LAST.strip(), data['text'])
        self.assertIn('3 < 5, valore_medio, città 📰.', data['text'])
        self.assertEqual(data['length'], len(data['text']))

    def test_php_rejects_cookie_dialog_and_obfuscated_text(self):
        code = r'''$s=file_get_contents($argv[1]); eval(substr($s,strpos($s,'function ')));
$x=json_decode(stream_get_contents(STDIN),true);
echo json_encode(article_reader_quality_reason($x['url'],'Article title',$x['text']));'''
        for host, text, reason in [
            ('ansa.it', 'Se hai scelto di non accettare i cookie di profilazione. ' + FIRST, 'consent_dialog_instead_of_article'),
            ('micromega.net', ('Qmrxv plktr wfrgk zxvkj klwqzx. ' * 20 + '\n\n') * 3, 'obfuscated_article_text'),
            ('micromega.net', FIRST + LAST, None),
        ]:
            result = subprocess.run(['php', '-r', code, str(PHP)], input=json.dumps({'url': 'https://' + host + '/selected', 'text': text}), text=True, encoding='utf-8', capture_output=True, check=True)
            self.assertEqual(json.loads(result.stdout), reason)


if __name__ == '__main__':
    unittest.main(verbosity=2)
