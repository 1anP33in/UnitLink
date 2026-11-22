/* Mini games: skill check, signal breach, pattern lock */
(() => {
  'use strict';
  const { $, $$, svg } = UI;
  const root = $('#minigame');
  let stop = null;      // cleanup for the running game
  let finished = false;

  const keyName = e => (e.key === ' ' ? 'SPACE' : e.key.length === 1 ? e.key.toUpperCase() : e.key.toUpperCase());

  function frame(cls, icon, title, sub, stage, footer = '') {
    return `<div class="card mg ${cls}">
      <div class="mh"><div class="ic sm">${svg(icon)}</div><div><div class="tt">${title}</div><div class="sub">${sub}</div></div></div>
      <div class="stage">${stage}</div>
      ${footer}
      <div class="mf"><div class="status"></div><div class="rounds"></div></div>
    </div>`;
  }

  function finish(success, text) {
    if (finished) return;
    finished = true;
    if (stop) stop();
    stop = null;
    UI.offEsc('minigame');
    const card = $('.mg', root);
    if (card) {
      card.classList.add(success ? 'win' : 'lose');
      $('.status', card).textContent = text || (success ? 'Success' : 'Failed');
    }
    setTimeout(() => { UI.hide(root); UI.post('minigame:done', { success }); }, 650);
  }

  function begin(html) {
    if (stop) stop();
    finished = false;
    UI.show(root, html);
    UI.onEsc('minigame', () => finish(false, 'Cancelled'));
  }

  /* ---------------- skill check ---------------- */
  function skill(p) {
    const rounds = p.rounds && p.rounds.length ? p.rounds : [{ zone: 40, speed: 260 }];
    const keys = p.keys && p.keys.length ? p.keys.map(k => String(k).toUpperCase()) : ['E'];
    begin(frame('', 'target', 'Skill Check', 'Press the key in the zone', `
      <div class="sc"><svg viewBox="-60 -60 120 120">
        <circle class="trk" r="48"></circle><circle class="zone" r="48"></circle>
        <line class="needle" x1="0" y1="-30" x2="0" y2="-56"></line></svg>
        <div class="hub"><span class="key ac"></span></div></div>`));
    const card = $('.mg', root), zone = $('.zone', card), needle = $('.needle', card), keyEl = $('.hub .key', card);
    const status = $('.status', card), pips = $('.rounds', card);
    const C = 2 * Math.PI * 48;
    const results = [];
    let round = 0, angle = 0, zStart = 0, zSize = 0, key = 'E', last = 0, raf;
    const drawPips = () => { pips.innerHTML = rounds.length > 1 ? rounds.map((_, i) => `<i class="${results[i] === true ? 'done' : results[i] === false ? 'fail' : ''}"></i>`).join('') : ''; };
    function next() {
      const r = rounds[round];
      zSize = Math.max(5, Math.min(180, r.zone || 40));
      zStart = 120 + Math.random() * (220 - zSize);
      angle = 0;
      key = keys[Math.floor(Math.random() * keys.length)];
      keyEl.textContent = key === 'SPACE' ? '␣' : key;
      zone.setAttribute('stroke-dasharray', `${C * zSize / 360} ${C}`);
      zone.setAttribute('transform', `rotate(${zStart - 90})`);
      status.textContent = rounds.length > 1 ? `Round ${round + 1} of ${rounds.length}` : `Press ${key} in the zone`;
      drawPips();
    }
    function hit(ok) {
      results[round] = ok; drawPips();
      if (!ok) return finish(false);
      round++;
      if (round >= rounds.length) return finish(true);
      next();
    }
    function tick(t) {
      angle += (rounds[round].speed || 260) * Math.min(0.05, Math.max(0, (t - last) / 1000)); last = t;
      needle.setAttribute('transform', `rotate(${angle})`);
      if (angle > zStart + zSize + 8) return hit(false);
      raf = requestAnimationFrame(tick);
    }
    const onKey = e => {
      const k = keyName(e);
      if (k === 'ESCAPE' || e.repeat) return;
      e.preventDefault();
      hit(k === key && angle >= zStart && angle <= zStart + zSize);
    };
    document.addEventListener('keydown', onKey);
    stop = () => { cancelAnimationFrame(raf); document.removeEventListener('keydown', onKey); };
    next();
    last = performance.now();
    raf = requestAnimationFrame(tick);
  }

  /* ---------------- signal breach ---------------- */
  function breach(p) {
    const n = Math.max(1, p.nodes || 4);
    const pool = p.keys && p.keys.length ? p.keys.map(k => String(k).toUpperCase()) : ['W', 'A', 'S', 'D'];
    const keys = Array.from({ length: n }, () => pool[Math.floor(Math.random() * pool.length)]);
    begin(frame('', 'signal', 'Signal Breach', 'Hit the key inside the window', `
      <div class="sb"><div class="nodes"></div><div class="sbtrack"><div class="win"></div><div class="cur"></div></div></div>`));
    const card = $('.mg', root);
    card.style.setProperty('--rgb', 'var(--purple)');
    const nodesEl = $('.nodes', card), win = $('.win', card), cur = $('.cur', card), status = $('.status', card);
    let idx = 0, pos = 0, dir = 1, sweeps = 0, speed = p.speed || 70, wSize = p.window || 20, wPos = 0, last = 0, raf;
    const done = [];
    const maxSweeps = p.maxSweeps || 4;
    function draw(fail) {
      nodesEl.innerHTML = keys.map((k, i) => (i ? `<div class="link${done[i - 1] && done[i] ? ' ok' : ''}"></div>` : '') +
        `<div class="node${done[i] ? ' ok' : ''}${i === idx && !finished ? ' cur' : ''}${fail === i ? ' no' : ''}">${k === 'SPACE' ? '␣' : k}</div>`).join('');
      status.textContent = `Node ${Math.min(idx + 1, n)} of ${n}`;
    }
    function place() { wPos = 4 + Math.random() * (92 - wSize); win.style.left = wPos + '%'; win.style.width = wSize + '%'; }
    function fail() { cancelAnimationFrame(raf); finished = false; draw(idx); finish(false, 'Signal lost'); }
    function tick(t) {
      pos += dir * speed * Math.min(0.05, Math.max(0, (t - last) / 1000)); last = t;
      if (pos >= 100 && dir > 0) { pos = 100; dir = -1; sweeps++; }
      if (pos <= 0 && dir < 0) { pos = 0; dir = 1; sweeps++; }
      cur.style.left = pos + '%';
      if (sweeps >= maxSweeps) return fail();
      raf = requestAnimationFrame(tick);
    }
    const onKey = e => {
      const k = keyName(e);
      if (k === 'ESCAPE' || e.repeat) return;
      e.preventDefault();
      const inside = pos >= wPos && pos <= wPos + wSize;
      if (k !== keys[idx]) { if (p.failOnWrongKey !== false) fail(); return; }
      if (!inside) return fail();
      done[idx] = true;
      UI.post('minigame:node', { index: idx + 1 });
      idx++;
      if (idx >= n) { draw(); return finish(true, 'Breach complete'); }
      speed *= p.speedUp || 1.15;
      wSize = Math.max(4, wSize * (p.shrink || 0.85));
      sweeps = 0;
      place(); draw();
    };
    document.addEventListener('keydown', onKey);
    stop = () => { cancelAnimationFrame(raf); document.removeEventListener('keydown', onKey); };
    place(); draw();
    last = performance.now();
    raf = requestAnimationFrame(tick);
  }

  /* ---------------- pattern lock ---------------- */
  function pattern(p) {
    const size = Math.max(2, Math.min(6, p.grid || 3)), len = Math.max(1, p.length || 5);
    const show = p.showSpeed || 420, time = p.timeout || 6000, totalRounds = Math.max(1, p.rounds || 1);
    begin(frame('', 'grid', 'Pattern Lock', 'Watch, then repeat the pattern',
      `<div class="pl locked" style="grid-template-columns:repeat(${size},52px)">${Array.from({ length: size * size }, (_, i) => `<button data-i="${i}"></button>`).join('')}</div>`,
      '<div class="mbar ptimer"><i style="width:100%"></i></div>'));
    const card = $('.mg', root);
    card.style.setProperty('--rgb', 'var(--warn)');
    const grid = $('.pl', card), timer = $('.ptimer i', card), status = $('.status', card), pips = $('.rounds', card);
    const btns = $$('button', grid);
    let timers = [], raf, seq = [], step = 0, accepting = false, round = 0;
    const results = [];
    const drawPips = () => { pips.innerHTML = totalRounds > 1 ? Array.from({ length: totalRounds }, (_, i) => `<i class="${results[i] === true ? 'done' : results[i] === false ? 'fail' : ''}"></i>`).join('') : ''; };
    const clear = () => { timers.forEach(clearTimeout); timers = []; cancelAnimationFrame(raf); };
    function play() {
      clear(); accepting = false; grid.classList.add('locked'); timer.style.width = '100%';
      status.textContent = 'Watch the pattern…'; drawPips();
      seq = [];
      while (seq.length < len) { const r = Math.floor(Math.random() * size * size); if (r !== seq[seq.length - 1]) seq.push(r); }
      seq.forEach((c, k) => {
        timers.push(setTimeout(() => btns[c].classList.add('lit'), 400 + k * show));
        timers.push(setTimeout(() => btns[c].classList.remove('lit'), 400 + k * show + show * 0.7));
      });
      timers.push(setTimeout(() => {
        accepting = true; step = 0; grid.classList.remove('locked');
        status.textContent = `Repeat the pattern · 0 of ${len}`;
        const t0 = performance.now();
        const tick = t => {
          const left = 1 - (t - t0) / time;
          timer.style.width = Math.max(0, left) * 100 + '%';
          if (left <= 0) { results[round] = false; drawPips(); return finish(false, 'Out of time'); }
          raf = requestAnimationFrame(tick);
        };
        raf = requestAnimationFrame(tick);
      }, 400 + len * show + 150));
    }
    btns.forEach(b => b.onclick = () => {
      if (!accepting) return;
      const i = +b.dataset.i;
      b.classList.add('lit');
      if (seq[step] !== i) { accepting = false; results[round] = false; drawPips(); return finish(false, 'Wrong pattern'); }
      setTimeout(() => b.classList.remove('lit'), 200);
      step++;
      status.textContent = `Repeat the pattern · ${step} of ${len}`;
      if (step >= len) {
        accepting = false; results[round] = true; round++;
        if (round >= totalRounds) { drawPips(); return finish(true, 'Unlocked'); }
        timers.push(setTimeout(play, 500));
      }
    });
    stop = clear;
    play();
  }

  UI.on('minigame:start', d => {
    const p = d.params || {};
    if (d.kind === 'skill') skill(p);
    else if (d.kind === 'breach') breach(p);
    else if (d.kind === 'pattern') pattern(p);
  });
  UI.on('minigame:cancel', () => {
    if (stop) stop();
    stop = null; finished = true;
    UI.offEsc('minigame');
    UI.hide(root);
  });
})();
