// Run with: node test/ticketone_accessible_dom.cjs <path-to-jsdom>
// All fixtures are synthetic. No account, browser cookies or live orders needed.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { JSDOM } = require(process.argv[2] || 'jsdom');
const source = fs.readFileSync(path.join(__dirname, '../lib/services/ticketone_accessible_script.dart'), 'utf8');
const script = source.split("r'''")[1].split("''';")[0];
let passed = 0;
function fixture(html, url = 'https://auth.ticketone.it/identity/auth/') {
  const dom = new JSDOM(html, { url, runScripts: 'outside-only' });
  const w = dom.window;
  w.HTMLElement.prototype.getClientRects = function () {
    return this.closest('[hidden], .hidden') || w.getComputedStyle(this).display === 'none' ? [] : [{}];
  };
  return {
    w, doc: w.document,
    read: () => JSON.parse(w.eval(script)),
    act: (page, action, values = {}, extra = {}) => w.__sonarpadTicketOneUi.run({ revision: page.revision, action, values, ...extra }),
    close: () => w.close(),
  };
}
async function test(name, run) { await run(); console.log('PASS ' + name); passed++; }
(async () => {
  await test('email: accept cookies first, dispatch input events, submit once', async () => {
    const f = fixture(`<main id="mainContainer"><form id="kc-form-login"><label for="email">Indirizzo Email</label><input type="email" id="email" required><input class="hidden" id="username"><input type="submit" value="Continua"></form></main><div id="cmpbox"><button>Accetta tutti i Cookie</button></div>`);
    let submits = 0, input = 0;
    f.doc.querySelector('#cmpbox button').onclick = () => f.doc.querySelector('#cmpbox').style.display = 'none';
    f.doc.querySelector('#email').oninput = () => input++;
    f.doc.querySelector('form').onsubmit = e => { e.preventDefault(); submits++; assert.equal(f.doc.querySelector('#cmpbox').style.display, 'none'); };
    const p = f.read(); assert.equal(p.fields.length, 1); assert.equal(p.fields[0].type, 'email');
    assert.equal((await f.act(p, 'a0', { f0: 'person@example.test' }, { acceptCookies: true })).status, 'submitted');
    assert.equal(submits, 1); assert.equal(input, 1);
    assert.equal((await f.act(p, 'a0')).status, 'stale'); assert.equal(submits, 1); f.close();
  });
  await test('cookie failure never submits or fills the form', async () => {
    const f = fixture(`<main id="mainContainer"><form><label for="email">Email</label><input type="email" id="email"><input type="submit" value="Continua"></form></main><div id="cmpbox">Cookie<button>Preferenze</button></div>`);
    let submits = 0; f.doc.querySelector('form').onsubmit = e => { e.preventDefault(); submits++; };
    assert.equal((await f.act(f.read(), 'a0', { f0: 'person@example.test' }, { acceptCookies: true })).status, 'cookies-unavailable');
    assert.equal(submits, 0); assert.equal(f.doc.querySelector('#email').value, ''); f.close();
  });
  await test('password is redacted; one-time-code link does not require a password', async () => {
    const f = fixture(`<main id="mainContainer"><form><label for="password">Password</label><input id="password" type="password" value="PRIVATE" required><input type="submit" value="Accedi"></form><a href="#otp">Accedi con un codice monouso</a></main>`);
    const p = f.read(); assert.equal(p.fields[0].value, ''); assert.equal(p.fields[0].secret, true);
    let clicks = 0; f.doc.querySelector('a').onclick = e => { e.preventDefault(); clicks++; };
    f.doc.querySelector('#password').value = '';
    assert.equal((await f.act(p, 'a1')).status, 'submitted'); assert.equal(clicks, 1); f.close();
  });
  await test('OTP is redacted; validation returns the exact native field', async () => {
    const f = fixture(`<main id="mainContainer"><form><label for="otp">Codice</label><input id="otp" name="otp" value="123456" required><input type="submit" value="Conferma"></form></main>`);
    const p = f.read(); assert.equal(p.fields[0].secret, true); assert.equal(p.fields[0].value, '');
    const r = await f.act(p, 'a0', { f0: '' }); assert.equal(r.status, 'invalid'); assert.equal(r.field, 'f0'); f.close();
  });
  await test('stale DOM cannot submit another form', async () => {
    const f = fixture(`<main id="mainContainer"><form><label for="email">Email</label><input id="email"><input type="submit" value="Continua"></form></main>`);
    const p = f.read(); f.doc.querySelector('#email').remove();
    assert.equal((await f.act(p, 'a0', { f0: 'new@example.test' })).status, 'stale'); f.close();
  });
  await test('ticket quantity uses actual stepper; cart action needs a fresh snapshot', async () => {
    const f = fixture(`<form class="js-ticket-selection-with-limits"><button type="button" data-qa="LessTickets">Meno</button><div data-qa="TicketAmount">2</div><button type="button" data-qa="MoreTickets">Più</button><input class="js-fast-booking-item" type="radio" id="ticket" data-min="1" data-max="10" data-pc-title="Posto unico"><label for="ticket">Intero 20 EUR</label><button data-qa="AddToShoppingCart">Metti nel carrello</button></form>`, 'https://www.ticketone.it/event/test');
    const qty = f.doc.querySelector('[data-qa=TicketAmount]');
    f.doc.querySelector('[data-qa=LessTickets]').onclick = () => qty.textContent = Number(qty.textContent) - 1;
    const p = f.read(); assert.equal(p.quantity.value, 2);
    assert.equal((await f.act(p, 'quantity', {}, { quantity: 1 })).status, 'changed'); assert.equal(qty.textContent, '1');
    assert.equal((await f.act(p, 'a0')).status, 'stale'); f.close();
  });
  await test('delivery/payment role radios retain labels, fees and checked state', async () => {
    const f = fixture(`<title>Consegna - TicketOne</title><li role="radio" aria-checked="false"><input type="radio" aria-hidden="true"><span>Stampa@casa 0 EUR</span></li><button>Salva e vai al pagamento</button>`, 'https://www.ticketone.it/checkout.html');
    const radio = f.doc.querySelector('li'); radio.onclick = () => radio.setAttribute('aria-checked', 'true');
    const p = f.read(); assert.equal(p.fields.length, 1); assert.equal(p.fields[0].label, 'Stampa@casa 0 EUR');
    assert.equal((await f.act(p, 'change', { f0: true })).status, 'changed');
    assert.equal(f.read().fields[0].value, true); f.close();
  });
  await test('privacy choices retain purpose and are not automatically selected', async () => {
    const f = fixture(`<div class="evi-widget"><label for="yes">Acconsento</label><input type="radio" id="yes"><div class="evi-widget-text-below">al marketing</div></div><button>Conferma i dati</button>`, 'https://www.ticketone.it/checkout.html');
    const p = f.read(); assert.equal(p.fields[0].label, 'Acconsento — al marketing'); assert.equal(p.fields[0].value, false); f.close();
  });
  await test('review includes totals; final PayPal is never clicked automatically', async () => {
    const f = fixture(`<div data-qa="summary-page"><div data-qa="order-overview">1 Biglietto</div><div data-qa="total-order-sum">Totale 21,50 EUR</div><label for="terms">Accetto i termini</label><input type="checkbox" id="terms"><iframe title="PayPal-paypal"></iframe><button>Acquista e paga</button></div>`, 'https://www.ticketone.it/checkout.html');
    const p = f.read(); assert.equal(p.stage, 'review'); assert.equal(p.paypal, true);
    assert(p.summary.includes('Totale 21,50 EUR')); assert.equal(p.actions.length, 0); assert.equal(p.fields[0].value, false); f.close();
  });
  await test('cart exposes numbered seats before checkout without sidebar duplicates or extras', async () => {
    const f = fixture(`<title>Carrello - TicketOne</title><div data-qa="order-position"><div data-qa="event-information">Concerto A <div data-qa="seat-information">Platea, Fila 9, Posto 28</div></div><label for="insurance">Polizza facoltativa</label><input id="insurance" type="checkbox"></div><aside><div data-qa="event-information">Concerto A copia laterale</div></aside><button>Vai alla spedizione</button>`, 'https://www.ticketone.it/checkout.html');
    const p = f.read(); assert.equal(p.stage, 'checkout'); assert.deepEqual(p.summary, ['Concerto A Platea, Fila 9, Posto 28']);
    assert.equal(p.fields[0].value, false); f.close();
  });
  await test('general admission is preserved without invented row or seat', async () => {
    const f = fixture(`<div data-qa="order-position"><div data-qa="event-information">Concerto B Posto Unico</div></div><button>Vai alla spedizione</button>`, 'https://www.ticketone.it/checkout.html');
    assert.deepEqual(f.read().summary, ['Concerto B Posto Unico']); f.close();
  });
  await test('registration projects personal fields, descriptions and separate optional consents', async () => {
    const f = fixture(`<ev-registration-page><h1>Crea account</h1><form><label for="email">Email</label><input id="email" type="email" required><label for="password">Password</label><input id="password" type="password" required aria-describedby="rules"><p id="rules">Almeno 12 caratteri</p><label for="name">Nome</label><input id="name" required><label for="country">Paese</label><select id="country"><option value="IT">Italia</option></select><label for="marketing">Consenso marketing facoltativo</label><input id="marketing" type="checkbox"><button data-qa="registration-button">Registrati</button></form></ev-registration-page>`, 'https://www.ticketone.it/dashboard/login/register');
    let submits = 0; f.doc.querySelector('form').onsubmit = e => { e.preventDefault(); submits++; };
    const p = f.read(); assert.equal(p.stage, 'registration'); assert.equal(p.fields.length, 5);
    assert.equal(p.fields[1].hint, 'Almeno 12 caratteri'); assert.equal(p.fields[1].secret, true);
    assert.equal(p.fields[4].value, false); assert.equal(submits, 0);
    assert.equal((await f.act(p, 'a0', { f0: 'person@example.test', f1: 'Synthetic-test-password', f2: 'Persona' })).status, 'submitted');
    assert.equal(submits, 1); assert.equal(f.doc.querySelector('#marketing').checked, false);
    assert.equal(f.read().fields[1].value, ''); f.close();
  });
  await test('registration server validation errors remain visible and no automatic resubmit occurs', async () => {
    const f = fixture(`<ev-registration-page><form novalidate><label for="name">Nome</label><input id="name" required><button data-qa="registration-button">Registrati</button><ev-forms-field-error>Inserisci il nome</ev-forms-field-error></form></ev-registration-page>`, 'https://www.ticketone.it/dashboard/login#/register');
    let submits = 0; f.doc.querySelector('form').onsubmit = e => { e.preventDefault(); submits++; };
    const p = f.read(); assert(p.errors.includes('Inserisci il nome'));
    assert.equal((await f.act(p, 'a0')).status, 'submitted');
    assert.equal((await f.act(p, 'a0')).status, 'stale'); assert.equal(submits, 1); f.close();
  });
  await test('foreign providers and card data are not projected', async () => {
    const foreign = fixture('<input type="password">', 'https://www.paypal.com/checkout'); assert.equal(foreign.read().status, 'foreign'); foreign.close();
    const card = fixture('<input autocomplete="cc-number">', 'https://www.ticketone.it/checkout.html'); assert.equal(card.read().status, 'payment-provider'); card.close();
  });
  console.log(`${passed} DOM tests passed`);
})().catch(e => { console.error(e); process.exitCode = 1; });
