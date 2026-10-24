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
    page.reload()
    # Structure from diagnostic 23: link > radio + separate label/heading + logos.
    page.set_content('''<form onsubmit="window.paid=true;return false">
      <a id="card-row" href="#card"><div><input id="c" type="radio" name="method"></div>
        <div><label for="c"><div><h6><span>Carta</span></h6></div></label></div>
        <div><img alt="Visa"><img alt="MasterCard"><img alt="Maestro"></div></a>
      <a id="pp-row" href="#paypal"><input id="p" type="radio" name="method" checked>
        <label for="p"><h6>PayPal</h6></label><img alt="PayPal"></a>
      <a id="rev-row" href="#revolut"><input id="r" type="radio" name="method">
        <label for="r"><h6>Revolut Pay</h6></label>
        <iframe id="small" src="https://revolut.com/icon" style="width:22px;height:16px;border:0"></iframe></a>
      <iframe id="large" src="https://revolut.com/payment" style="width:363px;height:91px"></iframe>
      <label>Numero carta<input autocomplete="cc-number"></label><button>PayPal</button>
      </form>''')
    result=json.loads(page.evaluate(script))
    assert result['wrappers']==3 and result['frames']==0
    tree=page.locator('body').aria_snapshot()
    assert 'link "Carta' not in tree and 'link "PayPal' not in tree
    assert 'heading "Carta' not in tree and 'img "PayPal' not in tree
    assert 'radio "Carta"' in tree and 'radio "PayPal" [checked]' in tree
    assert 'textbox "Numero carta"' in tree and 'button "PayPal"' in tree
    assert page.locator('#small').get_attribute('aria-hidden') is None
    assert page.locator('#large').get_attribute('aria-hidden') is None
    page.locator('#c').check()
    page.evaluate(script)
    assert page.locator('#c').is_checked()
    assert page.locator('#card-row').get_attribute('href')=='#card'
    # Omio can update selection after focus arrives. Sync the accessible state
    # after that handler without rerunning the simplification script.
    page.locator('#p').evaluate("el=>el.addEventListener('focus',()=>queueMicrotask(()=>{el.checked=true}))")
    page.locator('#p').focus()
    page.wait_for_function("document.getElementById('p').getAttribute('aria-checked')==='true' && document.getElementById('c').getAttribute('aria-checked')==='false'")
    assert page.locator('#p').is_checked()
    assert 'radio "PayPal" [checked]' in page.locator('body').aria_snapshot()
    page.locator('#c').check()
    page.wait_for_function("document.getElementById('p').getAttribute('aria-checked')==='false' && document.getElementById('c').getAttribute('aria-checked')==='true'")
    assert not page.locator('#p').is_checked()
    assert page.evaluate('window.paid') is None

    page.locator('#small').evaluate("el=>el.style.width='350px'")
    page.evaluate(script)
    assert page.locator('#small').get_attribute('aria-hidden') is None
    assert page.locator('#small').get_attribute('tabindex') is None
    assert page.evaluate('window.paid') is None
    page.evaluate("""() => document.body.insertAdjacentHTML('beforeend',
      '<p id="terms">Accetto i termini di uso di Omio</p>'+
      '<div id="points"><a href="#promotion"><span>Guadagna 2 volte i RevPoints</span></a></div>'+
      '<iframe id="named-promo" title="Guadagna 2x RevPoints" src="https://revolut.com/promo"></iframe>'+
      '<button id="submit-points">Guadagna 2 volte i RevPoints</button>')""")
    result=json.loads(page.evaluate(script))
    assert result['promotions']>=2
    assert page.locator('#points').get_attribute('aria-hidden')=='true'
    assert page.locator('#named-promo').get_attribute('aria-hidden')=='true'
    assert page.locator('#terms').get_attribute('aria-hidden') is None
    assert page.locator('#submit-points').get_attribute('aria-hidden') is None
    assert page.locator('#large').get_attribute('aria-hidden') is None
    assert page.locator('#points a').get_attribute('tabindex')=='-1'
    assert page.evaluate('window.paid') is None
    page.evaluate("document.body.insertAdjacentHTML('beforeend','<div aria-modal=\"true\">Modal</div>')")
    assert json.loads(page.evaluate(script))['status'] == 'modal'
    page.goto('https://www.paypal.com/checkout')
    assert json.loads(page.evaluate(script))['status'] == 'outside-checkout'
    browser.close()
print('Checkout accessibility: labels, fields, payment controls, frames and selection preserved; no scrolling or payment')
