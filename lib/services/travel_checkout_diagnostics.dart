/// Read-only, allowlisted checkout diagnostics. No text, URLs, identifiers,
/// input values, HTML, cookies or provider-frame content are exported.
const travelCheckoutDiagnosticsScript = r'''
(() => {
  if (location.protocol !== 'https:' || (location.port && location.port !== '443') ||
      !['omio.com', 'www.omio.com'].includes(location.hostname) ||
      !/\/checkout\/?$/.test(location.pathname)) return JSON.stringify({scope:'outside-checkout'});
  const normalize = s => (s || '').toLowerCase().replace(/\s+/g, ' ').trim();
  const labels = new Map([
    ['voglio viaggiare senza protezione','no-protection'],
    ['i want to travel without protection','no-protection'],
    ['travel without protection','no-protection'],
    ['paypal','paypal'], ['carta','card'], ['card','card'],
    ['carta di credito','card'], ['credit card','card'],
    ['apple pay','apple-pay'], ['google pay','google-pay'], ['revolut pay','revolut-pay']
  ]);
  const state = window.__sonarpadCheckoutDiagnosticsV1 ||= {
    ids: new WeakMap(), next: 1, events: [], started: performance.now()
  };
  state.lastPoll = performance.now();
  const id = el => {
    if (!state.ids.has(el)) state.ids.set(el, state.next++);
    return state.ids.get(el);
  };
  const classify = el => {
    const refs = (el.getAttribute('aria-labelledby') || '').split(/\s+/)
      .map(x => document.getElementById(x)).filter(Boolean);
    const sources = [
      ['aria-label', el.getAttribute('aria-label')], ['text',el.textContent],
      ['labelledby', refs.map(x => x.textContent).join(' ')],
      ...[...(el.labels || [])].map(x => ['label', x.textContent])
    ];
    return sources.flatMap(([source,text]) => {
      const match = labels.get(normalize(text));
      return match ? [{source, match}] : [];
    });
  };
  const attr = (el,key,allowed) => {
    const v = el.getAttribute(key);
    return v === null ? null : allowed.includes(v) ? v : 'other';
  };
  const describe = el => {
    const box = el.getBoundingClientRect(), style = getComputedStyle(el);
    return {
      node: id(el), tag: el.tagName.toLowerCase(),
      role: attr(el,'role',['radio','checkbox','switch','button','radiogroup','group','dialog']),
      type: attr(el,'type',['radio','checkbox','button','submit','hidden']),
      checked: typeof el.checked === 'boolean' ? el.checked : null,
      defaultChecked: typeof el.defaultChecked === 'boolean' ? el.defaultChecked : null,
      ariaChecked: attr(el,'aria-checked',['true','false','mixed']),
      ariaPressed: attr(el,'aria-pressed',['true','false','mixed']),
      ariaSelected: attr(el,'aria-selected',['true','false']),
      dataState: attr(el,'data-state',['checked','unchecked','on','off','active','inactive']),
      disabled: !!el.disabled || el.getAttribute('aria-disabled') === 'true',
      connected: el.isConnected,
      rendered: box.width > 0 && box.height > 0 && style.display !== 'none' && style.visibility !== 'hidden',
      hiddenAncestor: !!el.closest('[hidden], [inert], [aria-hidden="true"]'),
      pointerEventsNone: style.pointerEvents === 'none',
      inViewport: box.bottom > 0 && box.top < innerHeight && box.right > 0 && box.left < innerWidth,
      submitRisk: el.tagName === 'BUTTON' && el.type !== 'button',
      labelCount: el.labels ? el.labels.length : 0
    };
  };
  if (!state.listening) {
    state.listening = true;
    for (const type of ['click','change','input']) {
      document.addEventListener(type, event => {
        if (performance.now() - state.lastPoll > 6000) return;
        let target = event.target instanceof Element ? event.target : null;
        for (let depth=0; target && depth<4; depth++,target=target.parentElement) {
          const matches = classify(target);
          if (!matches.length) continue;
          state.events.push({event:type, trusted:event.isTrusted, node:id(target),
            matches, ms:Math.round(performance.now()-state.started)});
          state.events = state.events.slice(-12);
          break;
        }
      },true);
    }
  }
  const controls = [];
  let count = 0;
  for (const el of document.querySelectorAll('button,input[type="radio"],input[type="checkbox"],[role],label,span,div')) {
    const matches = classify(el);
    if (!matches.length) continue;
    count++;
    if (controls.length >= 32) continue;
    const ancestors = [];
    let parent = el.parentElement;
    for (let i=0; parent && i<3; i++,parent=parent.parentElement) ancestors.push(describe(parent));
    controls.push({...describe(el), matches, ancestors,
      nearby: [...(el.parentElement?.querySelectorAll('input[type="radio"],input[type="checkbox"],[role],button') || [])].slice(0,6).map(describe),
      children: [...el.querySelectorAll('input[type="radio"],input[type="checkbox"],[role],button')].slice(0,6).map(describe)});
  }
  const events = state.events.splice(0);
  return JSON.stringify({scope:'checkout',version:1,ready:document.readyState,
    count,truncated:count>32,controls,events,
    frames:document.querySelectorAll('iframe').length,
    modalCount:[...document.querySelectorAll('[aria-modal="true"],dialog[open]')].filter(el=>describe(el).rendered).length});
})()
''';
