import 'dart:convert';

/// Read public event metadata even when ticket controls are unavailable.
/// Hidden accordion copies can be empty while another copy is populated.
const ticketOneOrganiserScript = r'''
(() => {
  if (location.origin !== 'https://www.ticketone.it' || !location.pathname.startsWith('/event/') || window.top !== window)
    return JSON.stringify({status:'waiting'});
  const norm = value => String(value || '').replace(/\s+/g, ' ').trim();
  const organiser = Array.from(document.querySelectorAll('[data-qa="promoter-address"]'))
    .map(el => norm(el.textContent)).find(value => value.length > 0 && value.length <= 1500) || '';
  const eventTitle = norm(document.querySelector('h1')?.textContent).slice(0,500);
  return JSON.stringify({status:organiser ? 'ready' : 'waiting',organiser,eventTitle,path:location.pathname});
})()
''';

/// Remove observed advertising frames, not payment, login or security frames.
/// Advertising SVG titles such as Asset_14_1 are exposed inside these frames.
const ticketOneRemoveAdsScript = r'''
(() => {
  if (!['https://www.ticketone.it', 'https://auth.ticketone.it'].includes(location.origin) || window.top !== window) return;
  if (window.__sonarpadTicketOneAds) { window.__sonarpadTicketOneAds(); return; }
  const clean = () => {
    for (const frame of document.querySelectorAll('iframe')) {
      let host = '';
      try { host = new URL(frame.src, location.href).hostname; } catch (_) {}
      const adHost = ['googlesyndication.com', 'doubleclick.net'].some(h => host === h || host.endsWith('.' + h));
      const adId = /^google_ads_iframe_|^google_ads_top_frame$/.test(frame.id);
      const adTitle = /^(contenuto dell['’]annuncio di terze parti|3rd party ad content|third.party ad content)$/i.test(frame.title.trim());
      if (!adHost && !adId && !adTitle) continue;
      if (frame.getAttribute('aria-hidden') !== 'true') frame.setAttribute('aria-hidden', 'true');
      if (frame.tabIndex !== -1) frame.tabIndex = -1;
      if (!frame.inert) frame.inert = true;
      if (frame.style.getPropertyValue('display') !== 'none' || frame.style.getPropertyPriority('display') !== 'important') {
        frame.style.setProperty('display', 'none', 'important');
      }
    }
  };
  window.__sonarpadTicketOneAds = clean;
  let queued = false;
  new MutationObserver(() => {
    if (queued) return;
    queued = true;
    setTimeout(() => { queued = false; clean(); }, 200);
  }).observe(document.documentElement, {subtree:true, childList:true, attributes:true, attributeFilter:['src','title','id','style']});
  clean();
})();
''';

/// Move accessibility into the revealed document instead of leaving TalkBack on
/// Flutter's Back button. Focus only: never activate a control or submit a form.
const ticketOneWebsiteFocusScript = r'''
(() => {
  if (!['https://www.ticketone.it', 'https://auth.ticketone.it'].includes(location.origin) || window.top !== window) return;
  const visible = e => e && e.getClientRects().length > 0 &&
    getComputedStyle(e).display !== 'none' && getComputedStyle(e).visibility !== 'hidden' &&
    !e.closest('[hidden], [aria-hidden="true"]');
  const dialog = [...document.querySelectorAll('[role="dialog"], [aria-modal="true"]')].find(visible);
  const paypal = !dialog && document.querySelector('[data-qa="summary-page"]') &&
    document.querySelector('iframe[title="PayPal-paypal"]');
  const root = dialog || document;
  const heading = [...root.querySelectorAll('h1,h2,[role="heading"]')].find(visible);
  const target = (visible(paypal) && paypal) || heading || dialog || document.body;
  if (!target) return;
  if (target === paypal) target.setAttribute('aria-label', 'PayPal');
  if (!target.hasAttribute('tabindex')) target.setAttribute('tabindex', '-1');
  target.scrollIntoView({block: 'center'});
  target.focus({preventScroll: true});
})();
''';

/// Projects the site's real controls; never builds an order from guessed API
/// parameters. Hidden fields, credentials and payment frames stay on the site.
const ticketOneUiSnapshotScript = r'''
(() => {
  const allowed = ['https://www.ticketone.it', 'https://auth.ticketone.it'];
  if (!allowed.includes(location.origin) || window.top !== window) return JSON.stringify({status:'foreign'});
  const norm = s => (s || '').replace(/\s+/g, ' ').trim();
  const visible = e => !!e && e.isConnected && getComputedStyle(e).display !== 'none' &&
    getComputedStyle(e).visibility !== 'hidden' && e.getClientRects().length > 0 &&
    !e.closest('[hidden], .hidden');
  const label = e => norm(e.getAttribute('aria-label') ||
    (e.labels && [...e.labels].map(l => l.textContent).join(' ')) ||
    (e.getAttribute('aria-labelledby') || '').split(' ').map(id => document.getElementById(id)?.textContent || '').join(' ') ||
    e.getAttribute('placeholder') || e.getAttribute('title') || e.textContent ||
    (['submit','button'].includes(e.type) ? e.value : ''));
  const usable = e => visible(e) || (!!e && ['radio','checkbox'].includes(e.type) &&
    !e.closest('[hidden], .hidden') && [...(e.labels || [])].some(visible));
  const path = location.pathname;
  const login = location.hostname === 'auth.ticketone.it';
  const externalProfile = !login && path === '/external-customer-data/';
  const registration = externalProfile || (!login && path.startsWith('/dashboard/') &&
    !!document.querySelector('ev-registration-page'));
  const event = !login && path.startsWith('/event/');
  const checkout = !login && path === '/checkout.html';
  const errorPage = !login && /^\/error\/?$/.test(path);
  const review = checkout && !!document.querySelector('[data-qa="summary-page"]');
  let root = login ? document.querySelector('#mainContainer, #kc-content, #kc-form-login, #kc-register-form, #kc-otp-login-form, form') :
    registration ? (externalProfile ? document.querySelector('app-external-customer-data-form') : document.querySelector('ev-registration-page')) :
    event ? (document.querySelector('#tickets-bestseat-tab') || document.querySelector('.js-ticket-selection-with-limits')?.closest('form')) :
    errorPage ? document.querySelector('main, [role="main"]') :
    checkout ? document.querySelector('main, [role="main"], app-root') || document.body : null;
  // Structural diagnostics only: never text, values, URLs, tokens or attributes.
  const diagnostic = (status, reason) => JSON.stringify({status, diagnostics:{
    reason, page:login?'login':registration?'registration':event?'event':errorPage?'error':checkout?'checkout':path.startsWith('/dashboard')?'account':'other',
    ready:document.readyState, root:!!root,
    forms:document.forms.length, frames:document.querySelectorAll('iframe').length,
    controls:document.querySelectorAll('input,select,textarea').length,
    dialogs:[...document.querySelectorAll('[role="dialog"], [aria-modal="true"]')].filter(visible).length,
    customCombos:[...document.querySelectorAll('[role="combobox"]')].filter(visible).length,
    cookies:[...document.querySelectorAll('#cmpbox, #onetrust-banner-sdk, #CybotCookiebotDialog')].filter(visible).length
  }});
  // The identity server can return an HTML denial instead of the next form.
  // This is not a slowly loading login page and must not be polled as one.
  if (login && /^access denied$/i.test(norm(document.title))) {
    window.__sonarpadTicketOneUi = null;
    return diagnostic('access-denied', 'access_denied');
  }
  // The live event page opens this modal after AddToShoppingCart. It covers
  // the ticket form: never offer that underlying form as if it were usable.
  if ([...document.querySelectorAll('.js-cc-layer')].some(visible)) {
    window.__sonarpadTicketOneUi = null;
    return diagnostic('security-check', 'security_check');
  }
  if (!root) return diagnostic('waiting', 'root_missing');
  if (checkout || registration) {
    const dialog = [...document.querySelectorAll('[role="dialog"], [aria-modal="true"]')]
      .find(e => visible(e) && !e.closest('#cmpbox, #onetrust-banner-sdk, #CybotCookiebotDialog'));
    if (dialog) root = dialog;
  }
  const outside = e => e.closest('header, footer, nav, #cmpbox, #onetrust-banner-sdk, [aria-hidden="true"]');
  const controls = [...root.querySelectorAll('input,select,textarea,[role="radio"],[role="checkbox"]')].filter(e =>
    usable(e) && !outside(e) && !['hidden','submit','button','reset','image'].includes(e.type));
  // Do not present a partial checkout as complete when the page requires widgets
  // we cannot represent (card frames, seat maps, custom comboboxes, file uploads).
  const unsupported = controls.some(e => ['file','range','color'].includes(e.type)) ||
    [...root.querySelectorAll('[role="combobox"]')].some(e => visible(e) && e.tagName !== 'SELECT' &&
      !e.querySelector('input:disabled'));
  if (unsupported || controls.length > 60) return diagnostic('unsupported', controls.length > 60 ? 'control_limit' : 'custom_control');
  if (controls.some(e => /^cc-/.test(e.autocomplete || '') || /card.?number|creditcard|cvv|cvc/i.test(e.name || e.id))) return diagnostic('payment-provider', 'payment_fields');
  const revision = Date.now().toString(36) + Math.random().toString(36).slice(2);
  const nodes = new Map(), fields = [];
  const categoryLabel = e => norm(e.closest('form')?.querySelector('.pc-list-category')?.textContent ||
    (e.closest('form')?.getAttribute('data-qa') || '').replace(/^pc-list-number-/, ''));
  const remember = (key, e) => nodes.set(key, {e, type:e.type, name:e.name, text:label(e)});
  for (const e of controls) {
    const id = 'f' + fields.length;
    let text = label(e);
    if (!text || text.length > 1200) return diagnostic('unsupported', !text ? 'missing_label' : 'label_limit');
    if (event && e.dataset.pcTitle) text = norm(e.dataset.pcTitle + ' — ' + text);
    else if (event && categoryLabel(e)) text = categoryLabel(e) + ' — ' + text;
    const consent = e.closest('.evi-widget')?.querySelector('.evi-widget-text-below');
    if (consent) text += ' — ' + norm(consent.textContent);
    const role = e.getAttribute('role');
    const kind = e.tagName === 'SELECT' ? 'select' : ['radio','checkbox'].includes(role) ? role : e.type === 'checkbox' || e.type === 'radio' ? e.type : 'text';
    const otpDigit = login && /^(first|second|third|fourth|fifth|sixth) digit$/i.test(text);
    const secret = otpDigit || e.type === 'password' || e.autocomplete === 'one-time-code' || /otp|totp|verification.?code/i.test(e.name || e.id);
    fields.push({id, label:text, kind, type:e.type || 'text', required:e.required,
      keyboard:e.type === 'email' || e.autocomplete === 'email' ? 'email' : e.type === 'tel' || /phone|mobile/i.test(e.name || e.id) ? 'phone' : e.type === 'number' || e.inputMode === 'numeric' || /postal|zipcode|postcode/i.test(e.name || e.id) ? 'number' : null,
      enabled:!e.disabled && e.getAttribute('aria-disabled') !== 'true', secret,
      hint:norm((e.getAttribute('aria-describedby') || '').split(/\s+/).map(id => document.getElementById(id)?.textContent || '').join(' ')),
      value:kind === 'checkbox' || kind === 'radio' ? ['radio','checkbox'].includes(role) ? e.getAttribute('aria-checked') === 'true' : e.checked : secret ? '' : e.value,
      options:kind === 'select' ? [...e.options].filter(o => !o.disabled).map(o => ({value:o.value,label:norm(o.textContent)})) : []});
    remember(id,e);
  }
  let candidates = [];
  if (login) candidates = [...root.querySelectorAll('button, input[type="submit"], a')];
  if (registration) candidates = [...root.querySelectorAll('button, input[type="submit"], [role="button"]')]
    .filter(e => e.matches('[data-qa="registration-button"]') ||
      (externalProfile && e.matches('[data-qa="save-data-button"]')) ||
      !!e.closest('[data-qa="registration-button"], ev-pl-button[dataqa="registration-button"]') ||
      /^(registrati|crea account|crea un account|conferma|continua|invia codice|verifica|register|create account|verify|continue)$/i.test(label(e)));
  if (errorPage) candidates = [...root.querySelectorAll('.back-link a')];
  if (event) candidates = [...root.querySelectorAll('[data-qa="AddToShoppingCart"], [data-qa="add-to-shopping-cart"], .js-stepper [data-qa="less-tickets"], .js-stepper [data-qa="more-tickets"]')];
  const checkoutActions = /^(vai alla spedizione|conferma la tua scelta|salva e vai al pagamento|conferma i dati|continua|prosegui|salva|avanti|elimina biglietti|continue|next|save|go to delivery|confirm your choice)$/i;
  if (checkout) candidates = [...root.querySelectorAll('button, a, input[type="submit"], [role="button"]')].filter(e =>
    checkoutActions.test(label(e)) || (/^Carrello\b/i.test(document.title) && /^Procedi con l['’]acquisto$/i.test(label(e))));
  const actions = [];
  for (const e of candidates) {
    if (!visible(e) || outside(e)) continue;
    let text = norm(e.tagName === 'INPUT' ? e.value : e.textContent || e.getAttribute('aria-label'));
    const ticketStepper = event && e.matches('.js-stepper [data-qa="less-tickets"], .js-stepper [data-qa="more-tickets"]');
    if (ticketStepper) {
      const stepper = e.closest('.js-stepper');
      const ticket = e.closest('.js-ticket-type-item');
      const amount = norm(stepper.querySelector('.js-stepper-amount-text')?.textContent) ||
        stepper.querySelector('input.js-stepper-amount')?.value;
      const details = norm(ticket?.querySelector('.ticket-type-title')?.textContent);
      const price = norm(ticket?.querySelector('[data-qa="tickettypeItem-price"]')?.textContent);
      text = [e.dataset.qa === 'more-tickets' ? 'Aumenta biglietti' : 'Diminuisci biglietti',
        details, price, /^\d+$/.test(amount || '') ? 'Quantità ' + amount : ''].filter(Boolean).join(' — ');
    }
    if (event && text && categoryLabel(e)) text += ' — ' + categoryLabel(e);
    if (!text || text.length > 500 || actions.some(a => a.label === text)) continue;
    // Auth-only links (OTP, password reset); never project arbitrary links.
    if (login && e.tagName === 'A' && !/codice|code|password|registr|account|acced|sign in/i.test(text)) continue;
    const id = 'a' + actions.length;
    actions.push({id,label:text,enabled:!e.disabled && e.getAttribute('aria-disabled') !== 'true',
      submit:!ticketStepper && e.tagName !== 'A' && (e.type === 'submit' || e.hasAttribute('data-qa') || checkout || registration)});
    remember(id,e);
  }
  const unavailableCategories = event ? [...root.querySelectorAll('.ticket-type-item-wrapper-unavailable')]
    // Empty availability placeholders also exist in fast booking. Their form's
    // heading is the quantity instruction, not an unavailable ticket category.
    .filter(e => visible(e) && [...e.querySelectorAll('[data-qa="ticket-type-availability-hint"]')]
      .some(hint => visible(hint) && norm(hint.textContent))).map(e => ({
      category:norm(e.closest('form')?.querySelector('.pc-list-category')?.textContent ||
        (e.closest('form')?.getAttribute('data-qa') || '').replace(/^pc-list-number-/, '')),
      message:norm(e.querySelector('[data-qa="ticket-type-availability-hint"]')?.textContent)
    })) : [];
  if (!errorPage && !fields.length && !actions.length && !unavailableCategories.length) return diagnostic('waiting', 'controls_missing');
  const qty = event ? root.querySelector('[data-qa="TicketAmount"]') : null;
  const chosen = root.querySelector('input.js-fast-booking-item:checked') || root.querySelector('input.js-fast-booking-item');
  const quantity = qty && chosen ? {value:Number(qty.textContent),min:Number(chosen.dataset.min || 1),max:Number(chosen.dataset.max || 10)} : null;
  const errors = [...root.querySelectorAll('[role="alert"], .alert-error, .alert-danger, .kc-feedback-text, .error-message, .invalid-feedback, ev-forms-field-error, [data-qa="message"]')]
    .filter(visible).map(e => norm(e.textContent)).filter(Boolean).slice(0,8);
  const eventTitle = event ? norm(document.querySelector('h1')?.textContent).slice(0,500) : '';
  const organiser = event ? (Array.from(document.querySelectorAll('[data-qa="promoter-address"]')).map(el => norm(el.textContent)).find(value => value.length > 0 && value.length <= 1500) || '') : '';
  const title = norm(root.querySelector('h1,h2')?.textContent || document.querySelector('h1')?.textContent || document.title);
  const notices = [...root.querySelectorAll('#termsAndConditions, [data-qa="priceSum"], .evi-widget-text-above')].filter(visible)
    .map(e => norm(e.textContent)).filter(Boolean);
  // The cart's event-information includes the server-assigned sector/row/seat.
  // Restrict it to order positions: sidebar copies and insurance are separate.
  const summarySelector = review ? '[data-qa="order-overview"], [data-qa="order-fees"], [data-qa="total-order-sum"], [data-qa="delivery-method-summary"], [data-qa="customer-address-summary"], [data-qa="payment-method-summary"]' :
    checkout ? '[data-qa="order-position"] [data-qa="event-information"]' : null;
  const summary = summarySelector ? [...root.querySelectorAll(summarySelector)]
    .filter(visible).filter((e,_,all) => !all.some(parent => parent !== e && parent.contains(e)))
    .map(e => norm(e.innerText || e.textContent)).filter(Boolean) : [];
  const paypal = review && !!document.querySelector('iframe[title="PayPal-paypal"]');
  const banner = () => [...document.querySelectorAll('#cmpbox, #onetrust-banner-sdk, #CybotCookiebotDialog')].filter(visible);
  let consumed = false;
  window.__sonarpadTicketOneUi = {revision, run: async (request) => {
    if (consumed || request.revision !== revision || !allowed.includes(location.origin) || location.pathname !== path) return {status:'stale'};
    const checked = id => {
      const old = nodes.get(id);
      if (!old || !usable(old.e) || old.e.type !== old.type || old.e.name !== old.name || label(old.e) !== old.text) return null;
      return old.e;
    };
    const action = request.action === 'change' || request.action === 'quantity' ? null : checked(request.action);
    if (!action && !['change','quantity'].includes(request.action)) return {status:'stale'};
    const changes = Object.entries(request.values || {});
    for (const [id,value] of changes) {
      const e = checked(id), f = fields.find(f => f.id === id);
      if (!e || !f || e.disabled) return {status:'stale'};
      if (['checkbox','radio'].includes(f.kind) ? typeof value !== 'boolean' : typeof value !== 'string' || value.length > 10000) return {status:'invalid',field:id};
      if (f.kind === 'select' && !f.options.some(o => o.value === value)) return {status:'invalid',field:id};
    }
    // Explicit user consent is supplied only by a native Send/Continue action.
    if (request.acceptCookies === true) {
      for (const b of banner()) {
        const accept = [...b.querySelectorAll('button, a, [role="button"]')].filter(visible)
          .find(e => /^(accetta tutti i cookie|accetta tutti|accept all cookies|accept all|alle cookies akzeptieren)$/i.test(label(e)));
        if (!accept) return {status:'cookies-unavailable'};
        accept.click();
      }
      for (let i=0;i<20 && banner().length;i++) await new Promise(r=>setTimeout(r,150));
      if (banner().length) return {status:'cookies-visible'};
    }
    for (const [id,value] of changes) {
      const e = checked(id);
      if (!e) return {status:'stale'};
      if (['radio','checkbox'].includes(e.getAttribute('role'))) {
        if ((e.getAttribute('aria-checked') === 'true') !== value) e.click();
      } else if (e.type === 'checkbox' || e.type === 'radio') {
        if (e.checked !== value) e.click();
      } else {
        const proto = e.tagName === 'SELECT' ? HTMLSelectElement.prototype : e.tagName === 'TEXTAREA' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
        Object.getOwnPropertyDescriptor(proto,'value').set.call(e,value);
        e.dispatchEvent(new Event('input',{bubbles:true}));
        e.dispatchEvent(new Event('change',{bubbles:true}));
      }
    }
    if (request.action === 'change') { consumed = true; return {status:'changed'}; }
    if (request.action === 'quantity') {
      const target = request.quantity;
      if (!quantity || !Number.isInteger(target) || target < quantity.min || target > quantity.max) return {status:'invalid'};
      for (let i=0;i<20 && Number(qty.textContent)!==target;i++) {
        const e = root.querySelector(Number(qty.textContent)<target ? '[data-qa="MoreTickets"]' : '[data-qa="LessTickets"]');
        if (!e || e.disabled) return {status:'quantity-unavailable'};
        e.click(); await new Promise(r=>setTimeout(r,50));
      }
      consumed = true;
      return {status:Number(qty.textContent)===target?'changed':'quantity-unavailable'};
    }
    const current = checked(request.action);
    if (!current || current.disabled || current.getAttribute('aria-disabled') === 'true') return {status:'stale'};
    const model = actions.find(a=>a.id===request.action);
    if (model.submit && !current.formNoValidate && !current.form?.noValidate) {
      const invalid = controls.find(e => !e.disabled && typeof e.checkValidity === 'function' && (!current.form || e.form === current.form) && !e.checkValidity());
      if (invalid) return {status:'invalid',field:fields[controls.indexOf(invalid)].id};
    }
    // Never retry this click automatically, even when navigation loses the ack.
    consumed = true;
    current.click();
    return {status:'submitted'};
  }};
  return JSON.stringify({status:'ready',revision,stage:login?'login':registration?'registration':event?'event':errorPage?'error':review?'review':'checkout',title,eventTitle,organiser,fields,actions,quantity,errors,notices,summary,paypal,unavailableCategories});
})();
''';

String ticketOneUiActionScript(Map<String, dynamic> request, String id) =>
    '''
(() => {
  if (!['https://www.ticketone.it','https://auth.ticketone.it'].includes(location.origin) || window.top !== window) return;
  const send = value => TicketOneUi.postMessage(JSON.stringify({id:${jsonEncode(id)},...value}));
  const bridge = window.__sonarpadTicketOneUi;
  if (!bridge) { send({status:'stale'}); return; }
  bridge.run(${jsonEncode(request)}).then(send).catch(() => send({status:'unavailable'}));
})();
''';
