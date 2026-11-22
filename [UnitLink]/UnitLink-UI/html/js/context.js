/* Context menu */
(() => {
  'use strict';
  const { $, $$, esc, fmt, rgb, svg, tone } = UI;
  const root = $('#context');

  function meta(o) {
    const list = Array.isArray(o.metadata) ? o.metadata : [];
    if (!list.length && !o.image) return '';
    const rows = list.map(m => `
      <div class="mrow"><span>${esc(m.label)}</span>${m.value != null ? `<b>${esc(m.value)}</b>` : ''}</div>
      ${m.progress != null ? `<div class="mbar"><i style="width:${Math.max(0, Math.min(100, m.progress))}%"></i></div>` : ''}`).join('');
    return `<div class="meta"><div>${o.image ? `<img src="${esc(o.image)}" alt="">` : ''}${rows}</div></div>`;
  }

  function option(o, i) {
    const cls = ['opt'];
    if (o.disabled) cls.push('dis');
    if (o.readOnly) cls.push('ro');
    const style = [o.iconColor ? `--rgb:${rgb(o.iconColor)}` : '', o.progressColor ? `--prgb:${rgb(o.progressColor)}` : ''].filter(Boolean).join(';');
    const end = [];
    if (o.keybind) end.push(`<span class="key">${esc(o.keybind)}</span>`);
    if (o.progress != null) end.push(`<span class="pv">${Math.round(o.progress)}%</span>`);
    if (o.disabled) end.push(svg('lock'));
    else if (o.arrow) end.push(svg('right'));
    return `
      <div class="${cls.join(' ')}" data-i="${i + 1}"${style ? ` style="${style}"` : ''}>
        ${o.icon ? `<div class="ic sm">${svg(o.icon, 'dots')}</div>` : ''}
        <div class="body">
          <div class="ot">${esc(o.title || '')}</div>
          ${o.description ? `<div class="od">${fmt(o.description)}</div>` : ''}
          ${o.progress != null ? `<div class="mbar"><i style="width:${Math.max(0, Math.min(100, o.progress))}%"></i></div>` : ''}
          ${meta(o)}
        </div>
        ${end.length ? `<div class="end">${end.join('')}</div>` : ''}
      </div>`;
  }

  UI.on('context:open', d => {
    root.className = 'pos-' + (UI.cfg.context?.position === 'left' ? 'left' : 'right');
    UI.show(root, `
      <div class="card ctx" style="--rgb:${tone(d.color)}">
        <div class="chead">
          ${d.canBack ? `<button class="back">${svg('left')}</button>` : ''}
          ${d.icon ? `<div class="ic sm">${svg(d.icon, 'dots')}</div>` : ''}
          <div><div class="tt">${esc(d.title || '')}</div><div class="sub">${esc(d.description || '')}</div></div>
        </div>
        <div class="list">${(d.options || []).map(option).join('')}</div>
      </div>`);
    const back = $('.back', root);
    if (back) back.onclick = () => UI.post('context:back');
    $$('.opt', root).forEach(el => el.onclick = () => {
      if (el.classList.contains('dis') || el.classList.contains('ro')) return;
      UI.post('context:select', { index: +el.dataset.i });
    });
    UI.onEsc('context', () => UI.post(d.canBack ? 'context:back' : 'context:close'));
  });

  UI.on('context:close', () => { UI.offEsc('context'); UI.hide(root); });
})();
