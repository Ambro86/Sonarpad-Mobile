const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {JSDOM} = require(process.argv[2] || 'jsdom');
const script = fs.readFileSync(path.join(__dirname,'../lib/services/ticketone_page_diagnostics.dart'),'utf8').split("= r'''")[1].split("''';")[0];
function fixture(html, url='https://www.ticketone.it/unknown/?code=QUERY_SECRET#FRAGMENT_SECRET') {
  const d = new JSDOM(html,{url,runScripts:'outside-only'});
  d.window.HTMLElement.prototype.getClientRects=function(){return [{}];};
  return d;
}
const d = fixture(`<title>Biglietti</title><main><h1>Scegli i posti</h1>
<form id="tickets" action="/checkout.html?token=ACTION_SECRET">
<input type="hidden" value="HIDDEN_SECRET"><input type="password" value="PASSWORD_SECRET">
<label for="email">Indirizzo email</label><input id="email" value="person@example.com">
<textarea>TEXTAREA_SECRET</textarea><input name="otp" value="123456">
<button data-qa="next">Continua</button><select aria-label="Quantità"><option>Uno</option><option>Due</option></select>
</form><div role="alert">Errore person@example.com 123456 PASSWORD_SECRET</div>
<div id="host"></div><iframe title="Pagamento" src="https://payment.example/path?session=FRAME_SECRET"></iframe>
<script>const token='SCRIPT_SECRET';</script><p>PRIVATE_ACCOUNT_SUMMARY</p></main>`);
d.window.document.cookie='session=COOKIE_SECRET';
d.window.localStorage.setItem('token','STORAGE_SECRET');
const shadow=d.window.document.getElementById('host').attachShadow({mode:'open'});
shadow.innerHTML='<button aria-label="Posto libero">Scegli</button>';
const report=JSON.parse(d.window.eval(script)), raw=JSON.stringify(report);
for (const secret of ['QUERY_SECRET','FRAGMENT_SECRET','ACTION_SECRET','HIDDEN_SECRET','PASSWORD_SECRET','TEXTAREA_SECRET','person@example.com','123456','FRAME_SECRET','SCRIPT_SECRET','COOKIE_SECRET','STORAGE_SECRET','PRIVATE_ACCOUNT_SUMMARY']) {
  assert(!raw.includes(secret), 'leaked '+secret);
}
assert(report.controls.some(c=>c.label==='Indirizzo email'));
assert(report.controls.some(c=>c.label==='Posto libero' && c.path.includes('/shadow/')));
assert(report.html.includes('data-qa="next"'));
assert(report.html.includes('id="tickets"'));
assert.equal(report.frames[0].readable,false);
assert.equal(report.frames[0].source.origin,'https://payment.example');
assert.equal(report.truncated,false);
assert.equal(report.location.path,'/unknown/');
assert.equal(report.headings[0].text,'Scegli i posti');
assert.equal(report.controls.find(c=>c.tag==='select').options.count,2);
assert.equal(d.window.document.querySelector('input[type=password]').value,'PASSWORD_SECRET');
d.window.close();
console.log('PASS structural HTML, controls, shadows, frame inventory, privacy and no mutation');
const huge=fixture('<main>'+ '<div class="item"><button>Vai</button></div>'.repeat(4000)+'</main>');
const bounded=JSON.parse(huge.window.eval(script));
assert(bounded.truncated); assert(bounded.nodes<=3500); assert(bounded.controlsTruncated);
huge.window.close();
console.log('PASS bounded capture explicitly reports truncation');
const foreign=fixture('<h1>Account</h1>','https://payment.example/');
assert.equal(JSON.parse(foreign.window.eval(script)).status,'foreign');
foreign.window.close();
console.log('PASS foreign provider is not inspected');
