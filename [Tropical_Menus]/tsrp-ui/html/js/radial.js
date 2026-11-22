/* Radial menu */
(() => {
  'use strict';
  const { $, $$, esc, ICONS } = UI;
  const root = $('#radial');
  const PER_PAGE = 6;
  let menu = null, page = 0;

  function pageItems() {
    const items = menu.items || [];
    if (items.length <= PER_PAGE) return items.map((it, i) => ({ ...it, index: i + 1 }));
    const per = PER_PAGE - 1, pages = Math.ceil(items.length / per);
    page = page % pages;
    const slice = items.slice(page * per, page * per + per).map((it, i) => ({ ...it, index: page * per + i + 1 }));
    slice.push({ label: 'More', description: `Page ${(page + 1) % pages + 1} of ${pages}`, icon: 'dots', more: true });
    return slice;
  }

  function render(animate) {
    const items = pageItems(), n = Math.max(items.length, 1), R1 = 62, R2 = 160, gap = n > 1 ? 1.6 : 0;
    const pt = (r, a) => [r * Math.sin(a * Math.PI / 180), -r * Math.cos(a * Math.PI / 180)];
    let html = '';
    items.forEach((it, i) => {
      const a0 = i * 360 / n - 180 / n + gap, a1 = (i + 1) * 360 / n - 180 / n - gap, mid = (a0 + a1) / 2;
      const large = a1 - a0 > 180 ? 1 : 0;
      const [x0, y0] = pt(R2, a0), [x1, y1] = pt(R2, a1), [x2, y2] = pt(R1, a1), [x3, y3] = pt(R1, a0);
      const [ix, iy] = pt(108, mid);
      let extra = '';
      if (it.badge) {
        const b = String(it.badge).slice(0, 3);
        extra += `<circle class="badge" cx="${ix + 13}" cy="${iy - 20}" r="${b.length > 1 ? 9 : 8}"/><text class="badge-t" x="${ix + 13}" y="${iy - 16.5}">${esc(b)}</text>`;
      }
      if (it.progress != null) {
        const c = 2 * Math.PI * 17, p = Math.max(0, Math.min(100, it.progress));
        extra += `<circle cx="${ix}" cy="${iy - 8}" r="17" fill="none" stroke="rgba(255,255,255,.1)" stroke-width="3"/>
          <circle cx="${ix}" cy="${iy - 8}" r="17" fill="none" stroke="rgb(var(--ok))" stroke-width="3" stroke-linecap="round" stroke-dasharray="${c * p / 100} ${c}" transform="rotate(-90 ${ix} ${iy - 8})"/>`;
      }
      const path = n === 1
        ? `M0,${-R2} A${R2},${R2} 0 1 1 -0.01,${-R2} Z M0,${-R1} A${R1},${R1} 0 1 0 0.01,${-R1} Z`
        : `M${x0},${y0} A${R2},${R2} 0 ${large} 1 ${x1},${y1} L${x2},${y2} A${R1},${R1} 0 ${large} 0 ${x3},${y3} Z`;
      html += `<g class="wedge${it.readOnly ? ' ro' : ''}" data-k="${i}">
        <path d="${path}" fill-rule="evenodd"/>
        <svg class="wi" x="${ix - 11}" y="${iy - 19}" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${ICONS[it.icon] || ICONS.dots}</svg>
        ${extra}<text x="${ix}" y="${iy + 18}">${esc(it.label || '')}</text></g>`;
    });

    const wheel = `<div class="radial"><svg class="wheel" viewBox="-170 -170 340 340">${html}</svg>
      <div class="center"><div><div class="ct"></div><div class="cd"></div></div></div></div>`;
    if (animate) UI.show(root, wheel); else root.innerHTML = wheel;

    const ct = $('.ct', root), cd = $('.cd', root);
    const idle = () => {
      ct.textContent = menu.sub ? 'Back' : 'Close';
      cd.textContent = menu.title ? menu.title : (menu.sub ? '' : `${UI.cfg.radial?.key || 'Z'} to toggle`);
    };
    idle();
    $$('.wedge', root).forEach(g => {
      const it = items[+g.dataset.k];
      g.onmouseenter = () => { ct.textContent = it.label || ''; cd.textContent = it.description || ''; };
      g.onmouseleave = idle;
      g.onclick = () => {
        if (it.more) { page++; render(false); return; }
        if (!it.readOnly) UI.post('radial:select', { index: it.index });
      };
    });
    $('.center', root).onclick = back;
  }

  const back = () => UI.post(menu && menu.sub ? 'radial:back' : 'radial:close');

  UI.on('radial:open', d => {
    const animate = !menu;
    if (!menu || d.sub !== menu.sub || d.title !== menu.title) page = 0;
    menu = d;
    render(animate);
    UI.onEsc('radial', () => UI.post('radial:close'));
  });
  UI.on('radial:close', () => { menu = null; page = 0; UI.offEsc('radial'); UI.hide(root); });

  root.addEventListener('contextmenu', e => { e.preventDefault(); if (menu) back(); });
  document.addEventListener('keydown', e => {
    if (menu && e.key.toUpperCase() === String(UI.cfg.radial?.key || 'Z').toUpperCase()) UI.post('radial:close');
  });
})();
