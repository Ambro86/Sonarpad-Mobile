"""Exercise the production cookie script in Chromium against isolated DOM fixtures.

Requires Python Playwright and Chrome. Does not contact Omio or create bookings.
"""
import pathlib
import re
from playwright.sync_api import sync_playwright

source = (pathlib.Path(__file__).resolve().parents[1] /
          'lib/services/travel_cookie_script.dart').read_text(encoding='utf-8')
script = re.search(r"= r'''(.*?)''';", source, re.S).group(1)
inspection = script.replace('const inspectOnly = false;', 'const inspectOnly = true;')

with sync_playwright() as p:
    browser = p.chromium.launch(channel='chrome', headless=True)
    page = browser.new_page()
    cases = [
        ('necessary', 'https://www.omio.com/',
         '<div role="dialog">Cookie<button id="necessary">Solo cookie necessari</button>'
         '<button>Accetta tutto</button></div><button>Paga</button>', ['necessary']),
        ('reject', 'https://www.omio.com/',
         '<div id="onetrust-banner-sdk">Cookies<button id="reject">Reject all</button>'
         '<button>Accept all</button></div>', ['reject']),
        ('accept-only', 'https://www.omio.com/',
         '<div role="dialog">Cookie<button>Accetta tutto</button></div>', []),
        ('outside-banner', 'https://www.omio.com/',
         '<button>Reject all</button><button>Accetta e paga</button>', []),
        ('payment-dialog', 'https://www.omio.com/',
         '<div role="dialog">Payment<button>Reject all</button><button>Pay</button></div>', []),
        ('wrong-origin', 'https://www.paypal.com/',
         '<div id="onetrust-banner-sdk"><button>Reject all</button></div>', []),
        ('lookalike', 'https://www.omio.com.example.org/',
         '<div id="onetrust-banner-sdk"><button>Reject all</button></div>', []),
        ('hidden', 'https://www.omio.com/',
         '<div role="dialog" style="display:none">Cookie<button>Reject all</button></div>', []),
        ('disabled', 'https://www.omio.com/',
         '<div role="dialog">Cookie<button disabled>Reject all</button></div>', []),
        ('not-exact', 'https://www.omio.com/',
         '<div role="dialog">Cookie<button>Reject all and pay</button></div>', []),
    ]
    for name, url, html, expected in cases:
        def fixture(route):
            route.fulfill(content_type='text/html',
                          body='<html><body>' + html + '</body></html>')
        page.route('**/*', fixture)
        page.goto(url)
        page.evaluate("window.clicked=[]; document.addEventListener('click', e => window.clicked.push(e.target.id || e.target.textContent));")
        result = page.evaluate(script)
        actual = page.evaluate('window.clicked')
        assert actual == expected, (name, result, actual)
        assert (result == 'selected-necessary') == bool(expected), (name, result)
        if expected:
            assert page.evaluate(inspection) == 'banner-visible'
            page.evaluate('window.__sonarpadTravelCookieBanner.remove()')
            assert page.evaluate(inspection) == 'banner-closed'
            assert page.evaluate('window.clicked') == expected
        page.unroute('**/*')
        print(name + ': OK')
    browser.close()
