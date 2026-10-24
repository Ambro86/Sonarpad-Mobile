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
    ['revpoints','revpoints'], ['paypal','paypal'], ['carta','card'], ['card','card'],
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
      .map(x => el.ownerDocument.getElementById(x)).filter(Boolean);
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
  // Broad recognition is evidence only, never authorization to hide/click.
  const hints = el => {
    const doc=el.ownerDocument;
    const texts = [
      ['aria-label',el.getAttribute('aria-label')], ['title',el.getAttribute('title')],
      ['alt',el.getAttribute('alt')],
      ['text',el.textContent?.length <= 240 ? el.textContent : ''],
      ...['aria-labelledby','aria-describedby'].map(key=>[key,
        (el.getAttribute(key)||'').split(/\s+/).map(x=>doc.getElementById(x)?.textContent||'').join(' ')])
    ];
    const found=[];
    for (const [source,text] of texts) {
      const normalized=normalize(text);
      for (const [category,pattern] of [
        ['revpoints',/\brev[\s-]*points\b/i], ['revolut',/\brevolut\b/i],
        ['paypal',/\bpay\s*pal\b/i], ['card',/\b(carta|card|visa|mastercard|maestro)\b/i]]) {
        if(pattern.test(normalized)) found.push({source,category});
      }
    }
    return found;
  };
  const attr = (el,key,allowed) => {
    const v = el.getAttribute(key);
    return v === null ? null : allowed.includes(v) ? v : 'other';
  };
  const describe = el => {
    const box = el.getBoundingClientRect(), style = el.ownerDocument.defaultView.getComputedStyle(el);
    return {
      bounds: [box.x,box.y,box.width,box.height].map(Math.round),
      tabIndex: el.tabIndex,
      hints:hints(el),
      hasAriaLabel:el.hasAttribute('aria-label'),
      hasLabelledBy:el.hasAttribute('aria-labelledby'),
      hasDescribedBy:el.hasAttribute('aria-describedby'),
      childCount:el.children.length,
      interactiveDescendants:el.querySelectorAll('input,select,textarea,button,a[href],iframe,[role="button"],[role="radio"]').length,
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
    for (const type of ['click','change','input','focusin','focusout']) {
      document.addEventListener(type, event => {
        if (performance.now() - state.lastPoll > 6000) return;
        const path=event.composedPath();
        const target=path.find(x=>x instanceof Element);
        if(!target) return;
        // Include unknown focus targets too: the old exact-name filter lost them.
        if(type==='focusin' || type==='focusout') {
          state.events.push({event:type,trusted:event.isTrusted,node:id(target),
            matches:classify(target),target:describe(target),
            ancestors:path.filter(x=>x instanceof Element).slice(1,4).map(describe),
            previous:target.previousElementSibling ? describe(target.previousElementSibling) : null,
            next:target.nextElementSibling ? describe(target.nextElementSibling) : null,
            ms:Math.round(performance.now()-state.started)});
        } else {
          const recognized=path.filter(x=>x instanceof Element).slice(0,4)
            .find(x=>classify(x).length || hints(x).length);
          if(recognized) state.events.push({event:type,trusted:event.isTrusted,node:id(recognized),
            matches:classify(recognized),target:describe(recognized),ms:Math.round(performance.now()-state.started)});
        }
        state.events=state.events.slice(-24);
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
  // Describe form structure without exporting values, names, IDs, arbitrary
  // text, validation messages, action URLs or iframe URLs.
  const fieldCategory = el => {
    const text = normalize([
      el.getAttribute('autocomplete'), el.getAttribute('name'), el.id,
      el.getAttribute('aria-label'), el.getAttribute('placeholder'),
      ...[...(el.labels || [])].map(x=>x.textContent)
    ].join(' '));
    if (/cc-csc|cvc|cvv|security.code|codice.di.sicurezza/.test(text)) return 'card-security-code';
    if (/cc-exp|expir|scadenza/.test(text)) return 'card-expiry';
    if (/cc-number|card.number|cardnumber|numero.*carta/.test(text)) return 'card-number';
    if (/cc-name|cardholder|intestatario/.test(text)) return 'cardholder-name';
    if (/password|passwd/.test(text) || el.type === 'password') return 'password';
    if (/email|e-mail/.test(text) || el.type === 'email') return 'email';
    if (/phone|tel|telefono/.test(text) || el.type === 'tel') return 'phone';
    if (/postal|postcode|zip|\bcap\b/.test(text)) return 'postal-code';
    if (/address|indirizzo/.test(text)) return 'address';
    if (/first.name|last.name|given-name|family-name|cognome|\bnome\b/.test(text)) return 'name';
    if (/country|paese/.test(text)) return 'country';
    if (/city|citta|città/.test(text)) return 'city';
    return 'other';
  };
  const layout = el => {
    const win = el.ownerDocument.defaultView;
    const style = win.getComputedStyle(el), r = el.getBoundingClientRect();
    return {node:id(el), rendered:r.width>0 && r.height>0 && style.display!=='none' && style.visibility!=='hidden',
      hiddenAncestor:!!el.closest('[hidden],[inert],[aria-hidden="true"]'),
      bounds:[r.x,r.y,r.width,r.height].map(Math.round),
      inViewport:r.bottom>0 && r.top<win.innerHeight && r.right>0 && r.left<win.innerWidth};
  };
  const provider = frame => {
    try {
      const host = new URL(frame.getAttribute('src') || '', location.href).hostname;
      for (const domain of ['paypal.com','paypalobjects.com','braintreegateway.com','braintree-api.com','adyen.com','stripe.com','revolut.com','google.com','apple.com','omio.com']) {
        if (host===domain || host.endsWith('.'+domain)) return domain;
      }
    } catch (_) {}
    return 'other';
  };
  const documents = [], frameDetails = [], readableDocuments = [];
  const inspectDocument = (doc, owner, depth) => {
    readableDocuments.push({doc,owner});
    const fields = [...doc.querySelectorAll('input:not([type="hidden"]),select,textarea')];
    documents.push({owner,forms:doc.forms.length,fieldCount:fields.length,truncated:fields.length>60,
      fields:fields.slice(0,60).map(el=>({...layout(el),tag:el.tagName.toLowerCase(),
        category:fieldCategory(el),type:attr(el,'type',['text','email','tel','password','number','radio','checkbox','date','month','submit','button']),
        form:el.form ? id(el.form) : null,required:!!el.required,disabled:!!el.disabled,readOnly:!!el.readOnly,
        ariaInvalid:attr(el,'aria-invalid',['true','false','grammar','spelling']),
        checked:['radio','checkbox'].includes(el.type) ? el.checked : null})),
      // Error presence only: error text can echo private input.
      alertCount:doc.querySelectorAll('[role="alert"],[aria-live="assertive"]').length});
    for (const frame of [...doc.querySelectorAll('iframe')].slice(0,20)) {
      if (frameDetails.length >= 30) break;
      const detail = {...layout(frame),owner,provider:provider(frame),hints:hints(frame),tabIndex:frame.tabIndex,access:'unavailable'};
      frameDetails.push(detail);
      try {
        const child = frame.contentDocument;
        if (!child) { detail.access='cross-origin-or-not-loaded'; continue; }
        if (depth>=2) { detail.access='depth-limit'; continue; }
        detail.access='readable';
        inspectDocument(child,id(frame),depth+1);
      } catch (_) { detail.access='cross-origin'; }
    }
  };
  inspectDocument(document,'main',0);
  // DOM accessibility inventory, not a claim to reproduce the native AX tree.
  // No names, text, URLs, raw IDs, values or hashes of personal text leave JS.
  const inventory=[], inventoryLimit=600, scanLimit=6000;
  let scanned=0, inventoryTruncated=false, shadowRoots=0;
  const safeTags=new Set('a button input select textarea label img svg span div p h1 h2 h3 h4 h5 h6 ul ol li table tr td th form section article main nav header footer aside iframe summary details dialog slot'.split(' '));
  const roles=['button','link','radio','checkbox','switch','radiogroup','group','dialog','heading','img','presentation','none','alert','status','textbox','combobox','listbox','option','tab','tabpanel','menu','menuitem','region','navigation','main'];
  const links=(el,key) => (el.getAttribute(key)||'').split(/\s+/).filter(Boolean)
    .slice(0,12).map(ref=>el.getRootNode().getElementById?.(ref) || el.ownerDocument.getElementById(ref))
    .filter(Boolean).map(id);
  const walk = (root,owner,shadowHost=null,depth=0) => {
    const walker=root.ownerDocument ? root.ownerDocument.createTreeWalker(root,1) : root.createTreeWalker(root,1);
    let el;
    while((el=walker.nextNode())) {
      if(++scanned>scanLimit || inventory.length>=inventoryLimit) { inventoryTruncated=true;return; }
      const tag=el.tagName.toLowerCase();
      if(['script','style','noscript','meta','link'].includes(tag)) continue;
      const directText=[...el.childNodes].some(n=>n.nodeType===3 && n.textContent.trim());
      const candidate=el.matches('a,button,input,select,textarea,label,img,svg,iframe,summary,details,[role],[tabindex],[aria-label],[aria-labelledby],[aria-live],h1,h2,h3,h4,h5,h6') || directText;
      if(candidate) {
        const win=el.ownerDocument.defaultView,r=el.getBoundingClientRect(),style=win.getComputedStyle(el);
        inventory.push({node:id(el),owner,order:inventory.length,shadowHost,
          tag:safeTags.has(tag)?tag:'custom',role:attr(el,'role',roles),
          parent:el.parentElement?id(el.parentElement):shadowHost,
          previous:el.previousElementSibling?id(el.previousElementSibling):null,
          next:el.nextElementSibling?id(el.nextElementSibling):null,
          labels:[...(el.labels||[])].slice(0,12).map(id),
          labelledBy:links(el,'aria-labelledby'),describedBy:links(el,'aria-describedby'),
          controls:links(el,'aria-controls'),owns:links(el,'aria-owns'),
          hints:hints(el),directText,hasAlt:el.hasAttribute('alt'),hasTitle:el.hasAttribute('title'),
          hasAriaLabel:el.hasAttribute('aria-label'),tabIndex:el.tabIndex,
          checked:typeof el.checked==='boolean'?el.checked:null,
          ariaChecked:attr(el,'aria-checked',['true','false','mixed']),
          ariaPressed:attr(el,'aria-pressed',['true','false','mixed']),
          expanded:attr(el,'aria-expanded',['true','false']),
          live:attr(el,'aria-live',['off','polite','assertive']),
          disabled:!!el.disabled || el.getAttribute('aria-disabled')==='true',
          required:!!el.required,readOnly:!!el.readOnly,
          hidden:!!el.closest('[hidden],[inert],[aria-hidden="true"]'),
          rendered:r.width>0 && r.height>0 && style.display!=='none' && style.visibility!=='hidden',
          position:['static','relative','absolute','fixed','sticky'].includes(style.position)?style.position:'other',
          overflowX:['visible','hidden','clip','scroll','auto'].includes(style.overflowX)?style.overflowX:'other',
          overflowY:['visible','hidden','clip','scroll','auto'].includes(style.overflowY)?style.overflowY:'other',
          scrollableX:el.scrollWidth>el.clientWidth,scrollableY:el.scrollHeight>el.clientHeight,
          bounds:[r.x+win.scrollX,r.y+win.scrollY,r.width,r.height].map(Math.round),
          fieldCategory:el.matches('input,select,textarea')?fieldCategory(el):null});
      }
      if(el.shadowRoot) {
        shadowRoots++;
        if(depth<3) walk(el.shadowRoot,owner,id(el),depth+1);
        else inventoryTruncated=true;
      }
    }
  };
  for(const {doc,owner} of readableDocuments) walk(doc.body||doc,owner);
  const previousInventory=state.inventory || new Map();
  const currentInventory=new Map(inventory.map(x=>[x.node,JSON.stringify(x)]));
  const inventoryChanges=inventory.filter(x=>previousInventory.get(x.node)!==currentInventory.get(x.node));
  // A truncated scan cannot prove that an unseen node was removed.
  const inventoryRemoved=inventoryTruncated?[]:[...previousInventory.keys()].filter(x=>!currentInventory.has(x));
  state.inventory=inventoryTruncated?new Map([...previousInventory,...currentInventory]):currentInventory;
  const inventorySummary={scanned,recorded:inventory.length,limit:inventoryLimit,scanLimit,
    truncated:inventoryTruncated,shadowRoots,closedShadowRoots:'not-inspectable',
    changed:inventoryChanges.length,removed:inventoryRemoved,
    kind:'dom-inventory-not-native-voiceover-order'};
  const landmarks = [...document.querySelectorAll('button,a,[role],iframe')]
    .filter(el => hints(el).some(x=>['revpoints','revolut','paypal'].includes(x.category)) ||
      (el.tagName==='IFRAME' && ['revolut.com','paypal.com'].includes(provider(el))))
    .slice(0,20).map(el=>({...describe(el),matches:classify(el),
      previous:el.previousElementSibling ? describe(el.previousElementSibling) : null,
      next:el.nextElementSibling ? describe(el.nextElementSibling) : null,
      parent:el.parentElement ? describe(el.parentElement) : null}));
  const viewport = {scrollX:Math.round(scrollX),scrollY:Math.round(scrollY),
    width:innerWidth,height:innerHeight,documentHeight:document.documentElement.scrollHeight};
  let focused=document.activeElement;
  for(let depth=0;focused?.shadowRoot?.activeElement && depth<3;depth++) focused=focused.shadowRoot.activeElement;
  const active = focused ? {...describe(focused),
    previous:focused.previousElementSibling ? describe(focused.previousElementSibling) : null,
    next:focused.nextElementSibling ? describe(focused.nextElementSibling) : null,
    parent:focused.parentElement ? describe(focused.parentElement) : null,
    children:[...focused.children].slice(0,6).map(describe)} : null;
  const events = state.events.splice(0);
  return JSON.stringify({scope:'checkout',version:4,ready:document.readyState,
    documents,frameDetails,landmarks,viewport,active,inventorySummary,inventoryChanges,
    count,truncated:count>32,controls,events,
    frames:document.querySelectorAll('iframe').length,
    modalCount:[...document.querySelectorAll('[aria-modal="true"],dialog[open]')].filter(el=>describe(el).rendered).length});
})()
''';
