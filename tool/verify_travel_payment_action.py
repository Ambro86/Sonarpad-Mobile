"""Offline browser checks: method selection must never submit payment."""
from pathlib import Path
from playwright.sync_api import sync_playwright

source = (Path(__file__).resolve().parents[1] / "lib/services/travel_payment_script.dart").read_text(encoding="utf8")
script = source.split("const _script = r'''", 1)[1].split("''';", 1)[0]
import json

with sync_playwright() as p:
    browser = p.chromium.launch(channel="chrome", headless=True)
    page = browser.new_page()
    page.route("**/*", lambda route: route.fulfill(body="<html><body></body></html>", content_type="text/html"))
    page.goto("https://www.omio.com/app/booking/test/checkout")
    def run(selection=None):
        return json.loads(page.evaluate(script.replace("__SELECTION__", json.dumps(selection))))
    def fixture(html):
        page.set_content(html + '<script>window.paid=0;document.addEventListener("submit",e=>{e.preventDefault();window.paid++});</script>')
    fixture('<form><label><input type="radio" name="pay">PayPal</label><label><input type="radio" name="pay">Carta</label><button>Paga</button></form>')
    assert run()["methods"] == ["PayPal", "card"]
    assert run("PayPal")["status"] == "selected"
    assert page.evaluate("window.paid") == 0
    fixture('<label><input type="radio">PayPal</label><label><input type="radio">PayPal</label>')
    assert run()["methods"] == []
    assert run("PayPal")["status"] == "unavailable"
    fixture('<button>PayPal</button><button>Paga con PayPal</button>')
    assert run()["methods"] == []
    fixture('<label><input type="radio" disabled>PayPal</label>')
    assert run()["methods"] == []
    fixture('<label style="display:none"><input type="radio">PayPal</label>')
    assert run()["methods"] == []
    fixture('<label><input type="radio">PayPal</label><div role="dialog" aria-modal="true">Cookies</div>')
    assert run("PayPal")["status"] == "blocked"
    fixture('<label><input type="radio">PayPal</label>')
    assert run()["methods"] == ["PayPal"]
    page.locator("label").evaluate("e => e.remove()")
    assert run("PayPal")["status"] == "unavailable"
    fixture('<form><button role="radio">PayPal</button></form>')
    assert run()["methods"] == []
    page.goto("https://www.omio.com.other.test/app/booking/test/checkout")
    fixture('<label><input type="radio">PayPal</label>')
    assert run("PayPal")["status"] == "unavailable"
    protection = source.split("const _noProtection = r" + "'" * 3, 1)[1].split("'" * 3 + ";", 1)[0]
    page.goto("https://www.omio.com/app/booking/test/checkout")
    def protect(verify=False):
        return page.evaluate(protection.replace("__VERIFY__", str(verify).lower()))
    fixture('<form><label><input type="checkbox">Voglio viaggiare senza protezione</label><button>Paga</button></form>')
    assert protect(True) == "unconfirmed"
    assert not page.locator('input').is_checked()
    assert protect() == "selected"
    assert protect() == "selected"  # Already selected: never toggle it off.
    assert protect(True) == "selected"
    assert page.evaluate("window.paid") == 0
    fixture('<button>Voglio viaggiare senza protezione</button>')
    assert protect() == "not-found"
    fixture('<label><input type="radio">Aggiungi una Protezione completa di viaggio</label>')
    assert protect() == "not-found"
    assert not page.locator('input').is_checked()
    fixture('<label><input type="checkbox">Voglio viaggiare senza protezione</label>' * 2)
    assert protect() == "ambiguous"
    assert page.locator('input:checked').count() == 0
    page.goto("https://example.org/app/booking/test/checkout")
    fixture('<label><input type="checkbox">Voglio viaggiare senza protezione</label>')
    assert protect() == "unavailable"
    page.goto("https://www.omio.com/app/booking/test/checkout")
    fixture('<form><button type="button" aria-pressed="false" onclick="this.setAttribute(\'aria-pressed\',\'true\')">Voglio viaggiare senza protezione</button><button>Paga</button></form>')
    assert protect() == "selected"
    assert protect(True) == "selected"
    assert page.evaluate("window.paid") == 0
    fixture('<form><button aria-pressed="false">Voglio viaggiare senza protezione</button></form>')
    assert protect() == "not-found"  # Default submit button must never be clicked.
    assert page.evaluate("window.paid") == 0
    fixture('<div role="button" aria-pressed="false" onclick="setTimeout(()=>this.setAttribute(\'aria-pressed\',\'true\'),100)">Voglio viaggiare senza protezione</div>')
    assert protect() == "unconfirmed"
    page.wait_for_timeout(200)
    assert protect(True) == "selected"
    fixture('<button type="button" aria-pressed="true" disabled>Voglio viaggiare senza protezione</button>')
    assert protect(True) == "selected"
    assert protect() == "selected"
    fixture('<button type="button" aria-pressed="false" disabled onclick="window.clicked=true">Voglio viaggiare senza protezione</button>')
    assert protect(True) == "unconfirmed"
    assert protect() == "disabled"
    assert page.evaluate("window.clicked") is None
    fixture('<button type="button" aria-pressed="false" onclick="this.setAttribute(\'aria-pressed\',\'true\');this.disabled=true">Voglio viaggiare senza protezione</button>')
    assert protect() == "selected"
    assert protect(True) == "selected"
    fixture('<div role="button" aria-pressed="true" aria-disabled="true">Voglio viaggiare senza protezione</div>')
    assert protect(True) == "selected"
    position = source.split("const travelPayPalPositionScript = r" + "'" * 3, 1)[1].split("'" * 3 + ";", 1)[0]
    fixture('<div style="height:2000px">Page</div><button onclick="window.paid++">PayPal</button>')
    assert page.evaluate(position) == "paypal-area"
    assert page.evaluate("window.scrollY") > 0
    assert page.evaluate("document.activeElement.tagName") == "BUTTON"
    assert page.evaluate("window.paid") == 0
    fixture('<div style="height:2000px">Page</div>')
    assert page.evaluate(position) == "bottom"
    assert page.evaluate("window.scrollY") > 0
    fixture('<div aria-modal="true">Cookies</div><button>PayPal</button>')
    assert page.evaluate(position) == "blocked"
    page.goto("https://www.paypal.com/checkout")
    assert page.evaluate(position) == "unavailable"
    browser.close()
print("Payment and protection selection checks passed; no payment submissions")
