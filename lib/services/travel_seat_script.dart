import 'dart:convert';

/// Mirrors only Omio's seat dialog. Payment controls are never actionable here.
/// Handles refer to the actual DOM node: a replaced node requires a fresh read.
String travelSeatScript({
  String? action,
  bool italian = false,
  Map<String, String>? labels,
}) =>
    '''
(() => {
  const action = ${jsonEncode(action)};
  const italian = $italian;
  const labels = ${jsonEncode(labels)};
  const result = value => JSON.stringify(value);
  if (location.protocol !== 'https:' ||
      !['omio.com','www.omio.com'].includes(location.hostname) ||
      (location.port && location.port !== '443')) return result({status:'outside'});
  const visible = e => !!e && e.isConnected && e.getClientRects().length > 0 &&
    getComputedStyle(e).visibility !== 'hidden' && !e.closest('[aria-hidden="true"]');
  const enabled = e => visible(e) && !e.disabled && e.getAttribute('aria-disabled') !== 'true';
  const clean = s => (s || '').replace(/\\s+/g,' ').trim();
  const text = e => clean(e.innerText || e.textContent);
  const launcher = [...document.querySelectorAll('[data-e2e="seatMapLauncherBtn"]')].find(visible);
  const dialog = [...document.querySelectorAll('[role="dialog"]')].find(e => visible(e) &&
    e.querySelector('[data-e2e="segmentSelector"], [data-e2e="seatmapWrapper"], [data-e2e="segmentSelector-modal-cta"], [data-e2e="seatmaps-modal-cta"]'));
  const selector = 'button, [role="button"][data-e2e\$="-seats-option"]';
  const candidates = dialog ? [...dialog.querySelectorAll(selector)].filter(visible) : [];
  const state = window.__sonarpadSeats || (window.__sonarpadSeats = {next:0,nodes:new Map(),ids:new WeakMap(),labels:new Map()});
  const idFor = e => {
    if (!state.ids.has(e)) state.ids.set(e, 'seat-' + (++state.next));
    const id = state.ids.get(e); state.nodes.set(id,e); state.labels.set(id,text(e)); return id;
  };
  if (action) {
    const node = action === 'open' ? launcher : state.nodes.get(action);
    if (!enabled(node) || (action !== 'open' && (!candidates.includes(node) || state.labels.get(action) !== text(node))))
      return result({status:'stale'});
    node.click();
    return result({status:'clicked'}); // Not a claim that the reservation was saved.
  }
  for (const [id,node] of state.nodes) if (!node.isConnected) state.nodes.delete(id);
  if (!dialog) return result({status:'closed',available:enabled(launcher)});
  const controls = candidates.map(e => {
    const kind = e.getAttribute('data-e2e');
    let label = e.getAttribute('data-seat-place') || e.getAttribute('aria-label') || text(e);
    if (e.hasAttribute('data-seat-place') && italian)
      label = label.replace(/^Coach (.*?) Seat (.*)\$/, 'Carrozza \$1, posto \$2');
    if (labels && e.hasAttribute('data-seat-place')) {
      const match = /^Coach (.*?) Seat (.*)\$/.exec(e.getAttribute('data-seat-place'));
      if (match) label = labels.position.replace('{coach}', match[1]).replace('{seat}', match[2]);
    }
    if (kind === 'modal-close-button') label = labels?.close || (italian ? 'Chiudi scelta posti' : 'Close seat selection');
    if (kind === 'seatmaps-header-back-btn') label = labels?.back || (italian ? 'Indietro' : 'Back');
    const radio = e.querySelector('input[type="radio"]');
    const selected = e.getAttribute('aria-selected') === 'true' || e.getAttribute('aria-pressed') === 'true' || !!radio?.checked;
    return {id:idFor(e),label,enabled:enabled(e),selected};
  }).filter(c => c.label);
  // Keep route, passenger, category, prices and validation messages; omit the
  // graphical map and controls, which are represented separately above.
  const copy = dialog.cloneNode(true);
  copy.querySelectorAll('[data-e2e="seatmapWrapper"],button,[role="button"],svg,style,script').forEach(e=>e.remove());
  copy.querySelectorAll('div,p,section,h1,h2,h3,h4,h5,h6').forEach(e=>e.appendChild(document.createTextNode(' ')));
  return result({status:'dialog',stage:dialog.querySelector('[data-e2e="seatmapWrapper"]')?'map':'segments',available:true,summary:clean(copy.textContent),controls});
})()
''';
