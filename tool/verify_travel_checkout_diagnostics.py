"""Read-only checkout diagnostics: real DOM state, replacements, privacy."""
import json
from pathlib import Path
from playwright.sync_api import sync_playwright
source = (Path(__file__).resolve().parents[1] / "lib/services/travel_checkout_diagnostics.dart").read_text(encoding="utf8")
script = source.split("r" + "'" * 3, 1)[1].rsplit("'" * 3, 1)[0]
with sync_playwright() as p:
    browser = p.chromium.launch(channel="chrome", headless=True)
    page = browser.new_page()
    page.route("**/*", lambda route: route.fulfill(body="<html><body></body></html>", content_type="text/html"))
    page.goto("https://www.omio.com/app/booking/private-booking/checkout?token=secret-token")
    page.set_content('''<p>Private Passenger private@example.org</p>
      <input type="text" autocomplete="cc-number" value="4111111111111111"><input type="password" value="private-password"><input autocomplete="cc-csc" value="987">
      <label><input type="radio" name="private-name" id="private-id">PayPal</label>
      <button type="button" aria-pressed="false" onclick="this.setAttribute('aria-pressed','true')">Voglio viaggiare senza protezione</button>
      <button type="submit" onclick="window.paid=true">Paga</button>''')
    def read(): return json.loads(page.evaluate(script))
    first = read()
    assert not page.locator("input[type=radio]").is_checked()
    assert page.locator("button[aria-pressed]").get_attribute("aria-pressed") == "false"
    assert page.evaluate("window.paid") is None
    encoded = json.dumps(first)
    for secret in ["private@example.org", "Private Passenger", "4111111111111111", "private-name", "private-id", "private-booking", "secret-token", "private-password", "987"]:
        assert secret not in encoded, secret
    control = next(c for c in first["controls"] if c["tag"] == "button")
    node = control["node"]
    page.locator("button[aria-pressed]").click()
    second = read()
    assert any(e["event"] == "click" for e in second["events"])
    assert next(c for c in second["controls"] if c["node"] == node)["ariaPressed"] == "true"
    page.locator("button[aria-pressed]").evaluate("e => e.replaceWith(e.cloneNode(true))")
    third = read()
    assert not any(c["node"] == node for c in third["controls"])
    assert third["events"] == []
    fields = first["documents"][0]["fields"]
    assert {x["category"] for x in fields} >= {"card-number", "card-security-code", "password"}
    assert all("value" not in x for x in fields)
    page.evaluate("""() => {
      const frame=document.createElement('iframe');
      frame.srcdoc='<input autocomplete="cc-exp" value="12/30">';
      document.body.append(frame);
      const external=document.createElement('iframe');
      external.src='https://www.paypal.com/private-session?token=secret-token';
      document.body.append(external);
    }""")
    page.wait_for_timeout(500)
    framed = read()
    assert any(x["provider"] == "paypal.com" and x["access"] == "cross-origin-or-not-loaded" for x in framed["frameDetails"])
    assert any(f["category"] == "card-expiry" for d in framed["documents"] for f in d["fields"])
    assert "12/30" not in json.dumps(framed)
    assert "secret-token" not in json.dumps(framed)
    page.goto("https://example.org/app/booking/test/checkout")
    assert read() == {"scope": "outside-checkout"}
    browser.close()
print("Checkout diagnostics: read-only, state changes, replacement identity, privacy and origin checks passed")
