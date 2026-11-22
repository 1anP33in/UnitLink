/* Notifications (standard + police / SAFR) */
(() => {
  'use strict';
  const { $, esc, fmt, rgb, svg } = UI;
  const POSITIONS = ['top-right', 'top-left', 'bottom-right', 'bottom-left', 'center-top'];
  const root = $('#notify');
  const live = new Map(); // id -> { slot, timer, leaving }
  let seq = 0;

  const cfg = () => UI.cfg.notify || {};
  const position = () => (POSITIONS.includes(cfg().position) ? cfg().position : 'top-right');
  const isBottom = () => position().startsWith('bottom');

  UI.onInit(() => {
    root.className = 'pos-' + position();
    root.style.setProperty('--ox', (cfg().offset?.x ?? 24) + 'px');
    root.style.setProperty('--oy', (cfg().offset?.y ?? 24) + 'px');
  });

  function mount(id, html, duration) {
    const existing = live.get(id);
    if (existing && !existing.leaving) {
      existing.slot.innerHTML = html;
      existing.slot.firstElementChild.classList.add('upd');
      arm(id, existing, duration);
      return;
    }
    const slot = document.createElement('div');
    slot.className = 'slot';
    slot.innerHTML = html;
    if (isBottom()) root.appendChild(slot); else root.prepend(slot);
    const item = { slot, timer: null, leaving: false };
    live.set(id, item);
    arm(id, item, duration);

    const max = Math.max(1, cfg().maxVisible || 5);
    const ids = [...live.keys()].filter(k => !live.get(k).leaving);
    for (let i = 0; i < ids.length - max; i++) remove(ids[i]);
  }

  function arm(id, item, duration) {
    clearTimeout(item.timer);
    if (Number(duration) > 0) item.timer = setTimeout(() => remove(id), Number(duration));
  }

  function remove(id) {
    const item = live.get(id);
    if (!item || item.leaving) return;
    item.leaving = true;
    clearTimeout(item.timer);
    const slot = item.slot;
    slot.style.height = slot.offsetHeight + 'px';
    void slot.offsetHeight;
    slot.classList.add('out');
    setTimeout(() => { slot.remove(); live.delete(id); }, 340);
  }

  const bar = d => (Number(d) > 0 ? `<div class="bar"><i style="animation-duration:${Number(d)}ms"></i></div>` : '');

  function notify(d) {
    const types = cfg().types || {};
    const type = types[d.type] ? d.type : 'info';
    const t = types[type] || {};
    const id = String(d.id ?? 'ui' + ++seq);
    mount(id, `
      <div class="n t-${type}" style="--rgb:${rgb(d.color || t.color, '59,167,255')}">
        <div class="ic">${svg(d.icon || t.icon, 'info')}</div>
        <div class="bd">
          ${t.tag ? `<div class="tag">${esc(t.tag)}</div>` : ''}
          <div class="hd"><div class="tt">${esc(d.title ?? t.title ?? '')}</div>${t.tag ? '' : '<div class="tm">now</div>'}</div>
          <div class="msg">${fmt(d.message)}</div>
        </div>
        ${bar(d.duration)}
      </div>`, d.duration);
  }

  function dispatch(d) {
    const deps = cfg().departments || {};
    const deptKey = deps[d.dept] ? d.dept : Object.keys(deps)[0];
    const dept = deps[deptKey] || {};
    const prios = cfg().priorities || [];
    const levels = prios.length || 3;
    let prio = parseInt(d.priority, 10);
    if (!(prio >= 1 && prio <= levels)) prio = Math.min(2, levels);
    const p = prios[prio - 1] || {};
    const f = cfg().flash || {};
    const id = String(d.id ?? 'ui' + ++seq);

    const flashing = typeof d.flash === 'boolean' ? d.flash : !!(f.enabled && prio <= (f.maxPriority ?? 2));
    const cls = ['n', 'dispatch', 'st-' + (dept.strip || 'lightbar')];
    if (flashing) {
      if (f.strip !== false) cls.push('fl-strip');
      if (f.edge !== false) cls.push('fl-edge');
      if (f.glow !== false) cls.push('fl-glow');
    }
    if (p.pulse) cls.push('p-pulse');

    const pi = cfg().priorityIndicator || {};
    let pips = '';
    if (pi.pips !== false) {
      const filled = Math.ceil((levels - prio + 1) * 3 / levels);
      pips = '<span class="pips">' + [1, 2, 3].map(i => `<i class="${i <= filled ? 'on' : ''}"></i>`).join('') + '</span>';
    }
    const chips = [];
    if (pi.chip !== false) chips.push(`<span class="chip prio">${esc(p.short || 'P' + prio)} · ${esc(p.label || 'Priority ' + prio)}</span>`);
    if (d.location) chips.push(`<span class="chip">${svg('pin')}${esc(d.location)}</span>`);

    const c = dept.colors || [];
    const style = [
      `--rgb:${rgb(c[0])}`, `--c1:${rgb(c[0])}`, `--c2:${rgb(c[1] || c[0])}`,
      `--prgb:${rgb(p.color, '245,165,36')}`, `--spd:${Number(f.speed) || 500}ms`,
      dept.tint ? `--tint:${esc(dept.tint)}` : '',
    ].filter(Boolean).join(';');

    mount(id, `
      <div class="${cls.join(' ')}" style="${style}">
        <div class="strip"></div>
        <div class="ic">${svg(d.icon || dept.icon, 'bell')}</div>
        <div class="bd">
          <div class="dh"><span class="dept">${esc(dept.label || String(deptKey).toUpperCase())}</span>${d.code ? `<span class="code">${esc(d.code)}</span>` : ''}${pips}</div>
          <div class="hd"><div class="tt">${esc(d.title || 'Dispatch')}</div></div>
          <div class="msg">${fmt(d.message)}</div>
          ${chips.length ? `<div class="meta">${chips.join('')}</div>` : ''}
        </div>
        ${bar(d.duration)}
      </div>`, d.duration);
  }

  UI.on('notify', notify);
  UI.on('dispatch', dispatch);
  UI.on('notify:remove', d => remove(String(d.id)));
  UI.on('notify:clear', () => [...live.keys()].forEach(remove));
})();
