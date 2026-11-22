(() => {
  const $ = id => document.getElementById(id);
  let show = {};

  /* scale every block with the screen height (designed at 1080p) */
  let userScale = 1;
  const fit = () => document.documentElement.style.setProperty('--s', (Math.min(innerHeight / 1080, innerWidth / 1920 * 1.25) * userScale).toFixed(4));
  addEventListener('resize', fit); fit();

  /* only touch the DOM when a value changes */
  const cache = new Map();
  const set = (key, value, apply) => { if (cache.get(key) !== value) { cache.set(key, value); apply(value); } };
  const text = (id, value) => set('t:' + id, value, v => { $(id).textContent = v; });
  const hide = (id, value) => set('h:' + id, value, v => { $(id).hidden = v; });
  const cls = (id, value) => set('c:' + id, value, v => { $(id).className = v; });

  /* status rings */
  const RINGS = {
    health: ['#ff6b5e', '<path d="M12 20.5s-7.5-4.6-9.2-9.4A4.9 4.9 0 0 1 12 7.2a4.9 4.9 0 0 1 9.2 3.9C19.5 15.9 12 20.5 12 20.5z"/>'],
    armor: ['#5ab8ff', '<path d="M12 3l7.5 3v6c0 4.6-3.2 7.8-7.5 9-4.3-1.2-7.5-4.4-7.5-9V6z"/>'],
    stamina: ['#b7f05a', '<path d="M13 2.5 4.5 13.5H11l-1 8 8.5-11H12z"/>'],
    hunger: ['#ffb84d', '<path d="M7 3v7M5 3v4.5a2 2 0 0 0 4 0V3M7 10v11M17 3c-2 2-3 5-3 8h3v10"/>'],
    thirst: ['#2fd4c0', '<path d="M12 3s-6.5 7.2-6.5 11.7a6.5 6.5 0 0 0 13 0C18.5 10.2 12 3 12 3z"/>'],
  };
  $('rings').innerHTML = Object.entries(RINGS).map(([k, [c, p]]) =>
    `<div class="ring" id="r-${k}" style="--c:${c};--v:0" hidden><svg class="ico" viewBox="0 0 24 24">${p}</svg></div>`).join('');

  /* compass strip, 3px per degree, covers -180..540 so any heading fits */
  const PPD = 3, CARD = {0:'N',45:'NE',90:'E',135:'SE',180:'S',225:'SW',270:'W',315:'NW'};
  const NAMES = ['N','NNE','NE','ENE','E','ESE','SE','SSE','S','SSW','SW','WSW','W','WNW','NW','NNW'];
  let sh = '';
  for (let d = -180; d <= 540; d += 5) {
    const n = ((d % 360) + 360) % 360, x = (d + 180) * PPD, card = n in CARD;
    sh += `<i class="tick ${card ? 'card' : d % 15 === 0 ? 'mid' : ''}" style="left:${x}px"></i>`;
    if (card) sh += `<span class="tlab card ${n === 0 ? 'n' : ''}" style="left:${x}px">${CARD[n]}</span>`;
    else if (d % 15 === 0) sh += `<span class="tlab" style="left:${x}px">${n}</span>`;
  }
  $('strip').innerHTML = sh;

  function init(d) {
    show = d.show || {};
    const logo = d.logo || {};
    $('logoName').textContent = logo.name || '';
    $('logoAccent').textContent = logo.accent || '';
    $('logoSub').textContent = logo.subtitle || '';
    $('logo').hidden = !show.logo;
    $('job').hidden = !show.job;
    $('pid').hidden = !show.playerId;
    $('compass').hidden = !show.compass; $('hdg').hidden = !show.compass;
    $('streetBox').hidden = !show.street;
    $('clock').hidden = !show.clock;
    $('unit').textContent = d.unit || 'MPH';
    document.body.dataset.letterbox = d.letterbox ? '1' : '';
  }

  function identity(d) {
    $('pid').textContent = 'ID ' + d.id;
    $('jchip').textContent = d.chip;
    $('jchip').style.setProperty('--jc', d.color);
    $('jgrade').textContent = d.grade;
  }

  function status(s) {
    for (const k in RINGS) {
      const v = s[k], off = v === undefined || v === null || show[k] === false;
      hide('r-' + k, off);
      if (off) continue;
      set('v:' + k, v, val => {
        const r = $('r-' + k);
        r.style.setProperty('--v', val);
        r.classList.toggle('low', val <= 20);
      });
    }
  }

  function world(d) {
    const h = d.heading;
    set('hdg', Math.round(h * 2) / 2, v => {
      $('strip').style.transform = `translateX(${270 - (v + 180) * PPD}px)`;
      $('hdg').textContent = String(Math.round(v) % 360).padStart(3, '0') + '° ' + NAMES[Math.round(v / 22.5) % 16];
    });
    if (d.street) {
      text('street', d.street.name || '');
      text('zone', d.street.zone || '');
      hide('zoneSep', !d.street.zone);
    }
    if (d.clock) { text('time', d.clock.time); text('date', d.clock.date); }
  }

  function weapon(w) {
    hide('weapon', !w);
    if (!w) return;
    text('wname', w.name);
    const hasAmmo = typeof w.clip === 'number';
    hide('ammo', !hasAmmo); hide('pips', !hasAmmo);
    if (!hasAmmo) return;
    text('clip', String(w.clip)); text('reserve', String(w.reserve));
    const pipCount = Math.min(w.maxClip, 40);
    set('pips', pipCount + ':' + w.clip, () => {
      const lit = Math.round(w.clip / w.maxClip * pipCount);
      $('pips').innerHTML = Array.from({ length: pipCount }, (_, i) => `<span class="${i < lit ? '' : 'off'}"></span>`).join('');
    });
  }

  function voice(v) {
    hide('voice', !v);
    if (!v) return;
    cls('voice', 'voice glass' + (v.talking ? ' talk' : ''));
    const hasRange = typeof v.range === 'number';
    hide('range', !hasRange); hide('vlab', !hasRange);
    if (hasRange) {
      set('range', v.range, r => [...$('range').children].forEach((s, i) => s.classList.toggle('on', i <= r)));
      text('vlab', v.label || ['Whisper', 'Normal', 'Shout'][v.range]);
    }
    hide('radio', !v.radio);
    if (v.radio) text('radio', v.radio);
  }

  function vehicle(v) {
    hide('veh', !v);
    if (!v) return;
    text('spd', String(v.speed));
    set('arc', v.speed, s => $('arc').setAttribute('stroke-dasharray', `${(75 * Math.min(s, 160) / 160).toFixed(2)} 100`));
    text('gear', v.gear);
    text('fuelv', v.fuel + '%');
    cls('fuel', 'vt' + (v.fuel <= 15 ? ' red' : ''));
    hide('belt', !v.beltApplies);
    cls('belt', 'vi ' + (v.belt ? 'green' : 'red' + (v.speed > 10 ? ' flash' : '')));
    hide('eng', v.engine > 40);
    cls('lights', 'vi' + (v.lights ? ' blue' : ''));
    hide('siren', !v.emergency);
    cls('siren', 'vi' + (v.siren ? ' siren' : ''));
    set('sig', v.indicator, i => {
      $('sigL').classList.toggle('on', i === 1 || i === 3);
      $('sigR').classList.toggle('on', i === 2 || i === 3);
    });
  }

  addEventListener('message', e => {
    const d = e.data || {};
    switch (d.action) {
      case 'init': init(d); break;
      case 'identity': identity(d); break;
      case 'settings':
        userScale = Math.max(0.5, Math.min(1.5, Number(d.scale) || 1)); fit();
        $('tc').hidden = d.compass === false;
        break;
      case 'visible':
        $('hud').hidden = !d.value;
        document.body.classList.toggle('cine', !!d.cinematic && document.body.dataset.letterbox === '1');
        break;
      case 'tick':
        status(d.status || {});
        world(d);
        weapon(d.weapon);
        voice(d.voice);
        vehicle(d.vehicle);
        break;
    }
  });
})();
