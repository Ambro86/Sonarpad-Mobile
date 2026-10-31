const assert = require('node:assert/strict');
const fs = require('node:fs');
const {JSDOM} = require(process.argv[2] || 'jsdom');
const source = fs.readFileSync('lib/services/travel_payment_script.dart','utf8');
const protection = source.split("const _noProtection = r\'\'\'")[1].split("\'\'\';")[0];
const payment = source.split("const _script = r\'\'\'")[1].split("\'\'\';")[0];
const accessibility = fs.readFileSync('lib/services/travel_checkout_accessibility.dart','utf8').split("r\'\'\'")[1].split("\'\'\';")[0];
const cases=JSON.parse(fs.readFileSync('test/fixtures/travel_checkout_locales.json','utf8'));
for(const test of cases) {
 const dom=new JSDOM('<button id="none" type="button" aria-pressed="false"></button><label for="card"></label><input id="card" type="radio" name="payment"><label for="paypal">PayPal</label><input id="paypal" type="radio" name="payment"><button id="pay" type="submit">Pay</button>',{url:'https://www.omio.com/app/booking/test/checkout',runScripts:'outside-only'});
 const w=dom.window,d=w.document;
 w.HTMLElement.prototype.getBoundingClientRect=function(){return {width:100,height:20}};
 const none=d.getElementById('none');none.textContent=test.noProtection;
 d.querySelector('label[for=card]').textContent=test.card;
 let clicks=0,payments=0;none.onclick=()=>{clicks++;none.setAttribute('aria-pressed','true');none.disabled=true;};
 d.getElementById('pay').onclick=()=>payments++;
 assert.equal(w.eval(protection.replaceAll('__VERIFY__','false')),'selected',test.locale);
 assert.equal(w.eval(protection.replaceAll('__VERIFY__','true')),'selected',test.locale);
 assert.equal(clicks,1);
 const read=()=>JSON.parse(w.eval(payment.replace('__SELECTION__','null')));
 assert.deepEqual(Array.from(read().methods),['card','PayPal']);
 assert.equal(JSON.parse(w.eval(payment.replace('__SELECTION__','"PayPal"'))).status,'selected');
 w.eval(accessibility);
 assert.equal(d.getElementById('paypal').getAttribute('aria-checked'),'true');
 assert.equal(d.querySelector('label[for=card]').getAttribute('aria-hidden'),'true');
 assert.equal(payments,0);
 // Unknown text, duplicate choices and modal dialogs never cause guessed clicks.
 none.disabled=false;none.setAttribute('aria-pressed','false');none.textContent='Unrecognised protection choice';
 assert.equal(w.eval(protection.replaceAll('__VERIFY__','false')),'not-found');assert.equal(clicks,1);
 none.textContent=test.noProtection;d.body.append(none.cloneNode(true));
 assert.equal(w.eval(protection.replaceAll('__VERIFY__','false')),'ambiguous');assert.equal(clicks,1);
 dom.window.close();console.log('PASS',test.locale,'protection, payment, accessibility, unknown/ambiguous guards');
}
