/* Text UI */
(() => {
  'use strict';
  const { $, esc, svg, tone } = UI;
  const root = $('#textui');
  const POS = ['right-center', 'left-center', 'top-center', 'bottom-center'];

  UI.on('text:show', d => {
    const pos = POS.includes(d.position) ? d.position : (UI.cfg.textui?.position || 'right-center');
    const style = `--rgb:${tone(d.color)}`;
    let html;
    if (Array.isArray(d.options) && d.options.length) {
      html = `<div class="card tui opts" style="${style}">
        ${d.title ? `<div class="th"><div class="tt">${esc(d.title)}</div><div class="sub">${esc(d.description || '')}</div></div>` : ''}
        ${d.options.map(o => `<div class="tr">${o.key ? `<span class="key">${esc(o.key)}</span>` : ''}${esc(o.label || '')}${o.icon ? svg(o.icon) : ''}</div>`).join('')}
      </div>`;
    } else if (!d.description && !d.icon) {
      html = `<div class="card tui small" style="${style}">${d.key ? `<span class="key">${esc(d.key)}</span>` : ''}<span class="tt" style="font-size:13px">${esc(d.title || '')}</span></div>`;
    } else {
      html = `<div class="card tui" style="${style}">
        ${d.icon ? `<div class="ic sm">${svg(d.icon, 'info')}</div>` : (d.key ? `<span class="key ac">${esc(d.key)}</span>` : '')}
        <div><div class="tt">${esc(d.title || '')}</div><div class="sub">${esc(d.description || '')}</div></div>
        ${d.icon && d.key ? `<span class="key ac" style="margin-left:6px">${esc(d.key)}</span>` : ''}
      </div>`;
    }
    const wasShown = UI.isShown(root) && root.className.includes('pos-' + pos);
    root.className = 'pos-' + pos + (wasShown ? ' show' : '');
    if (wasShown) root.innerHTML = html; else UI.show(root, html);
  });

  UI.on('text:hide', () => UI.hide(root));
})();
