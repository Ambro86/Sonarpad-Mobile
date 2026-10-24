"""Offline DOM checks for conservative checkout accessibility changes."""
import json
from pathlib import Path
from playwright.sync_api import sync_playwright

source = (Path(__file__).resolve().parents[1] / 'lib/services/travel_checkout_accessibility.dart').read_text()
script = source.split("r'''", 1)[1].split("''';", 1)[0]
with sync_playwright() as p:
    browser = p.chromium.launch(channel='chrome', headless=True)
    page = browser.new_page()
    page.route('**/*', lambda r: r.fulfill(body='<html><body></body></html>', content_type='text/html'))
    page.goto('https://www.omio.com/app/booking/test/checkout')
    page.set_content('''<form onsubmit="window.paid=true;return false">
      <label><input id="card" type="radio" name="method" aria-label="Carta"><span>Carta</span><img alt="Visa"><img alt="MasterCard"></label>
      <label><input id="paypal" type="radio" name="method" checked><span>PayPal</span></label>
      <label>Numero carta<input autocomplete="cc-number"></label>
      <button type="button" id="promo">RevPoints</button>
      <div role="button" id="unsafe">RevPoints<input></div>
      <a href="#terms">Condizioni</a><button id="pay">PayPal</button>
      <iframe title="Revolut" src="https://revolut.com/payment"></iframe>
      </form>''')
    before = page.evaluate('[scrollX,scrollY,document.activeElement.tagName]')
    result = json.loads(page.evaluate(script))
    assert result['radios'] == 2 and result['promotions'] == 1
    assert result['decorations'] == 4
    assert page.locator('#paypal').is_checked()
    assert not page.locator('#card').is_checked()
    assert page.locator('#promo').get_attribute('aria-hidden') == 'true'
    assert page.locator('#unsafe').get_attribute('aria-hidden') is None
    assert page.locator('iframe').get_attribute('aria-hidden') is None
    assert page.locator('#pay').get_attribute('aria-hidden') is None
    assert page.locator('input[autocomplete]').get_attribute('aria-hidden') is None
    assert page.evaluate('[scrollX,scrollY,document.activeElement.tagName]') == before
    assert page.evaluate('window.paid') is None
    tree = page.locator('body').aria_snapshot()
    assert 'radio "Carta"' in tree and 'radio "PayPal"' in tree
    assert 'textbox "Numero carta"' in tree and 'button "PayPal"' in tree
    assert 'img "Visa"' not in tree
    page.locator('#card').check()
    page.evaluate(script)
    assert page.locator('#card').is_checked()
    page.evaluate("document.body.insertAdjacentHTML('beforeend','<div aria-modal=\"true\">Modal</div>')")
    assert json.loads(page.evaluate(script))['status'] == 'modal'
    page.goto('https://www.paypal.com/checkout')
    assert json.loads(page.evaluate(script))['status'] == 'outside-checkout'
    browser.close()
print('Checkout accessibility: labels, fields, payment controls, frames and selection preserved; no scrolling or payment')
