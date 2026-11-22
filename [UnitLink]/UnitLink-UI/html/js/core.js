/* UnitLink-UI core: helpers, icons, Lua <-> NUI messaging */
(() => {
  'use strict';

  const IS_NUI = typeof GetParentResourceName === 'function';
  const RESOURCE = IS_NUI ? GetParentResourceName() : 'UnitLink-UI';
  const handlers = {};
  const escStack = [];
  const initHooks = [];

  const ICONS = {
    check: '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
    x: '<path d="M7 7l10 10M17 7L7 17"/>',
    warning: '<path d="M12 4l9 16H3z"/><path d="M12 10v4M12 17.2v.1"/>',
    info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 7.8v.1"/>',
    announce: '<path d="M4 10v4h3l6 4V6L7 10z"/><path d="M16.5 9a4 4 0 010 6M19 6.5a7.5 7.5 0 010 11"/>',
    sms: '<path d="M4 6.5A2.5 2.5 0 016.5 4h11A2.5 2.5 0 0120 6.5v8a2.5 2.5 0 01-2.5 2.5H10l-4.5 3.5V17A1.5 1.5 0 014 15.5z"/>',
    badge: '<path d="M12 3l7 3v5c0 4.5-3 8.3-7 10-4-1.7-7-5.5-7-10V6z"/><path d="M12 8.5l1.1 2.2 2.4.3-1.8 1.6.5 2.4-2.2-1.2-2.2 1.2.5-2.4-1.8-1.6 2.4-.3z"/>',
    fire: '<path d="M12 3c.8 3.2 5 5.4 5 10.2A5 5 0 017 13.2c0-2.3 1-3.8 2.3-5 .2 1.7 1 2.8 2 3.2.4-3-.3-5.7.7-8.4z"/>',
    medical: '<path d="M10 4h4v6h6v4h-6v6h-4v-6H4v-4h6z"/>',
    bell: '<path d="M6 16v-5a6 6 0 0112 0v5l1.5 2h-15z"/><path d="M10 20a2 2 0 004 0"/>',
    pin: '<path d="M12 21s-6-5.6-6-11a6 6 0 0112 0c0 5.4-6 11-6 11z"/><circle cx="12" cy="10" r="2"/>',
    wrench: '<path d="M14.5 6.5a4 4 0 00-5.2 5.2L4 17l3 3 5.3-5.3a4 4 0 005.2-5.2l-2.5 2.5-2.5-.5-.5-2.5z"/>',
    box: '<path d="M4 8l8-4 8 4v8l-8 4-8-4z"/><path d="M4 8l8 4 8-4M12 12v8"/>',
    edit: '<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="M13.5 6.5l4 4"/>',
    tag: '<path d="M3 12V4h8l9 9-8 8z"/><circle cx="7.5" cy="8.5" r="1.2"/>',
    lock: '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 018 0v3"/>',
    unlock: '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 017.5-2"/>',
    eye: '<path d="M2 12s3.6-6.5 10-6.5S22 12 22 12s-3.6 6.5-10 6.5S2 12 2 12z"/><circle cx="12" cy="12" r="2.8"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    minus: '<path d="M5 12h14"/>',
    card: '<rect x="3" y="5.5" width="18" height="13" rx="2.5"/><path d="M3 10h18M7 15h3"/>',
    down: '<path d="M6 9l6 6 6-6"/>',
    up: '<path d="M6 15l6-6 6 6"/>',
    left: '<path d="M15 6l-6 6 6 6"/>',
    right: '<path d="M9 6l6 6-6 6"/>',
    calendar: '<rect x="4" y="5" width="16" height="15" rx="2.5"/><path d="M4 10h16M9 3v4M15 3v4"/>',
    garage: '<path d="M3 20V9l9-5 9 5v11"/><path d="M7 20v-7h10v7M7 16h10"/>',
    car: '<path d="M5 16h14v-4l-2-5H7l-2 5z"/><path d="M5 16v3M19 16v3"/><circle cx="8" cy="13.5" r=".8"/><circle cx="16" cy="13.5" r=".8"/>',
    fuel: '<path d="M5 20V5a1.5 1.5 0 011.5-1.5h6A1.5 1.5 0 0114 5v15M3.5 20h12M14 9h2a2 2 0 012 2v5a1.5 1.5 0 003 0V8l-3-3"/><path d="M7 7.5h5"/>',
    key: '<circle cx="8" cy="15" r="4"/><path d="M11 12l8-8M16 7l2 2"/>',
    ban: '<circle cx="12" cy="12" r="9"/><path d="M6 6l12 12"/>',
    spray: '<rect x="7" y="9" width="8" height="12" rx="2"/><path d="M9 9V6h4v3M16 5h.1M19 4h.1M19 7h.1M16 2h.1"/>',
    wheel: '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="3"/><path d="M12 3v6M12 15v6M3 12h6M15 12h6"/>',
    bolt: '<path d="M13 3L5 14h6l-1 7 8-11h-6z"/>',
    sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M5 5l1.5 1.5M17.5 17.5L19 19M5 19l1.5-1.5M17.5 6.5L19 5"/>',
    turbo: '<circle cx="12" cy="12" r="8"/><path d="M12 12l4-4M12 4v2M20 12h-2"/>',
    smile: '<circle cx="12" cy="12" r="9"/><path d="M8.5 14.5a4.5 4.5 0 007 0M9 9.5h.1M15 9.5h.1"/>',
    shirt: '<path d="M8 4l-5 3 2 4 2-1v10h10V10l2 1 2-4-5-3a4 4 0 01-8 0z"/>',
    phone: '<rect x="7" y="3" width="10" height="18" rx="2.5"/><path d="M11 17.5h2"/>',
    walk: '<circle cx="13" cy="4.5" r="1.8"/><path d="M10 21l2-6 3 3v3M9 12l2-4.5 3 1 2 3.5M11 7.5L8 9l-1 3"/>',
    dots: '<circle cx="6" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="18" cy="12" r="1"/>',
    door: '<path d="M6 21V4a1 1 0 011-1h10a1 1 0 011 1v17M3 21h18"/><circle cx="14.5" cy="12" r=".8"/>',
    engine: '<path d="M4 10h3l2-2h5l2 2h2v3h2v-2M4 10v7h3l2 2h7l2-2v-4M4 13H2"/>',
    window: '<rect x="4" y="4" width="16" height="16" rx="2"/><path d="M4 12h16M12 4v16"/>',
    light: '<path d="M9 18h6M10 21h4M12 3a6 6 0 00-3.5 10.9V16h7v-2.1A6 6 0 0012 3z"/>',
    target: '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1"/>',
    signal: '<path d="M5 18v-3M10 18v-6M15 18V9M20 18V5"/>',
    grid: '<rect x="4" y="4" width="6" height="6" rx="1.5"/><rect x="14" y="4" width="6" height="6" rx="1.5"/><rect x="4" y="14" width="6" height="6" rx="1.5"/><rect x="14" y="14" width="6" height="6" rx="1.5"/>',
    drop: '<path d="M12 3s6 6.5 6 11a6 6 0 01-12 0c0-4.5 6-11 6-11z"/>',
    user: '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0116 0"/>',
    users: '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0113 0M16 4.5a3.5 3.5 0 010 7M18 14a6 6 0 013.5 6"/>',
    home: '<path d="M4 11l8-7 8 7v9H4z"/><path d="M10 20v-6h4v6"/>',
    map: '<path d="M9 4L3 6v14l6-2 6 2 6-2V4l-6 2z"/><path d="M9 4v14M15 6v14"/>',
    gear: '<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M2 12h3M19 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1"/>',
    trash: '<path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/>',
    search: '<circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/>',
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    star: '<path d="M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1L3.2 9.5l6.1-.9z"/>',
    heart: '<path d="M12 20s-7-4.4-7-10a4 4 0 017-2.6A4 4 0 0119 10c0 5.6-7 10-7 10z"/>',
    hand: '<path d="M8 13V5.5a1.5 1.5 0 013 0V11M11 10V4.5a1.5 1.5 0 013 0V11M14 10V6a1.5 1.5 0 013 0v7a7 7 0 01-7 7 6 6 0 01-5-3l-2-4a1.5 1.5 0 012.5-1.6L8 13"/>',
    paw: '<circle cx="7" cy="9" r="1.8"/><circle cx="12" cy="6.5" r="1.8"/><circle cx="17" cy="9" r="1.8"/><path d="M8 17c0-3 2-5 4-5s4 2 4 5a2 2 0 01-2 2h-4a2 2 0 01-2-2z"/>',
    tree: '<path d="M12 3l6 8h-3l4 6H5l4-6H6z"/><path d="M12 17v4"/>',
    fish: '<path d="M3 12s3.5-5 9-5 9 5 9 5-3.5 5-9 5-9-5-9-5z"/><path d="M21 12l-2-2v4z"/><circle cx="8" cy="11" r=".8"/>',
  };

  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  // escaped text + **bold** + line breaks
  const fmt = s => esc(s).replace(/\*\*(.+?)\*\*/g, '<b>$1</b>').replace(/\n/g, '<br>');

  function rgb(color, fallback = '255,255,255') {
    if (typeof color !== 'string') return fallback;
    const m = color.trim().match(/^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/i);
    if (m) return `${m[1]},${m[2]},${m[3]}`;
    let h = color.trim().replace('#', '');
    if (h.length === 3) h = h.split('').map(c => c + c).join('');
    if (!/^[0-9a-f]{6}$/i.test(h)) return fallback;
    const n = parseInt(h, 16);
    return `${(n >> 16) & 255},${(n >> 8) & 255},${n & 255}`;
  }

  function svg(name, fallback, style) {
    const p = ICONS[name] || ICONS[fallback];
    if (!p) return '';
    return `<svg class="i" viewBox="0 0 24 24"${style ? ` style="${style}"` : ''}>${p}</svg>`;
  }

  // --rgb value for an optional custom color, else a named token
  const tone = (color, token = 'accent') => (color ? rgb(color) : `var(--${token})`);

  function post(name, data) {
    if (!IS_NUI) { if (UI.mock) UI.mock(name, data || {}); return Promise.resolve(); }
    return fetch(`https://${RESOURCE}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).catch(() => {});
  }

  // single-instance containers: animate in / out
  function show(el, html) {
    clearTimeout(el._hideTimer);
    el.classList.remove('out', 'show');
    if (html !== undefined) el.innerHTML = html;
    void el.offsetWidth;
    el.classList.add('show');
  }
  function hide(el) {
    if (!el.classList.contains('show') || el.classList.contains('out')) return;
    el.classList.add('out');
    el._hideTimer = setTimeout(() => { el.classList.remove('show', 'out'); el.innerHTML = ''; }, 180);
  }
  const isShown = el => el.classList.contains('show') && !el.classList.contains('out');

  // Escape goes to whatever opened last
  function onEsc(owner, fn) { offEsc(owner); escStack.push({ owner, fn }); }
  function offEsc(owner) { const i = escStack.findIndex(e => e.owner === owner); if (i >= 0) escStack.splice(i, 1); }
  document.addEventListener('keydown', e => {
    if (e.key === 'Escape' && escStack.length) { e.preventDefault(); escStack[escStack.length - 1].fn(); }
  });

  const UI = window.UI = {
    IS_NUI, ICONS, cfg: {},
    $, $$, esc, fmt, rgb, svg, tone, post, show, hide, isShown, onEsc, offEsc,
    on: (action, fn) => { handlers[action] = fn; },
    onInit: fn => initHooks.push(fn),
    // used by the browser preview to fake Lua
    emit: (action, data) => { const h = handlers[action]; if (h) h(data || {}); },
  };

  window.addEventListener('message', e => {
    const m = e.data || {};
    const h = handlers[m.action];
    if (!h) return;
    try { h(m.data || {}); } catch (err) { console.error('[UnitLink-UI]', m.action, err); }
  });

  UI.on('init', c => {
    UI.cfg = c || {};
    document.documentElement.style.setProperty('--accent', rgb(UI.cfg.accent, '45,212,191'));
    document.documentElement.style.setProperty('--scale', UI.cfg.scale || 1);
    initHooks.forEach(fn => fn(UI.cfg));
  });
  UI.on('visible', d => $('#ui').classList.toggle('hidden', !d.visible));

  if (IS_NUI) {
    // tell Lua we're loaded (retry until the client script has registered its callback)
    const ready = () => fetch(`https://${RESOURCE}/ready`, {
      method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: '{}',
    }).then(r => { if (!r.ok) throw new Error(); }).catch(() => setTimeout(ready, 1000));
    window.addEventListener('load', ready);
  }
})();
