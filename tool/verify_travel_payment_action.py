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
    browser.close()
print("9 payment selection scenarios passed; no payment submissions")
