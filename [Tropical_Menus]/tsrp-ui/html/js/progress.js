/* Progress bar */
(() => {
  'use strict';
  const { $, $$, esc, svg, tone } = UI;
  const root = $('#progress');
  let raf = null, steps = null, t0 = 0, dur = 1, endTimer = null;

  function paint(card, p) {
    $('.pct', card).textContent = Math.round(p * 100) + '%';
    if (steps) {
      const n = steps.length, seg = Math.min(n - 1, Math.floor(p * n));
      $$('.steps i', card).forEach((el, i) => { el.style.width = Math.max(0, Math.min(1, p * n - i)) * 100 + '%'; });
      $('.stp', card).textContent = seg + 1;
      $('.stl', card).textContent = steps[seg];
    } else {
      $('.track i', card).style.width = p * 100 + '%';
    }
  }

  UI.on('progress:start', d => {
    clearTimeout(endTimer);
    cancelAnimationFrame(raf);
    steps = Array.isArray(d.steps) && d.steps.length ? d.steps.map(String) : null;
    root.className = 'pos-' + (UI.cfg.progress?.position === 'center' ? 'center' : 'bottom');
    const sub = steps
      ? `Step <span class="stp">1</span> of ${steps.length} · <span class="stl">${esc(steps[0])}</span>`
      : esc(d.description || '');
    UI.show(root, `
      <div class="card prog" style="--rgb:${tone(d.color)}">
        <div class="top">
          ${d.icon ? `<div class="ic">${svg(d.icon, 'clock')}</div>` : ''}
          <div class="tx"><div class="tt">${esc(d.label || 'Working…')}</div><div class="sub">${sub}</div></div>
          <div class="pct">0%</div>
        </div>
        ${steps ? `<div class="steps">${steps.map(() => '<b><i></i></b>').join('')}</div>` : '<div class="track"><i></i></div>'}
        ${d.canCancel ? `<div class="foot hints"><span><span class="key">${esc(UI.cfg.progress?.cancelKey || 'X')}</span>Cancel</span><span class="state"></span></div>` : ''}
      </div>`);
    const card = $('.prog', root);
    t0 = performance.now();
    dur = Math.max(1, Number(d.duration) || 1);
    const tick = now => {
      const p = Math.min(1, (now - t0) / dur);
      paint(card, p);
      if (p < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
  });

  UI.on('progress:end', d => {
    cancelAnimationFrame(raf);
    const card = $('.prog', root);
    if (!card) return;
    if (d.cancelled) {
      card.classList.add('cancelled');
      const st = $('.state', card);
      if (st) st.textContent = 'Cancelled'; else $('.sub', card).textContent = 'Cancelled';
      endTimer = setTimeout(() => UI.hide(root), 900);
    } else {
      paint(card, 1);
      card.classList.add('done');
      endTimer = setTimeout(() => UI.hide(root), 300);
    }
  });
})();
