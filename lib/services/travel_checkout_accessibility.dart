/// Simplify only identified decorative payment labels and the RevPoints toggle.
/// Never click, scroll, focus, submit, hide fields or enter provider frames.
const travelCheckoutAccessibilityScript = r'''
(() => {
  const result = (status, radios=0, decorations=0, promotions=0) =>
    JSON.stringify({status,radios,decorations,promotions});
  if (location.protocol !== 'https:' || (location.port && location.port !== '443') ||
      !['omio.com','www.omio.com'].includes(location.hostname) ||
      !/\/checkout\/?$/.test(location.pathname)) return result('outside-checkout');
  const norm = s => (s || '').toLowerCase().replace(/\s+/g,' ').trim();
  const visible = el => {
    const r=el.getBoundingClientRect(),s=getComputedStyle(el);
    return r.width>0 && r.height>0 && s.display!=='none' && s.visibility!=='hidden';
  };
  if ([...document.querySelectorAll('[aria-modal="true"],dialog[open]')].some(visible)) return result('modal');
  const known = new Map([['paypal','PayPal'],['carta','Carta'],['card','Card'],
    ['apple pay','Apple Pay'],['google pay','Google Pay'],['revolut pay','Revolut Pay']]);
  let radios=0,decorations=0,promotions=0;
  const set = (el,key,value) => {if(el.getAttribute(key)!==value) el.setAttribute(key,value);};
  const hide = el => {set(el,'aria-hidden','true');set(el,'tabindex','-1');};
  for (const radio of document.querySelectorAll('input[type="radio"]')) {
    const labels=[...(radio.labels || [])];
    const names=[radio.getAttribute('aria-label'),...labels.map(x=>x.textContent)]
      .map(norm).filter(x=>known.has(x));
    const unique=[...new Set(names)];
    if(unique.length!==1 || !labels.length) continue;
    const name=unique[0];
    // The live input retains native checked/disabled semantics and its handler.
    set(radio,'aria-label',known.get(name));
    radios++;
    for(const label of labels) {
      for(const el of label.querySelectorAll('img,svg,span')) {
        if(el.contains(radio) || el.querySelector('input,select,textarea,button,a,iframe,[role],[tabindex]')) continue;
        if(el.closest('a,button,[role="button"]')) continue;
        const text=norm(el.getAttribute('alt') || el.getAttribute('aria-label') || el.textContent);
        if(text!==name && !['visa','mastercard','maestro'].includes(text)) continue;
        hide(el);decorations++;
      }
    }
  }
  // Exact promotion only. Never infer from a Revolut iframe/domain or hide
  // a wrapper that may also contain payment controls, terms or form fields.
  for(const el of document.querySelectorAll('button[type="button"],[role="button"]')) {
    if(norm(el.getAttribute('aria-label') || el.textContent)!=='revpoints') continue;
    if(el.closest('label,[role="radio"],[role="dialog"],[aria-modal="true"]') ||
      el.querySelector('input,select,textarea,iframe,a,button,[role="radio"]')) continue;
    hide(el);promotions++;
  }
  return result('simplified',radios,decorations,promotions);
})()
''';
