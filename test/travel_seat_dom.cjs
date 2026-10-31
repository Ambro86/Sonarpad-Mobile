// node test/travel_seat_dom.cjs <path-to-jsdom>
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {JSDOM} = require(process.argv[2] || 'jsdom');
const source = fs.readFileSync(path.join(__dirname, '../lib/services/travel_seat_script.dart'), 'utf8');
function script(action = null) {
  return source.split("'''")[1].replace('${jsonEncode(action)}', JSON.stringify(action))
    .replace('${jsonEncode(labels)}', 'null').replace('$italian', 'true').replace(/\\\$/g, '$').replace(/\\\\/g, '\\');
}
const dom = new JSDOM(`<button data-e2e="seatMapLauncherBtn">Seleziona posto</button>
  <button id="pay">Paga</button><div role="dialog">
  <div data-e2e="seatmapWrapper">
  <button data-seat-place="Coach 1 Seat 3A" aria-selected="true">3A</button>
  <button data-seat-place="Coach 1 Seat 3B" aria-disabled="true">3B</button>
  </div><p>Posto 3A, Anteriore, supplemento 2,89 EUR</p>
  <button data-e2e="seatmaps-modal-cta">Conferma +2,89 EUR</button></div>`,
  {url:'https://www.omio.com/app/booking/test/checkout',runScripts:'outside-only'});
const w = dom.window;
w.HTMLElement.prototype.getClientRects = function () { return this.hidden ? [] : [{}]; };
const read = action => JSON.parse(w.eval(script(action)));
let data = read();
assert.equal(data.status, 'dialog');
assert.equal(data.controls.length, 3);
assert.equal(data.controls[0].label, 'Carrozza 1, posto 3A');
assert.equal(data.controls[0].selected, true);
assert.equal(data.controls[1].enabled, false);
assert.match(data.summary, /2,89 EUR/);
assert.ok(!data.controls.some(c => /Paga/.test(c.label)));
assert.equal(read(data.controls[1].id).status, 'stale');
let clicks = 0;
const seat = w.document.querySelector('[data-seat-place]');
seat.onclick = () => clicks++;
assert.equal(read(data.controls[0].id).status, 'clicked');
assert.equal(clicks, 1);
seat.replaceWith(seat.cloneNode(true));
assert.equal(read(data.controls[0].id).status, 'stale');
assert.equal(read('pay').status, 'stale');
const confirm = w.document.querySelector('[data-e2e="seatmaps-modal-cta"]');
confirm.textContent = 'Conferma +4,99 EUR';
assert.equal(read(data.controls[2].id).status, 'stale');
assert.equal(read().controls[2].label, 'Conferma +4,99 EUR');
w.document.querySelector('[role=dialog]').remove();
assert.equal(read().status, 'closed');
assert.equal(read().available, true);
dom.reconfigure({url:'https://www.omio.com.evil.test/'});
assert.equal(read('open').status, 'outside');
w.close();
console.log('PASS seats: labels, price, selection, disabled, stale nodes, payment isolation, origin');
