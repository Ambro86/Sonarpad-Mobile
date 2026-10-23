import 'dart:convert';

String travelNoProtectionScript({bool verifyOnly = false}) =>
    _noProtection.replaceFirst('__VERIFY__', '$verifyOnly');

const _noProtection = r'''
(() => {
  if (location.protocol !== 'https:' || (location.port && location.port !== '443') ||
      !['omio.com', 'www.omio.com'].includes(location.hostname) ||
      !/\/checkout\/?$/.test(location.pathname)) return 'unavailable';
  const visible = el => {
    const r = el.getBoundingClientRect(), s = getComputedStyle(el);
    return r.width > 0 && r.height > 0 && s.visibility !== 'hidden' &&
      s.display !== 'none' && !el.closest('[inert], [aria-hidden="true"]');
  };
  if ([...document.querySelectorAll('[aria-modal="true"], dialog[open]')].some(visible)) return 'blocked';
  const names = new Set(['voglio viaggiare senza protezione',
    'i want to travel without protection', 'travel without protection']);
  const normalize = text => (text || '').toLowerCase().replace(/\s+/g, ' ').trim();
  const matches = [];
  for (const el of document.querySelectorAll('input[type="radio"], input[type="checkbox"], [role="radio"], [role="checkbox"], [role="switch"]')) {
    if (el.disabled || el.getAttribute('aria-disabled') === 'true' ||
        (el.tagName === 'BUTTON' && el.type !== 'button')) continue;
    const labels = [...(el.labels || [])];
    if (!visible(el) && !labels.some(visible)) continue;
    const refs = (el.getAttribute('aria-labelledby') || '').split(/\s+/)
      .map(id => document.getElementById(id)).filter(Boolean);
    const texts = [el.getAttribute('aria-label'), el.textContent,
      refs.map(x => x.textContent).join(' '), ...labels.map(x => x.textContent)];
    if (texts.some(t => names.has(normalize(t)))) matches.push(el);
  }
  if (matches.length !== 1) return 'unavailable';
  const el = matches[0];
  const checked = () => el.checked === true || el.getAttribute('aria-checked') === 'true';
  if (!__VERIFY__ && !checked()) el.click();
  return checked() ? 'selected' : 'unconfirmed';
})()
''';

/// Only radio selection is allowed. Never clicks buttons, submits forms or
/// accesses provider frames. Labels are re-read on every invocation.
String travelPaymentScript({String? select}) =>
    _script.replaceFirst('__SELECTION__', jsonEncode(select));

const _script = r'''
(() => {
  const requested = __SELECTION__;
  const result = (status, methods = []) => JSON.stringify({status, methods});
  if (location.protocol !== 'https:' || location.port && location.port !== '443' ||
      !['omio.com', 'www.omio.com'].includes(location.hostname) ||
      !/\/checkout\/?$/.test(location.pathname)) return result('unavailable');
  const normalize = s => (s || '').toLowerCase().replace(/\s+/g, ' ').trim();
  const names = new Map([
    ['paypal', 'PayPal'], ['apple pay', 'Apple Pay'],
    ['google pay', 'Google Pay'], ['revolut pay', 'Revolut Pay'],
    ['carta', 'card'], ['card', 'card'], ['credit card', 'card'],
    ['carta di credito', 'card'], ['carte bancaire', 'card'],
    ['kreditkarte', 'card'], ['tarjeta', 'card']
  ]);
  const visible = el => {
    const r = el.getBoundingClientRect(), s = getComputedStyle(el);
    return r.width > 0 && r.height > 0 && s.visibility !== 'hidden' &&
      s.display !== 'none' && !el.closest('[inert], [aria-hidden="true"]');
  };
  // An open consent or other modal must be handled before selecting anything.
  if ([...document.querySelectorAll('[aria-modal="true"], dialog[open]')]
      .some(visible)) return result('blocked');
  const found = new Map();
  for (const el of document.querySelectorAll('input[type="radio"], [role="radio"]')) {
    if (el.disabled || el.getAttribute('aria-disabled') === 'true') continue;
    if (el.tagName === 'BUTTON' && el.type !== 'button') continue;
    const labels = [...(el.labels || [])];
    const refs = (el.getAttribute('aria-labelledby') || '').split(/\s+/)
      .map(id => document.getElementById(id)).filter(Boolean);
    if (!visible(el) && !labels.some(visible)) continue;
    const candidates = [el.getAttribute('aria-label'),
      refs.map(x => x.textContent).join(' '), ...labels.map(x => x.textContent),
      el.textContent].map(normalize).filter(Boolean);
    const ids = [...new Set(candidates.map(x => names.get(x)).filter(Boolean))];
    if (ids.length !== 1) continue;
    const id = ids[0];
    if (!found.has(id)) found.set(id, []);
    found.get(id).push(el);
  }
  const methods = [...found].filter(([, els]) => els.length === 1).map(([id]) => id);
  if (requested === null) return result('ready', methods);
  if (!methods.includes(requested)) return result('unavailable', methods);
  const el = found.get(requested)[0];
  if (!(el.checked || el.getAttribute('aria-checked') === 'true')) el.click();
  return result(el.checked || el.getAttribute('aria-checked') === 'true'
    ? 'selected' : 'unconfirmed', methods);
})()
''';
