/// Only selects an explicit necessary-only/reject-optional consent action on Omio.
/// Never removes overlays, accepts all, or interacts with booking/payment controls.
const travelNecessaryCookiesScript = r'''
(() => {
  if (location.protocol !== 'https:' ||
      !['omio.com', 'www.omio.com'].includes(location.hostname)) return 'wrong-origin';
  const inspectOnly = false;
  const normalize = s => (s || '').toLowerCase().replace(/\s+/g, ' ').trim();
  const labels = new Set([
    'solo cookie necessari', 'accetta solo i cookie necessari', 'accetta solo necessari',
    'solo necessari', 'solo essenziali', 'rifiuta tutti', 'rifiuta tutto',
    'rifiuta i cookie facoltativi', 'rifiuta cookie facoltativi',
    'necessary cookies only', 'accept necessary cookies only', 'only necessary cookies',
    'only necessary', 'essential cookies only', 'accept essential cookies only',
    'reject all', 'reject optional cookies', 'reject non-essential cookies',
    'nur notwendige cookies', 'nur erforderliche cookies', 'alle ablehnen',
    'uniquement les cookies nécessaires', 'tout refuser',
    'solo cookies necesarias', 'rechazar todas', 'rechazar todo',
    'apenas cookies necessários', 'rejeitar todos',
    'tylko niezbędne pliki cookie', 'odrzuć wszystkie',
    'pouze nezbytné soubory cookie', 'odmítnout vše',
    'doar cookie-urile necesare', 'respinge toate',
    'yalnızca gerekli çerezler', 'tümünü reddet',
    'лише необхідні файли cookie', 'відхилити всі',
    '仅必要的 cookie', '仅必要cookie', '全部拒绝'
  ]);
  const visible = el => {
    const style = getComputedStyle(el), box = el.getBoundingClientRect();
    return style.display !== 'none' && style.visibility !== 'hidden' &&
      box.width > 0 && box.height > 0 && !el.disabled &&
      el.getAttribute('aria-disabled') !== 'true' && !el.closest('[inert], [aria-hidden="true"]');
  };
  const roots = document.querySelectorAll(
    '#onetrust-banner-sdk, #onetrust-pc-sdk, #CybotCookiebotDialog, ' +
    '[role="dialog"], [aria-modal="true"], [data-testid*="cookie" i], ' +
    '[id*="cookie-banner" i], [class*="cookie-banner" i], [class*="CookieBanner"], ' +
    '[id*="consent-banner" i]'
  );
  const previous = window.__sonarpadTravelCookieBanner;
  if (inspectOnly && !previous) return 'verification-unavailable';
  if (inspectOnly && previous.isConnected && visible(previous)) return 'banner-visible';
  let bannerFound = false;
  for (const root of roots) {
    if (!visible(root)) continue;
    const text = normalize(root.innerText || root.textContent);
    const known = ['onetrust-banner-sdk', 'onetrust-pc-sdk', 'CybotCookiebotDialog'].includes(root.id);
    if (!known && !/cookie|cookies|çerez|кукі|куки|饼干/.test(text)) continue;
    bannerFound = true;
    if (inspectOnly) return 'banner-visible';
    for (const button of root.querySelectorAll('button, [role="button"], input[type="button"]')) {
      if (!visible(button)) continue;
      const label = normalize(button.innerText || button.textContent || button.value || button.getAttribute('aria-label'));
      if (!labels.has(label)) continue;
      window.__sonarpadTravelCookieBanner = root;
      button.click();
      return 'selected-necessary';
    }
  }
  if (inspectOnly) return 'banner-closed';
  return bannerFound ? 'action-not-found' : 'banner-not-found';
})()
''';

final travelCookieBannerStatusScript = travelNecessaryCookiesScript
    .replaceFirst('const inspectOnly = false;', 'const inspectOnly = true;');
