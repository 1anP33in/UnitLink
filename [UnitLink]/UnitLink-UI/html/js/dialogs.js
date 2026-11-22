/* Alert dialog + input dialog (share the #modal layer) */
(() => {
  'use strict';
  const { $, $$, esc, fmt, svg, tone } = UI;
  const modal = $('#modal');
  const TYPES = { info: ['accent', 'info'], success: ['ok', 'check'], warning: ['warn', 'warning'], danger: ['bad', 'warning'], error: ['bad', 'x'] };

  const openModal = html => {
    modal.className = UI.cfg.dialog?.backdrop === false ? '' : 'backdrop';
    UI.show(modal, html);
  };

  /* ================= alert ================= */
  function callout(c) {
    const t = TYPES[c.type] || TYPES.info;
    return `<div class="callout" style="--rgb:var(--${t[0]})">${svg(c.icon || t[1], 'info')}<div>${c.label ? `<b>${esc(c.label)}</b>` : ''}${fmt(c.text || c.description || '')}</div></div>`;
  }

  UI.on('alert:open', d => {
    const t = TYPES[d.type] || TYPES.info;
    const callouts = d.callout ? (Array.isArray(d.callout) ? d.callout : [d.callout]) : [];
    const labels = d.labels || {};
    openModal(`
      <div class="card dlg" style="--rgb:${d.color ? tone(d.color) : `var(--${t[0]})`}">
        <div class="dhead">
          <div class="ic">${svg(d.icon || t[1], 'info')}</div>
          <div><div class="tt">${esc(d.header || 'Are you sure?')}</div><div class="sub">${esc(d.subheader || '')}</div></div>
        </div>
        <div class="dbody">${fmt(d.content || '')}</div>
        ${callouts.map(callout).join('')}
        <div class="btns">
          ${d.cancel === false ? '' : `<button class="btn ghost" data-r="cancel">${esc(labels.cancel || 'Cancel')}</button>`}
          <button class="btn solid" data-r="confirm">${esc(labels.confirm || 'Confirm')}</button>
        </div>
      </div>`);
    $$('[data-r]', modal).forEach(b => b.onclick = () => answer(b.dataset.r));
    UI.onEsc('alert', () => answer('cancel'));
  });
  function answer(result) { UI.offEsc('alert'); UI.post('alert:close', { result }); }
  UI.on('alert:close', () => { UI.offEsc('alert'); UI.hide(modal); });

  /* ================= input ================= */
  let rows = [];
  const optList = r => (r.options || []).map(o => (typeof o === 'object' ? { value: o.value ?? o.label, label: o.label ?? String(o.value) } : { value: o, label: String(o) }));
  const COLORS = ['#ef4b5a', '#f5a524', '#22c38a', '#3ba7ff', '#a77bf3', '#f2f4f8', '#1b2130'];

  function field(r, i) {
    const type = r.type || 'input';
    const req = r.required ? ' <span class="req">*</span>' : '';
    const label = r.label ? `<label>${esc(r.label)}${req}</label>` : '';
    const desc = r.description ? `<div class="desc">${esc(r.description)}</div>` : '';
    const err = '<div class="err"></div>';
    const icon = r.icon ? svg(r.icon) : '';
    const ph = esc(r.placeholder || '');
    const wrap = (inner, extra = '') => `<div class="f${r.disabled ? ' dis' : ''}" data-i="${i}" data-t="${type}"${extra}>${label}${inner}${err}${desc}</div>`;
    const def = r.default;

    switch (type) {
      case 'input':
        return wrap(`<div class="box">${icon}<input type="${r.password ? 'password' : 'text'}" placeholder="${ph}" value="${esc(def ?? '')}"${r.max ? ` maxlength="${r.max}"` : ''}>${r.password ? `<button class="sbtn" data-eye>${svg('eye')}</button>` : ''}</div>`);
      case 'textarea':
        return wrap(`<div class="box ta"><textarea placeholder="${ph}"${r.max ? ` maxlength="${r.max}"` : ''}>${esc(def ?? '')}</textarea></div>`);
      case 'number':
        return wrap(`<div class="box">${icon}<button class="sbtn" data-step="-1">${svg('minus')}</button><input type="number" value="${def ?? ''}" placeholder="${ph}"${r.min != null ? ` min="${r.min}"` : ''}${r.max != null ? ` max="${r.max}"` : ''} step="${r.step || 1}"><button class="sbtn" data-step="1">${svg('plus')}</button></div>`);
      case 'select': {
        const opts = optList(r), cur = opts.find(o => o.value === def);
        return wrap(`<div class="sel"><div class="box">${icon}<span class="val${cur ? '' : ' ph'}">${esc(cur ? cur.label : (r.placeholder || 'Select…'))}</span>${svg('down', null).replace('class="i"', 'class="i chev"')}</div>
          <div class="dd">${opts.map((o, k) => `<div data-k="${k}" class="${cur && cur.value === o.value ? 'on' : ''}">${esc(o.label)}</div>`).join('')}</div></div>`);
      }
      case 'multi-select': {
        const on = Array.isArray(def) ? def : [];
        return wrap(`<div class="tags">${optList(r).map((o, k) => `<button data-k="${k}" class="${on.includes(o.value) ? 'on' : ''}">${esc(o.label)}</button>`).join('')}</div>`);
      }
      case 'slider': {
        const min = r.min ?? 0, max = r.max ?? 100, v = def ?? min;
        return wrap(`<div class="slider"><input type="range" min="${min}" max="${max}" step="${r.step || 1}" value="${v}"><output></output></div>`);
      }
      case 'toggle':
        return `<div class="f${r.disabled ? ' dis' : ''}" data-i="${i}" data-t="toggle"><div class="tog${def ? ' on' : ''}"><div><div class="tl">${esc(r.label || '')}</div>${desc.replace('class="desc"', 'class="desc" style="margin:2px 0 0"')}</div><div class="sw"></div></div>${err}</div>`;
      case 'checkbox':
        return `<div class="f${r.disabled ? ' dis' : ''}" data-i="${i}" data-t="checkbox"><div class="chk${def ? ' on' : ''}"><div class="bx">${svg('check')}</div>${esc(r.label || '')}${req}</div>${err}${desc}</div>`;
      case 'color': {
        const list = r.colors || COLORS, v = def || list[0];
        return wrap(`<div class="colors">${list.map(c => `<button style="background:${esc(c)}" data-c="${esc(c)}" class="${c.toLowerCase() === String(v).toLowerCase() ? 'on' : ''}"></button>`).join('')}<span class="hex">${esc(String(v).toUpperCase())}</span></div>`);
      }
      case 'date':
        return wrap(`<div class="box">${icon || svg('calendar')}<input type="date" value="${esc(def || '')}"${r.min ? ` min="${esc(r.min)}"` : ''}${r.max ? ` max="${esc(r.max)}"` : ''}></div>`);
      case 'date-range': {
        const v = Array.isArray(def) ? def : [];
        return wrap(`<div class="range"><div class="box">${svg('calendar')}<input type="date" value="${esc(v[0] || '')}"></div><span class="muted">to</span><div class="box">${svg('calendar')}<input type="date" value="${esc(v[1] || '')}"></div></div>`);
      }
      default:
        return '';
    }
  }

  function bind(form) {
    $$('[data-eye]', form).forEach(b => b.onclick = () => { const i = b.previousElementSibling; i.type = i.type === 'password' ? 'text' : 'password'; });
    $$('[data-step]', form).forEach(b => b.onclick = () => {
      const n = $('input', b.parentElement), step = Number(n.step) || 1;
      let v = (Number(n.value) || 0) + step * Number(b.dataset.step);
      if (n.min !== '') v = Math.max(Number(n.min), v);
      if (n.max !== '') v = Math.min(Number(n.max), v);
      n.value = v;
    });
    $$('.sel', form).forEach(s => {
      const r = rows[+s.closest('.f').dataset.i];
      $('.box', s).onclick = e => { e.stopPropagation(); $$('.sel.open', form).forEach(o => o !== s && o.classList.remove('open')); s.classList.toggle('open'); };
      $$('.dd div', s).forEach(o => o.onclick = () => {
        $$('.dd div', s).forEach(x => x.classList.toggle('on', x === o));
        const val = $('.val', s); val.textContent = o.textContent; val.classList.remove('ph');
        s.dataset.k = o.dataset.k; s.classList.remove('open');
        s.closest('.f').classList.remove('bad');
      });
      const opts = optList(r), k = opts.findIndex(o => o.value === r.default);
      if (k >= 0) s.dataset.k = k;
    });
    form.addEventListener('click', e => { if (!e.target.closest('.sel')) $$('.sel.open', form).forEach(o => o.classList.remove('open')); });
    $$('.tags button', form).forEach(b => b.onclick = () => b.classList.toggle('on'));
    $$('.slider input', form).forEach(r => {
      const sync = () => {
        const p = ((r.value - r.min) / ((r.max - r.min) || 1)) * 100;
        r.style.setProperty('--p', p + '%');
        r.nextElementSibling.textContent = r.value;
      };
      r.oninput = sync; sync();
    });
    $$('.tog,.chk', form).forEach(t => t.onclick = () => { t.classList.toggle('on'); t.closest('.f').classList.remove('bad'); });
    $$('.colors button', form).forEach(b => b.onclick = () => {
      const c = b.parentElement;
      $$('button', c).forEach(x => x.classList.toggle('on', x === b));
      $('.hex', c).textContent = b.dataset.c.toUpperCase();
    });
    $$('input,textarea', form).forEach(el => el.addEventListener('input', () => el.closest('.f').classList.remove('bad')));
    $$('.box input', form).forEach(el => el.addEventListener('keydown', e => { if (e.key === 'Enter') submit(); }));
  }

  function read(f, r) {
    const t = f.dataset.t;
    switch (t) {
      case 'input': case 'textarea': { const v = $('input,textarea', f).value; return v === '' ? null : v; }
      case 'number': { const v = $('input', f).value; return v === '' ? null : Number(v); }
      case 'select': { const s = $('.sel', f); return s.dataset.k != null ? optList(r)[+s.dataset.k].value : null; }
      case 'multi-select': { const opts = optList(r); return $$('.tags button', f).filter(b => b.classList.contains('on')).map(b => opts[+b.dataset.k].value); }
      case 'slider': return Number($('input', f).value);
      case 'toggle': return $('.tog', f).classList.contains('on');
      case 'checkbox': return $('.chk', f).classList.contains('on');
      case 'color': { const on = $('.colors button.on', f); return on ? on.dataset.c : null; }
      case 'date': { const v = $('input', f).value; return v || null; }
      case 'date-range': { const [a, b] = $$('input', f).map(x => x.value || null); return a || b ? [a, b] : null; }
    }
    return null;
  }

  function check(r, v) {
    const empty = v == null || v === false || (Array.isArray(v) && (v.length === 0 || v.some(x => x == null)));
    if (r.required && empty) return 'This field is required';
    if (v == null) return null;
    if (r.type === 'number') {
      if (r.min != null && v < r.min) return `Must be at least ${r.min}`;
      if (r.max != null && v > r.max) return `Must be at most ${r.max}`;
    }
    if ((r.type || 'input') === 'input' || r.type === 'textarea') {
      if (r.min && String(v).length < r.min) return `At least ${r.min} characters`;
    }
    return null;
  }

  function submit() {
    const form = $('.inp', modal);
    if (!form) return;
    const values = [];
    let firstBad = null;
    $$('.f', form).forEach(f => {
      const i = +f.dataset.i, r = rows[i], v = read(f, r), e = check(r, v);
      f.classList.toggle('bad', !!e);
      $('.err', f).textContent = e || '';
      if (e && !firstBad) firstBad = f;
      values[i] = v;
    });
    if (firstBad) { firstBad.scrollIntoView({ block: 'nearest' }); return; }
    UI.offEsc('input');
    UI.post('input:submit', { values });
  }
  function cancel() { UI.offEsc('input'); UI.post('input:submit', { cancelled: true }); }

  UI.on('input:open', d => {
    rows = Array.isArray(d.rows) ? d.rows : [];
    openModal(`
      <div class="card inp" style="--rgb:${tone(d.color)}">
        <div class="dhead">
          <div class="ic">${svg(d.icon || 'edit', 'edit')}</div>
          <div><div class="tt">${esc(d.heading || 'Input')}</div><div class="sub">${esc(d.description || '')}</div></div>
        </div>
        <div class="fields">${rows.map(field).join('')}</div>
        <div class="btns">
          ${d.cancel === false ? '' : `<button class="btn ghost" data-a="cancel">${esc(d.cancelLabel || 'Cancel')}</button>`}
          <button class="btn solid" data-a="submit">${esc(d.submitLabel || 'Submit')}</button>
        </div>
      </div>`);
    const form = $('.inp', modal);
    bind(form);
    $('[data-a="submit"]', form).onclick = submit;
    const c = $('[data-a="cancel"]', form);
    if (c) c.onclick = cancel;
    UI.onEsc('input', () => { if (d.cancel !== false) cancel(); });
    const first = $('.f:not(.dis) input:not([type=range]), .f:not(.dis) textarea', form);
    if (first) setTimeout(() => first.focus(), 60);
  });
  UI.on('input:close', () => { UI.offEsc('input'); UI.hide(modal); });
})();
