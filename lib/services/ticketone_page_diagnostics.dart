/// Read-only structural capture. Never export raw HTML, script bodies, form
/// values, cookies, storage, URL queries/fragments or payment-frame contents.
const ticketOnePageDiagnosticsScript = r'''
(() => {
  if (!['https://www.ticketone.it','https://auth.ticketone.it'].includes(location.origin) || window.top !== window) return JSON.stringify({version:1,status:'foreign'});
  const secrets = new Set();
  const documents = [document];
  const roots = [];
  const collect = (root, depth=0) => {
    if (depth > 5 || roots.includes(root)) return;
    roots.push(root);
    for (const e of root.querySelectorAll('*')) {
      if (['INPUT','TEXTAREA','SELECT'].includes(e.tagName)) {
        if (e.value) secrets.add(String(e.value));
        if (e.getAttribute('value')) secrets.add(e.getAttribute('value'));
      }
      if (e.shadowRoot) collect(e.shadowRoot, depth+1);
      if (e.tagName === 'IFRAME') {
        try {
          const d = e.contentDocument;
          if (d && d.location.origin === location.origin) { documents.push(d); collect(d, depth+1); }
        } catch (_) {}
      }
    }
  };
  collect(document);
  const values = [...secrets].filter(v=>v.length >= 3).sort((a,b)=>b.length-a.length);
  const clean = (v, max=240) => {
    let s = String(v || '');
    for (const value of values) s = s.split(value).join('[value]');
    return s.replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi,'[email]')
      .replace(/\b[a-f0-9]{24,}\b/gi,'[identifier]')
      .replace(/\b[A-Za-z0-9_-]{40,}\b/g,'[identifier]')
      .replace(/\b\d{5,}\b/g,'[number]').replace(/\s+/g,' ').trim().slice(0,max);
  };
  const route = value => {
    try {
      const u = new URL(value,location.href);
      if (!['https:','http:'].includes(u.protocol)) return {scheme:u.protocol};
      // Public event permalink is already logged separately. All other paths
      // are structural only; queries and fragments are never collected.
      return {origin:u.origin,path:clean(u.pathname,320)};
    } catch (_) { return {invalid:true}; }
  };
  const escape = s => s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/"/g,'&quot;');
  let count=0, clipped=false, htmlSize=0;
  const controls=[], frames=[], headings=[], alerts=[];
  const visible = e => {
    const style = e.ownerDocument.defaultView.getComputedStyle(e);
    return style.display !== 'none' && style.visibility !== 'hidden' && !e.closest('[hidden],[aria-hidden="true"]') && e.getClientRects().length>0;
  };
  const text = e => {
    const copy=e.cloneNode(true);
    for (const node of copy.querySelectorAll('script,style,input,textarea')) node.remove();
    return clean(copy.textContent);
  };
  const label = e => clean(e.getAttribute('aria-label') || [...(e.labels||[])].map(text).join(' ') ||
    (e.getAttribute('aria-labelledby')||'').split(' ').map(id=>e.ownerDocument.getElementById(id)).filter(Boolean).map(text).join(' ') || e.getAttribute('placeholder') || (['BUTTON','A','LABEL','LEGEND','H1','H2','H3','SUMMARY'].includes(e.tagName)?text(e):''));
  const walk = (e, path, depth=0) => {
    if (e.nodeType !== 1) return '';
    if (count >= 3500 || htmlSize >= 220000 || depth > 45) { clipped=true; return ''; }
    count++;
    const tag=e.tagName.toLowerCase();
    if (['script','style','noscript','svg','img','link','meta'].includes(tag)) return '';
    const attrs={};
    for (const k of ['id','class','name','type','role','data-qa','aria-label','aria-labelledby','aria-describedby','aria-expanded','aria-checked','aria-disabled','aria-hidden','autocomplete','inputmode','placeholder','required','disabled','hidden','min','max','step']) {
      if (e.hasAttribute(k)) attrs[k]=clean(e.getAttribute(k));
    }
    const caption=label(e), shown=visible(e);
    const control=e.matches('input,select,textarea,button,a[href],[role="button"],[role="combobox"],[role="radio"],[role="checkbox"],summary');
    if (control && controls.length<400) controls.push({path,tag,attributes:attrs,label:caption,visible:shown,
      form:e.form?clean(e.form.id||e.form.className):null,checked:['checkbox','radio'].includes(e.type)?e.checked:undefined,
      options:e.tagName==='SELECT'?{count:e.options.length,labels:[...e.options].slice(0,20).map(o=>clean(o.textContent))}:undefined,
      destination:e.hasAttribute('href')?route(e.getAttribute('href')):undefined});
    if (/^h[1-6]$/.test(tag) && headings.length<40) headings.push({path,text:text(e),visible:shown});
    if (e.matches('[role="alert"],[aria-live],.error,.alert') && alerts.length<40) alerts.push({path,text:text(e),visible:shown});
    let extra='';
    if (tag==='form') attrs['diagnostic-action']=JSON.stringify(route(e.getAttribute('action')||location.href));
    if (tag==='iframe') {
      let d=null; try { if (e.contentDocument?.location.origin===location.origin) d=e.contentDocument; } catch (_) {}
      frames.push({path,title:clean(e.title),source:route(e.getAttribute('src')||''),visible:shown,readable:!!d});
      if (d?.documentElement) extra=walk(d.documentElement,path+'/frame',depth+1);
    }
    if (e.shadowRoot) extra += [...e.shadowRoot.children].map((c,i)=>walk(c,path+'/shadow/'+i,depth+1)).join('');
    const heading=/^h[1-6]$/.test(tag);
    const ticketText=e.matches('.pc-list-category,.ticket-type-title,[data-qa="ticket-type-availability-hint"],[data-qa="tickettypeItem-price"]');
    // No arbitrary body/account/order text. Only UI labels/headings; values
    // from every form (including hidden fields) were redacted above.
    const captionHtml=(control || heading || ticketText || ['label','legend','summary'].includes(tag))?escape(caption|| (heading || ticketText?text(e):'')):'';
    const opening='<'+tag+Object.entries(attrs).map(([k,v])=>' '+k+'="'+escape(v)+'"').join('')+'>';
    htmlSize+=opening.length+captionHtml.length;
    const children=[...e.children].map((c,i)=>walk(c,path+'/'+i,depth+1)).join('');
    return opening+captionHtml+children+extra+'</'+tag+'>';
  };
  const html=walk(document.documentElement,'html');
  return JSON.stringify({version:1,location:route(location.href),title:clean(document.title),ready:document.readyState,
    nodes:count,truncated:clipped,limits:{nodes:3500,htmlCharacters:220000,controls:400},
    controlsTruncated:controls.length===400,headings,alerts,controls,frames,html,
    limitations:['No form values, cookies, storage or script contents','Cross-origin frames are inventoried but unreadable','Closed shadow roots are not readable','Only control labels and headings retained as HTML text']});
})();
''';
