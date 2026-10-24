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
    assert all(e["event"] == "focusout" for e in third["events"])
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
    page.evaluate("""() => {
      const b=document.createElement('button'); b.type='button'; b.textContent='RevPoints';
      b.style.marginTop='2000px'; document.body.append(b); b.focus();
    }""")
    focused = read()
    assert any(e['event']=='focusin' and any(m['match']=='revpoints' for m in e['matches']) for e in focused['events'])
    landmark = next(x for x in focused['landmarks'] if any(m['match']=='revpoints' for m in x['matches']))
    assert landmark['node'] == focused['active']['node']
    assert len(landmark['bounds']) == 4
    assert focused['viewport']['scrollY'] > 0
    assert page.evaluate("window.paid") is None
    assert 'private@example.org' not in json.dumps(focused)
    page.evaluate("""() => {
      const b=document.createElement('div'); b.setAttribute('role','button'); b.tabIndex=0;
      b.setAttribute('aria-label','Usa i tuoi Rev Points private@example.org');
      b.innerHTML='<span>Promozione</span>'; document.body.append(b); b.focus();
    }""")
    variant = read()
    assert any(h['category']=='revpoints' for h in variant['active']['hints'])
    assert any(h['source']=='aria-label' and h['category']=='revpoints'
               for x in variant['landmarks'] for h in x['hints'])
    assert any(e['event']=='focusin' and e['target']['hints'] for e in variant['events'])
    assert variant['active']['interactiveDescendants'] == 0
    page.evaluate("""() => {
      const b=document.createElement('button'); b.type='button'; b.textContent='Unknown private-person';
      document.body.append(b); b.focus();
      document.querySelector('iframe').title='Use RevPoints private-token';
    }""")
    unknown = read()
    assert any(e['event']=='focusin' and e['target']['tag']=='button' and e['matches']==[] for e in unknown['events'])
    assert any(h['category']=='revpoints' for f in unknown['frameDetails'] for h in f['hints'])
    for data in [variant,unknown]:
        for secret in ['private-person','private@example.org','private-token','4111111111111111','private-password']:
            assert secret not in json.dumps(data)
    assert page.evaluate("window.paid") is None
    page.evaluate("""() => {
      const host=document.createElement('div'); document.body.append(host);
      host.attachShadow({mode:'open'}).innerHTML='<label id="private-shadow-label">Private Name</label><button aria-labelledby="private-shadow-label">Other control</button>';
    }""")
    mapped=read()
    assert mapped['inventorySummary']['shadowRoots']==1
    shadow_button=next(x for x in mapped['inventoryChanges'] if x['shadowHost'] and x['tag']=='button')
    assert len(shadow_button['labelledBy'])==1
    assert any(x['tag']=='iframe' for x in first['inventoryChanges']) is False
    assert any(x['fieldCategory']=='card-number' for x in first['inventoryChanges'])
    assert not mapped['inventorySummary']['truncated']
    assert read()['inventoryChanges']==[]
    page.locator('input[autocomplete="cc-number"]').evaluate("el => el.remove()")
    removed=read()
    card_node=next(x['node'] for x in first['inventoryChanges'] if x['fieldCategory']=='card-number')
    assert card_node in removed['inventorySummary']['removed']
    for secret in ['Private Name','private-shadow-label','private@example.org','4111111111111111']:
        assert secret not in json.dumps(mapped)
    page.evaluate("""() => {for(let i=0;i<650;i++){const b=document.createElement('button');b.textContent='x';document.body.append(b)}}""")
    capped=read()
    assert capped['inventorySummary']['truncated']
    assert capped['inventorySummary']['recorded']<=600
    assert capped['inventorySummary']['removed']==[]
    page.goto("https://example.org/app/booking/test/checkout")
    assert read() == {"scope": "outside-checkout"}
    browser.close()
print("Checkout diagnostics: read-only, state changes, replacement identity, privacy and origin checks passed")
