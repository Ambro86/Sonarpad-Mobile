/// Simplify only identified decorative payment labels and the RevPoints toggle.
/// Never click, scroll, focus, submit, hide fields or enter provider frames.
const travelCheckoutAccessibilityScript = r'''
(() => {
  const result = (status, radios=0, decorations=0, promotions=0, frames=0, wrappers=0) =>
    JSON.stringify({status,radios,decorations,promotions,frames,wrappers});
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
  let radios=0,decorations=0,promotions=0,frames=0,wrappers=0;
  const set = (el,key,value) => {if(el.getAttribute(key)!==value) el.setAttribute(key,value);};
  const hide = el => {set(el,'aria-hidden','true');set(el,'tabindex','-1');};
  const selectionState=window.__sonarpadPaymentSelection ||= {radios:new WeakSet(),listening:false,pending:false};
  const syncSelection=()=>{
    if(!['omio.com','www.omio.com'].includes(location.hostname) || !/\/checkout\/?$/.test(location.pathname)) return;
    for(const radio of document.querySelectorAll('input[type="radio"]')) {
      if(selectionState.radios.has(radio)) set(radio,'aria-checked',String(radio.checked));
    }
  };
  if(!selectionState.listening) {
    selectionState.listening=true;
    // Read after Omio's focus/change handlers, including their microtasks.
    // Never change checked, dispatch an event or trigger payment.
    for(const event of ['focusin','input','change','click']) document.addEventListener(event,()=>{
      if(selectionState.pending) return;
      selectionState.pending=true;
      requestAnimationFrame(()=>{selectionState.pending=false;syncSelection();});
    },true);
  }

  for (const radio of document.querySelectorAll('input[type="radio"]')) {
    const labels=[...(radio.labels || [])];
    const names=[radio.getAttribute('aria-label'),...labels.map(x=>x.textContent)]
      .map(norm).filter(x=>known.has(x));
    const unique=[...new Set(names)];
    if(unique.length!==1 || !labels.length) continue;
    const name=unique[0];
    // The live input retains native checked/disabled semantics and its handler.
    set(radio,'aria-label',known.get(name));
    selectionState.radios.add(radio);
    set(radio,'aria-checked',String(radio.checked));
    radios++;
    // Omio nests a native radio, separate label/title and logos in a link.
    // Keep the native input as the single payment selection control.
    const wrapper=radio.closest('a');
    const safeWrapper=wrapper && wrapper.querySelectorAll('input[type="radio"]').length===1 &&
      !wrapper.querySelector('input:not([type="radio"]),select,textarea,button,[role="button"],a');
    if(safeWrapper) {
      set(wrapper,'role','group');
      set(wrapper,'tabindex','-1');
      wrappers++;
    }
    for(const label of labels) {
      if(!label.contains(radio) && !label.querySelector('input,select,textarea,button,a,iframe,[role],[tabindex]')) {
        hide(label);decorations++;
      } else {
        for(const el of label.querySelectorAll('img,svg,span,h6')) {
          if(el.contains(radio) || el.querySelector('input,select,textarea,button,a,iframe,[role],[tabindex]')) continue;
          if(el.closest('button,[role="button"]')) continue;
          const text=norm(el.getAttribute('alt') || el.getAttribute('aria-label') || el.textContent);
          if(text!==name && !['visa','mastercard','maestro'].includes(text)) continue;
          hide(el);decorations++;
        }
      }
    }
    if(safeWrapper) {
      for(const image of wrapper.querySelectorAll('img,svg')) {
        const text=norm(image.getAttribute('alt') || image.getAttribute('aria-label') || image.textContent);
        if(text===name || ['visa','mastercard','maestro'].includes(text)) {hide(image);decorations++;}
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
  // Explicit promotion reported by the user, not the Revolut payment method.
  // Match the complete short label, never a page/container containing it.
  const doublePoints = text => /^(?:guadagna\s+(?:2|due)\s*(?:volte|x)\s*(?:i\s+)?rev\s*points|earn\s+2\s*(?:x|times)\s+rev\s*points)[.!]?$/.test(norm(text));
  for(const el of document.querySelectorAll('span,p,div,a,button,iframe')) {
    if(![el.getAttribute('aria-label'),el.getAttribute('title'),el.textContent].some(doublePoints)) continue;
    if(el.matches('button:not([type="button"])') ||
      el.closest('label,[role="radio"],[role="dialog"],[aria-modal="true"]') ||
      el.querySelector('input,select,textarea,iframe,button:not([type="button"]),[role="radio"]')) continue;
    // A named frame can be excluded without inspecting its external content.
    // Unnamed frames remain untouched, regardless of their provider.
    hide(el);
    for(const child of el.querySelectorAll('a,button,[tabindex]')) set(child,'tabindex','-1');
    promotions++;
  }
  return result('simplified',radios,decorations,promotions,frames,wrappers);
})()
''';
