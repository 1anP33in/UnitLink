/* List menu (keyboard only, state lives in Lua) */
(() => {
  'use strict';
  const { $, esc, svg, tone } = UI;
  const root = $('#list');
  const POS = ['top-left', 'top-right', 'bottom-left', 'bottom-right'];
  let menu = null;
  let state = { selected: 1, scroll: [], checked: [] };

  const valueOf = v => (v && typeof v === 'object' ? v : { label: String(v ?? '') });

  function row(o, i) {
    const n = i + 1, sel = n === state.selected;
    let desc = o.description || '';
    let right = '';
    if (Array.isArray(o.values) && o.values.length) {
      const v = valueOf(o.values[(state.scroll[i] || 1) - 1]);
      if (v.description) desc = v.description;
      right = `<div class="side">${svg('left')}<span class="v">${esc(v.label)}</span>${svg('right')}</div>`;
    } else if (o.checkbox) {
      right = `<div class="chk${state.checked[i] ? ' on' : ''}"><div class="bx">${svg('check')}</div></div>`;
    } else if (o.progress != null) {
      right = `<div class="mbar"><i style="width:${Math.max(0, Math.min(100, o.progress))}%"></i></div>`;
    }
    if (o.disabled) right += svg('lock');
    const cls = ['lr'];
    if (sel) cls.push('sel');
    if (desc) cls.push('has-d');
    if (o.disabled) cls.push('dis');
    return `<div class="${cls.join(' ')}">${svg(o.icon || 'dots', 'dots')}<div class="lt">${esc(o.label || '')}</div>${right}<div class="ld">${esc(desc)}</div></div>`;
  }

  function render(animate) {
    if (!menu) return;
    const opts = menu.options || [];
    const html = `
      <div class="card lm" style="--rgb:${tone(menu.color)}">
        <div class="lhead">
          ${menu.icon ? `<div class="ic sm">${svg(menu.icon, 'dots')}</div>` : ''}
          <div><div class="tt">${esc(menu.title || '')}</div><div class="sub">${esc(menu.subtitle || '')}</div></div>
          <div class="count">${state.selected}/${opts.length}</div>
        </div>
        <div class="rows">${opts.map(row).join('')}</div>
        <div class="lfoot hints">
          <span><span class="key">↑</span><span class="key">↓</span>Navigate</span>
          <span><span class="key">←</span><span class="key">→</span>Change</span>
          <span><span class="key">↵</span>Select</span>
          ${menu.canClose === false ? '' : '<span><span class="key">⌫</span>Close</span>'}
        </div>
      </div>`;
    if (animate) UI.show(root, html); else root.innerHTML = html;
    const sel = $('.lr.sel', root);
    if (sel) sel.scrollIntoView({ block: 'nearest' });
  }

  UI.on('list:open', d => {
    menu = d;
    state = d.state || { selected: 1, scroll: [], checked: [] };
    root.className = 'pos-' + (POS.includes(d.position) ? d.position : (UI.cfg.list?.position || 'top-left'));
    render(true);
  });
  UI.on('list:state', s => { state = s; render(false); });
  UI.on('list:close', () => { menu = null; UI.hide(root); });
})();
