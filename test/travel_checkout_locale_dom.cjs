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

// Terms are a separate prerequisite, not the PayPal payment action.
const terms = source.split("const _bookingTerms = r" + "'".repeat(3))[1].split("'".repeat(3) + ";")[0];
for (const text of ['Ho letto e accettato i termini e le condizioni di Omio.', 'I have read and accept the terms and conditions.']) {
 const dom=new JSDOM('<label><input id="terms" type="checkbox"><span id="terms-label"></span></label><label><input id="marketing" type="checkbox">Accetto le condizioni delle offerte marketing</label><label><input id="privacy" type="checkbox">Ho letto l’informativa sulla privacy</label><button id="pay" type="submit">PayPal</button>',{url:'https://www.omio.com/app/booking/test/checkout',runScripts:'outside-only'});
 const w=dom.window,d=w.document;
 w.HTMLElement.prototype.getBoundingClientRect=function(){return {width:100,height:20}};
 d.getElementById('terms-label').textContent=text;
 let payments=0, clicks=0;
 d.getElementById('pay').onclick=()=>payments++;
 const checkbox=d.getElementById('terms');checkbox.onclick=()=>clicks++;
 assert.equal(w.eval(terms.replaceAll('__VERIFY__','false')),'selected');
 assert.equal(checkbox.checked,true);
 assert.equal(w.eval(terms.replaceAll('__VERIFY__','false')),'selected');
 assert.equal(clicks,1,'An accepted checkbox must never be toggled off');
 assert.equal(d.getElementById('marketing').checked,false);
 assert.equal(d.getElementById('privacy').checked,false);
 assert.equal(payments,0);
 checkbox.checked=false;checkbox.disabled=true;
 assert.equal(w.eval(terms.replaceAll('__VERIFY__','false')),'disabled');assert.equal(clicks,1);
 checkbox.disabled=false;
 const modal=d.createElement('div');modal.setAttribute('aria-modal','true');d.body.append(modal);
 assert.equal(w.eval(terms.replaceAll('__VERIFY__','false')),'blocked');assert.equal(clicks,1);modal.remove();
 const duplicate=checkbox.parentElement.cloneNode(true);d.body.append(duplicate);
 assert.equal(w.eval(terms.replaceAll('__VERIFY__','false')),'ambiguous');assert.equal(clicks,1);duplicate.remove();
 checkbox.parentElement.style.display='none';checkbox.style.display='none';
 assert.equal(w.eval(terms.replaceAll('__VERIFY__','false')),'not-found');assert.equal(clicks,1);
 checkbox.parentElement.style.display='';checkbox.style.display='';
 dom.reconfigure({url:'https://www.paypal.com/checkout'});
 assert.equal(w.eval(terms.replaceAll('__VERIFY__','false')),'unavailable');assert.equal(clicks,1);
 dom.window.close();
}
console.log('PASS booking terms: required checkbox only, idempotence, disabled/modal/ambiguous/hidden/provider guards');

// Reproduce the report: zero viewport at selection, then a delayed terms control.
// The PayPal button is a provider frame and must survive all of these operations.
{
 const dom=new JSDOM('<label for="paypal">PayPal</label><input id="paypal" type="radio" name="payment"><iframe id="paypal-button" title="PayPal" src="https://www.paypal.com/smart/buttons"></iframe><button id="pay" type="submit">Pay</button>',{url:'https://www.omio.com/app/booking/test/checkout',runScripts:'outside-only'});
 const w=dom.window,d=w.document;
 w.HTMLElement.prototype.getBoundingClientRect=function(){return {width:100,height:20}};
 const frame=d.getElementById('paypal-button'), originalFrame=frame.outerHTML;
 let payments=0, radioClicks=0, termsClicks=0;
 d.getElementById('pay').onclick=()=>payments++;
 d.getElementById('paypal').onclick=()=>radioClicks++;
 const select=()=>JSON.parse(w.eval(payment.replace('__SELECTION__','"PayPal"'))).status;
 const accept=(verifyOnly=false)=>w.eval(terms.replaceAll('__VERIFY__',String(verifyOnly)));
 w.innerWidth=0;w.innerHeight=0;
 assert.equal(select(),'not-ready');assert.equal(radioClicks,0);
 assert.equal(accept(),'not-ready');
 w.innerWidth=390;w.innerHeight=707;
 assert.equal(select(),'selected');assert.equal(radioClicks,1);
 assert.equal(accept(),'not-found');
 d.body.insertAdjacentHTML('beforeend','<label for="late-terms">Ho letto e accettato i termini e le condizioni.</label><input id="late-terms" type="checkbox">');
 const checkbox=d.getElementById('late-terms');
 // Simulate a framework that commits the checked value asynchronously.
 checkbox.onclick=e=>{termsClicks++;e.preventDefault();};
 assert.equal(accept(),'unconfirmed');assert.equal(termsClicks,1);
 assert.equal(accept(true),'unconfirmed');assert.equal(termsClicks,1);
 checkbox.checked=true;
 assert.equal(accept(true),'selected');assert.equal(termsClicks,1);
 assert.equal(d.getElementById('paypal-button'),frame);
 assert.equal(frame.outerHTML,originalFrame);
 assert.notEqual(d.activeElement,frame);
 assert.equal(payments,0);
 dom.window.close();
}
console.log('PASS zero viewport, late terms, asynchronous confirmation; PayPal iframe preserved, no payment submitted');
