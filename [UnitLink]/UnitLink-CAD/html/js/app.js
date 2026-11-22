/* UnitLink CAD app. All data comes from the server through UL.req / pushes. */
(() => {
  'use strict';

  /* ============================ icons ============================ */
  const I = {
    back:'<path d="M19 12H5M11 6l-6 6 6 6"/>', fwd:'<path d="M5 12h14M13 6l6 6-6 6"/>',
    cad:'<rect x="3" y="4" width="18" height="12" rx="1.5"/><path d="M8 20h8M12 16v4"/>',
    search:'<circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/>',
    returns:'<path d="M4 6h16v12H4z"/><path d="M4 10h16M8 14h5"/>',
    forms:'<path d="M6 3h9l3 3v15H6z"/><path d="M9 10h6M9 14h6M9 18h3"/>',
    star:'<path d="M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1L3.2 9.5l6.1-.9z"/>',
    phone:'<path d="M5 4h4l2 5-2.5 1.5a11 11 0 005 5L15 13l5 2v4a2 2 0 01-2 2A16 16 0 013 6a2 2 0 012-2"/>',
    alert:'<path d="M12 3l9 16H3z"/><path d="M12 10v4M12 17v.1"/>',
    laws:'<path d="M12 3v18M5 7h14M7 7l-3 7a3 3 0 006 0zM17 7l-3 7a3 3 0 006 0z"/>',
    history:'<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    bell:'<path d="M6 16v-5a6 6 0 0112 0v5l1.5 2h-15z"/><path d="M10 20a2 2 0 004 0"/>',
    signal:'<path d="M5 18v-3M10 18v-6M15 18V9M20 18V5"/>',
    trash:'<path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/>',
    route:'<circle cx="6" cy="18" r="2"/><circle cx="18" cy="6" r="2"/><path d="M8 18h7a3 3 0 000-6H9a3 3 0 010-6h7"/>',
  };
  const svg = (n, c) => `<svg viewBox="0 0 24 24" ${c ? `style="--ic:${c}"` : ''}>${I[n]}</svg>`;

  /* ============================ state ============================ */
  const S = {
    cfg: null, me: null, board: { calls: [], units: [] }, signal100: false,
    screen: 'cad', hist: ['cad'], histPos: 0,
    selectedCall: null, callData: null, callTab: 'notes',
    person: null, lastReturn: null, returnsCount: 0,
    formTab: 'citation', charges: [], subject: null,
  };

  /* ============================ helpers ============================ */
  const $ = s => document.querySelector(s), $$ = s => [...document.querySelectorAll(s)];
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[c]));
  const pad = n => String(n).padStart(2, '0');
  const t24 = sec => { const d = new Date(sec * 1000); return `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`; };
  const d24 = sec => { const d = new Date(sec * 1000); return `${pad(d.getMonth()+1)}/${pad(d.getDate())}/${d.getFullYear()} ${t24(sec)}`; };
  const age = sec => { const m = Math.max(0, Math.floor((Date.now()/1000 - sec) / 60)); return m < 60 ? m + 'm' : Math.floor(m/60) + 'h' + (m%60) + 'm'; };
  const yrs = dob => Math.floor((Date.now() - new Date(dob)) / (365.25 * 864e5));
  const CLS = { F:'FELONY', M:'MISDEMEANOR', I:'INFRACTION' };
  let toastTimer;
  function toast(msg, err){ const t = $('#toast'); t.textContent = msg; t.className = 'toast on' + (err ? ' err' : ''); clearTimeout(toastTimer); toastTimer = setTimeout(() => t.className = 'toast', 2600); }
  async function call(action, payload, okMsg){
    const r = await UL.req(action, payload);
    if (!r || !r.ok){ toast((r && r.data) || 'Request failed.', true); return null; }
    if (okMsg) toast(okMsg);
    return r.data === undefined ? true : r.data;
  }
  const meUnit = () => S.board.units.find(u => u.callsign === S.me.callsign) || {};
  const myCalls = () => meUnit().calls || [];
  const findCall = id => S.board.calls.find(c => c.id === id);
  const callStatus = c => !c.units.length ? 'PENDING' : (c.units.some(u => (S.board.units.find(x => x.source === u.src) || {}).code === 'ARRVD') ? 'ARRVD' : 'ACTIVE');

  /* ============================ toolbar / nav ============================ */
  const TILES = [
    ['back','Back','#ffb547','back'],['fwd','Previous','#ffb547','fwd'],['|'],
    ['cad','CAD','#fff','cad'],['search','Search','#ffd257','search'],['returns','Returns','#ffd257','returns'],['forms','Forms','#fff','forms'],['|'],
    ['mycall','My Call','#cbd5e1','star'],['newcall','New Call','#3ee06a','phone'],['assign','Assign Self','#3ee06a','phone'],['alerts','Alerts','#ff6b6b','alert'],['laws','Laws','#ffd257','laws'],['history','History','#9cc3ff','history'],['|'],
    ['signal','Signal 100','#ffd257','signal'],['panic','Panic','#ff6b6b','bell'],
  ];
  function tileOff(t){
    if (t === 'mycall') return !myCalls().length;
    if (t === 'assign') return !S.selectedCall || !findCall(S.selectedCall) || myCalls().includes(S.selectedCall);
    if (t === 'back') return S.histPos === 0;
    if (t === 'fwd') return S.histPos >= S.hist.length - 1;
    if (t === 'signal') return !S.me.supervisor && !S.signal100;
    return false;
  }
  function renderToolbar(){
    $('#toolbar').innerHTML = TILES.map(t => t[0] === '|' ? '<div class="gap"></div>' :
      `<div class="tile ${t[0]==='panic'?'panic':''} ${t[0]==='signal'?'sig'+(S.signal100?' active':''):''} ${tileOff(t[0])?'off':''} ${t[0]===S.screen||(S.screen==='call'&&t[0]==='mycall'&&myCalls().includes(S.selectedCall))?'on':''}" data-t="${t[0]}">${svg(t[3], t[2])}${t[1]}</div>`).join('') +
      `<div class="seal"><div>${esc(S.cfg.name.toUpperCase())}</div></div>`;
    $$('#toolbar .tile').forEach(el => el.onclick = () => !el.classList.contains('off') && action(el.dataset.t));
    const Q = [['mycall','My Call','star','#cbd5e1'],['search','Search','search','#ffd257'],['laws','Laws','laws','#ffd257'],['history','Call History','history','#9cc3ff'],['alerts','Alerts','alert','#ff6b6b'],['newcall','New Call','phone','#3ee06a'],['assign','Assign Self','phone','#3ee06a'],['returns','Returns','returns','#ffd257']];
    $('#quick').innerHTML = Q.map(q => `<a data-q="${q[0]}" class="${tileOff(q[0])?'off':''}">${svg(q[2], q[3])}${q[1]}</a>`).join('');
    $$('#quick a').forEach(a => a.onclick = () => !a.classList.contains('off') && action(a.dataset.q));
  }
  const TITLES = { cad:'CAD', call:'Call', search:'Search', returns:'State Returns', forms:'Forms', alerts:'Alerts', laws:'Laws', history:'Call History' };
  function show(screen, push = true){
    S.screen = screen;
    $$('.screen').forEach(s => s.classList.toggle('on', s.id === 's-' + screen));
    if (push){ S.hist = S.hist.slice(0, S.histPos + 1); if (S.hist[S.histPos] !== screen){ S.hist.push(screen); S.histPos++; } }
    const c = S.callData && (S.callData.call || S.callData.closed);
    $('#winTitle').textContent = screen === 'call' && c ? `${c.id} - ${c.nature}` : TITLES[screen];
    if (screen === 'cad') renderBoard();
    if (screen === 'returns') loadReturns();
    if (screen === 'history') loadHistory();
    if (screen === 'forms'){ renderForms(); loadMyRecords(); }
    if (screen === 'alerts') loadAlerts();
    if (screen === 'laws') renderLaws();
    renderToolbar();
  }
  async function action(t){
    if (t === 'back'){ if (S.histPos > 0){ S.histPos--; show(S.hist[S.histPos], false); } return; }
    if (t === 'fwd'){ if (S.histPos < S.hist.length - 1){ S.histPos++; show(S.hist[S.histPos], false); } return; }
    if (t === 'mycall'){ if (myCalls().length) openCall(myCalls()[0]); return; }
    if (t === 'newcall') return newCallModal();
    if (t === 'assign'){ if (await call('assign', { id:S.selectedCall }, `Attached to call ${S.selectedCall}`)) refreshBoard(); return; }
    if (t === 'signal') return call('signal100', { on: !S.signal100 });
    if (t === 'panic'){ await call('panic', {}); toast('PANIC sent with your location', true); return; }
    show(t);
  }

  /* ============================ CAD board ============================ */
  function renderBoard(){
    const q = $('#callSearch').value.trim().toLowerCase();
    const calls = S.board.calls.filter(c => !q || JSON.stringify(c).toLowerCase().includes(q));
    $('#callsBody').innerHTML = calls.map(c => {
      const st = callStatus(c);
      const cls = c.priority === 1 ? 'c-p1' : st === 'PENDING' ? 'c-pend' : 'c-avail';
      return `<tr class="click ${cls} ${c.id===S.selectedCall?'sel':''}" data-id="${c.id}"><td>${c.id}</td><td>${esc(c.nature)}</td><td>${esc(c.address)}</td><td>${esc(c.city)}</td><td>${esc(c.county)}</td><td>${c.priority}</td><td>${st}</td><td>${c.units.map(u=>esc(u.callsign)).join(', ')}</td><td>${age(c.createdAt)}</td></tr>`;
    }).join('') || '<tr><td colspan="9" class="empty">No active calls</td></tr>';
    $$('#callsBody tr[data-id]').forEach(r => {
      r.onclick = () => { S.selectedCall = +r.dataset.id; renderBoard(); renderToolbar(); };
      r.ondblclick = () => openCall(+r.dataset.id);
    });

    const f = $('#agencyFilter').value, uq = $('#unitSearch').value.trim().toLowerCase();
    const depts = [...new Set(S.board.units.map(u => u.dept))].sort();
    const sel = $('#agencyFilter'); const keep = sel.value;
    sel.innerHTML = '<option value="">All Agencies</option>' + depts.map(d => `<option ${d===keep?'selected':''}>${esc(d)}</option>`).join('');
    const units = S.board.units.filter(u => (!f || u.dept === f) && (!uq || JSON.stringify(u).toLowerCase().includes(uq)));
    $('#unitsBody').innerHTML = units.map(u => {
      const mine = u.callsign === S.me.callsign;
      const cls = u.type && u.type !== 'leo' ? 'c-disp' : 'c-' + u.code.toLowerCase();
      const desc = u.calls.length ? `(MDC) ATTACHED TO CALL = ${u.calls.join(', ')}` : `(MDC) ${(S.cfg.statuses.find(s=>s.code===u.code)||{}).label || u.code}`;
      const status = mine ? `<select class="cellsel" id="myStatusCell">${S.cfg.statuses.map(s=>`<option value="${s.code}" ${s.code===u.code?'selected':''}>${s.code}</option>`).join('')}</select>` : u.code;
      return `<tr class="${cls} ${mine?'sel':''}"><td>${esc(u.name)}</td><td>${esc(u.callsign)}</td><td>${status}</td><td>${u.calls.join(', ')}</td><td>${esc(u.dept)}</td><td>${esc(u.location || '')}</td><td>${desc}</td></tr>`;
    }).join('') || '<tr><td colspan="7" class="empty">No units on duty</td></tr>';
    const ms = $('#myStatusCell'); if (ms) ms.onchange = () => setStatus(ms.value);
  }
  $('#callSearch').oninput = renderBoard; $('#unitSearch').oninput = renderBoard; $('#agencyFilter').onchange = renderBoard;
  $('#newCallPlus').onclick = () => newCallModal();

  function applyBoard(b){
    S.board = b; S.signal100 = !!b.signal100;
    const mu = meUnit();
    $('#sbStatus').innerHTML = S.cfg.statuses.map(s => `<option value="${s.code}" ${s.code===mu.code?'selected':''}>${s.code}</option>`).join('');
    $('#sbCall').textContent = mu.calls && mu.calls.length ? `Active Call: ${mu.calls.join(', ')}` : 'No Active Call';
    $('#sbSignal').style.display = S.signal100 ? '' : 'none';
    if (S.screen === 'cad') renderBoard();
    if (S.screen === 'call' && S.callData && S.callData.call){
      const live = findCall(S.callData.call.id);
      if (live){ S.callData.call = live; renderCall(); } else if (!S.callData.closed){ loadCall(S.callData.call.id); }
    }
    renderToolbar();
  }
  async function refreshBoard(){ const b = await call('board'); if (b) applyBoard(b); }
  async function setStatus(code){
    if (await call('setStatus', { code })) refreshBoard(); else refreshBoard();
  }
  $('#sbStatus').onchange = e => setStatus(e.target.value);

  /* ============================ modal ============================ */
  function modal(title, body, buttons){
    $('#mTitle').textContent = title; $('#mBody').innerHTML = body;
    $('#mFoot').innerHTML = buttons.map((b,i) => `<button class="btn ${b.cls||''}" data-i="${i}">${b.label}</button>`).join('');
    $$('#mFoot button').forEach(el => el.onclick = () => { const b = buttons[+el.dataset.i]; if (!b.run || b.run() !== false) closeModal(); });
    $('#modal').classList.add('on');
    const first = $('#mBody input, #mBody select, #mBody textarea'); if (first) first.focus();
  }
  const closeModal = () => $('#modal').classList.remove('on');
  const modalOpen = () => $('#modal').classList.contains('on');

  function newCallModal(){
    modal('New Call (self-initiated)', `
      <div><label class="lbl">Nature</label><select class="fin" id="ncNature">${S.cfg.natures.map(n=>`<option ${n==='10-38 TRAFFIC STOP'?'selected':''}>${esc(n)}</option>`).join('')}</select></div>
      <div><label class="lbl">Priority</label><select class="fin" id="ncPri"><option>3</option><option>2</option><option>1</option></select></div>
      <div><label class="lbl">Notes</label><textarea class="fin" id="ncNotes" placeholder="Plate, vehicle, what you see..."></textarea></div>
      <div class="hint">Created at your current location. You are attached automatically.</div>`,
      [{ label:'Cancel', cls:'gray' }, { label:'Create Call', cls:'green', run: () => { createCall(); } }]);
  }
  async function createCall(){
    const r = await call('createCall', { nature:$('#ncNature').value, priority:+$('#ncPri').value, notes:$('#ncNotes').value });
    if (r){ toast(`Call ${r.id} created`); await refreshBoard(); openCall(r.id); }
  }

  /* ============================ call record ============================ */
  async function loadCall(id){
    const d = await call('getCall', { id });
    if (!d) return false;
    S.callData = d; S.selectedCall = id;
    return true;
  }
  async function openCall(id){ if (await loadCall(id)){ S.callTab = 'notes'; show('call'); renderCall(); } }
  function renderCall(){
    const d = S.callData; if (!d) return;
    const live = d.call, c = live || d.closed;
    const mine = live && myCalls().includes(live.id);
    const us = live ? live.units : [];
    const st = live ? callStatus(live) : 'CLOSED';
    const natureOpts = [...new Set([c.nature, ...S.cfg.natures])].map(n => `<option ${n===c.nature?'selected':''}>${esc(n)}</option>`).join('');
    $('#callLeft').innerHTML = `
      <div class="callhead ${live?'':'closed'}"><h2>#${c.id} - ${esc((c.nature||'').split(' ')[0])}</h2>
        <div class="tools">${live ? `<div class="sq" title="Set GPS" data-a="gps">${svg('route')}</div><div class="sq red" title="Close call" data-a="close">${svg('trash')}</div>` : ''}</div></div>
      <div class="fields">
        ${live ? '' : `<div class="hint warn">This call is closed (${esc(d.closed.close_reason)}${d.closed.closed_by ? ' by ' + esc(d.closed.closed_by) : ''}). Read only.</div>`}
        <div class="frow"><label>Units</label><div class="uchips">${(live ? us.map(u=>u.callsign) : (d.closed.units||'').split(', ').filter(Boolean)).map(u=>`<span class="uchip">${esc(u)}</span>`).join('') || '<span class="hint">None</span>'}</div></div>
        <div class="frow"><label>Created On</label><input class="fin" value="${d24(c.createdAt).replace(' ', ' @ ')}" readonly></div>
        <div class="frow"><label>Source</label><input class="fin" value="${live ? (live.origin === 'cad' ? 'CAD (SELF-INITIATED)' : '911') : 'HISTORY'}" readonly></div>
        <div class="frow"><label>Nature</label><select class="fin" id="fNature" ${live?'':'disabled'}>${natureOpts}</select></div>
        <div class="frow"><label>Status</label><input class="fin" value="${st}" readonly></div>
        <div class="frow"><label>Priority</label><select class="fin" id="fPri" ${live?'':'disabled'}>${[1,2,3].map(p=>`<option ${p===c.priority?'selected':''}>${p}</option>`).join('')}</select></div>
        <div class="frow"><label>Address</label><input class="fin" value="${esc(live ? live.address : c.street)}" readonly></div>
        <div class="frow"><label>City</label><input class="fin" value="${esc(live ? live.city : '')}" readonly></div>
        <div class="frow"><label>County</label><input class="fin" value="${esc(live ? live.county : '')}" readonly></div>
        <div class="frow"><label>Caller</label><input class="fin" value="${esc(c.callerName)}" readonly></div>
        <div class="frow"><label>Primary Unit</label><input class="fin" value="${us[0] ? esc(us[0].callsign + ' (' + us[0].department + ')') : 'NONE'}" readonly></div>
        ${live ? `<div class="frow"><label></label><div style="display:flex;gap:6px;flex-wrap:wrap">${mine
          ? `<button class="btn" data-a="ENRT">ENRT</button><button class="btn" data-a="ARRVD">ARRVD</button><button class="btn gray" data-a="detach">Clear Self</button>`
          : `<button class="btn green" data-a="assign">Assign Self</button>`}</div></div>` : ''}
      </div>`;
    $$('#callLeft [data-a]').forEach(b => b.onclick = async () => {
      const a = b.dataset.a, id = c.id;
      if (a === 'assign'){ if (await call('assign', { id }, `Attached to call ${id}`)) refreshBoard(); }
      if (a === 'detach'){ if (await call('detach', { id }, `Cleared from call ${id}`)) refreshBoard(); }
      if (a === 'ENRT' || a === 'ARRVD') setStatus(a);
      if (a === 'gps') call('waypoint', { id }, 'Waypoint set');
      if (a === 'close') modal(`Close call ${id}?`, '<div class="hint">The call is removed for every unit and saved to Call History.</div>',
        [{ label:'Cancel', cls:'gray' }, { label:'Close Call', cls:'red', run: () => { call('closeCall', { id }, `Call ${id} closed`).then(ok => { if (ok){ S.callData = null; show('cad'); refreshBoard(); } }); } }]);
    });
    const fp = $('#fPri'), fn = $('#fNature');
    if (live){
      fp.onchange = () => call('updateCall', { id:c.id, priority:+fp.value }).then(ok => ok && refreshBoard());
      fn.onchange = () => call('updateCall', { id:c.id, nature:fn.value }).then(ok => ok && refreshBoard());
    }
    renderCallTabs();
  }
  function renderCallTabs(){
    const d = S.callData, live = d.call, c = live || d.closed;
    const TABS = [['notes','Notes'],['info','Info'],['returns','State Returns'],['history','Address History']];
    $('#callTabs').innerHTML = TABS.map(([k,l]) => `<button class="${S.callTab===k?'on':''}" data-k="${k}">${l}</button>`).join('');
    $$('#callTabs button').forEach(b => b.onclick = () => { S.callTab = b.dataset.k; renderCallTabs(); });
    const body = $('#callTabBody');
    if (S.callTab === 'notes'){
      body.innerHTML = `<div class="notes" id="notesList">${d.notes.map(n => `<div class="note ${n.system?'sys':''}"><div class="h">${d24(n.at)}${n.system && n.author === 'SYSTEM' ? '' : `<b>${esc(n.author)}</b>`}</div><div class="t">${esc(n.body)}</div></div>`).join('') || '<div class="empty">No notes yet</div>'}</div>
        ${live ? '<form class="cmt" id="cmtForm"><input class="fin" id="cmtIn" maxlength="500" placeholder="Type comment here..."><button class="btn">Add</button></form>' : ''}`;
      const nl = $('#notesList'); nl.scrollTop = nl.scrollHeight;
      const f = $('#cmtForm');
      if (f) f.onsubmit = async e => { e.preventDefault(); const v = $('#cmtIn').value.trim(); if (!v) return; if (await call('addNote', { id:c.id, body:v })) $('#cmtIn').value = ''; };
    } else if (S.callTab === 'info'){
      body.innerHTML = `<dl class="kvtab"><dt>Call#</dt><dd>${c.id}</dd><dt>Caller</dt><dd>${esc(c.callerName)}</dd><dt>Received</dt><dd>${d24(c.createdAt)}</dd><dt>Open For</dt><dd>${live ? age(c.createdAt) : 'CLOSED'}</dd><dt>Units</dt><dd>${live ? live.units.length : esc(d.closed.units || 'NONE')}</dd>${live && live.message ? `<dt>Caller Statement</dt><dd style="white-space:pre-wrap;font-weight:600">${esc(live.message)}</dd>` : ''}</dl>`;
    } else if (S.callTab === 'returns'){
      body.innerHTML = d.returns.length ? `<div class="grid" style="border-top:0"><table><thead><tr><th>Time</th><th>Subject</th><th>Result</th></tr></thead><tbody>${d.returns.map(r=>`<tr class="${r.hit?'c-offdt':'c-avail'}"><td>${t24(r.at)}</td><td>${esc(r.subject_name)}</td><td>${esc(r.result)}</td></tr>`).join('')}</tbody></table></div>`
        : '<div class="empty">No names run on this call yet. Names you run while attached are linked here.</div>';
    } else {
      body.innerHTML = d.history.length ? `<div class="grid" style="border-top:0"><table><thead><tr><th>Closed</th><th>Call#</th><th>Nature</th><th>Units</th><th>Disposition</th></tr></thead><tbody>${d.history.map(h=>`<tr class="c-avail click" data-id="${h.call_id}"><td>${d24(h.at)}</td><td>${h.call_id}</td><td>${esc(h.nature)}</td><td>${esc(h.units)}</td><td>${esc(h.close_reason)}</td></tr>`).join('')}</tbody></table></div>`
        : '<div class="empty">No earlier calls at this location.</div>';
      $$('#callTabBody tr[data-id]').forEach(r => r.onclick = () => openCall(+r.dataset.id));
    }
  }

  /* ============================ search / returns ============================ */
  $('#searchForm').onsubmit = async e => {
    e.preventDefault();
    const list = await call('searchPeople', { q:$('#sQuery').value });
    if (!list) return;
    $('#resBody').innerHTML = list.length ? list.map(p => `<tr class="click ${p.flags.includes('WANTED')?'c-offdt':p.flags.length?'c-busy':'c-avail'} ${S.person===p.id?'sel':''}" data-id="${p.id}">
      <td>${p.id}</td><td>${esc(p.last)}, ${esc(p.first)}</td><td>${esc(p.dob)}</td><td>${esc((p.gender||'')[0]||'')}</td><td>${esc(p.flags.join(' · ') || '-')}</td></tr>`).join('')
      : '<tr><td colspan="5" class="empty">NO RECORD FOUND</td></tr>';
    $$('#resBody tr[data-id]').forEach(r => r.onclick = () => runReturn(+r.dataset.id));
  };
  async function runReturn(id){
    const R = await call('runReturn', { id });
    if (!R) return;
    S.person = id; S.lastReturn = R; S.returnsCount++;
    $('#sbReturns').textContent = 'State Returns: ' + S.returnsCount;
    $$('#resBody tr').forEach(tr => tr.classList.toggle('sel', +tr.dataset.id === id));
    const p = R.person, L = R.licenses, hit = R.warrants.length > 0;
    S.subject = { id:p.id, name:`${p.first} ${p.last}`, dob:p.dob };
    const lic = l => (l.status === 'VALID' ? l.status : `<span class="r">${esc(l.status)}</span>`);
    $('#retTitle').textContent = `State Return · ${p.last.toUpperCase()}, ${p.first.toUpperCase()}`;
    $('#ret').innerHTML =
`<span class="hd">*** SAN ANDREAS CRIMINAL JUSTICE INFORMATION SYSTEM ***</span>
<span class="w">QUERY: NAME   REQ BY: ${esc(R.runBy)}   ${d24(R.runAt)}</span>

${hit ? '<span class="r">********  WARNING: SUBJECT IS WANTED  ********</span>\n' : ''}NAME .......... <span class="w">${esc(p.last.toUpperCase())}, ${esc(p.first.toUpperCase())}</span>
CHAR ID ....... ${p.id}
DOB ........... ${esc(p.dob)}   AGE ${yrs(p.dob)}
SEX ........... ${esc((p.gender||'').toUpperCase())}   HGT ${p.height}CM
NATIONALITY ... ${esc((p.nationality||'').toUpperCase())}

<span class="hd">--- LICENSES ---</span>
DRIVERS ....... ${lic(L.drivers)}   POINTS ${L.drivers.points >= R.suspendAt * 0.75 ? `<span class="r">${L.drivers.points}</span>` : L.drivers.points}/${R.suspendAt}
FIREARMS ...... ${lic(L.firearm)}
PILOT ......... ${lic(L.pilot)}

<span class="hd">--- WANTS / WARRANTS ---</span>
${R.warrants.length ? R.warrants.map(w => `<span class="r">${esc(w.number)} ${esc(w.warrantType || 'ARREST')} WARRANT · ${esc(w.charges.map(c=>c.offense+' §'+c.code).join(', ') || 'SEE WARRANT')} · APPROVED ${esc(w.reviewed_by || '-')}</span>`).join('\n') : 'NO WANTS OR WARRANTS ON FILE'}

<span class="hd">--- ALERTS ---</span>
${R.alerts.length ? R.alerts.map(a => `<span class="y">${esc(a.type)}: ${esc(a.title)}</span>`).join('\n') : 'NONE'}

<span class="hd">--- HISTORY ---</span>
CITATIONS ..... ${R.history.citation}
ARRESTS ....... ${R.history.arrest}
REPORTS ....... ${R.history.report}
${R.records.length ? '\n' + R.records.slice(0, 10).map(r => `<span class="w">${esc(r.number)}</span>  ${d24(r.at).slice(0,10)}  ${esc(r.type.toUpperCase())}  ${esc(r.summary || '')}`).join('\n') + '\n' : ''}
<span class="w">*** END OF RETURN ***</span>`;
    $('#retActs').style.display = 'flex';
  }
  $$('#retActs [data-f]').forEach(b => b.onclick = () => { S.formTab = b.dataset.f; S.charges = []; show('forms'); });
  $('#addAlertFromRet').onclick = () => alertModal(S.subject);

  async function loadReturns(){
    const rows = await call('returnsLog'); if (!rows) return;
    $('#retBody').innerHTML = rows.length ? rows.map(r => `<tr class="click ${r.hit?'c-offdt':'c-avail'}" data-id="${r.subject_char}"><td>${t24(r.at)}</td><td>${esc(r.subject_name)}</td><td>${r.subject_char}</td><td>${r.call_id || ''}</td><td>${esc(r.result)}</td></tr>`).join('')
      : '<tr><td colspan="5" class="empty">No returns in the last 12 hours</td></tr>';
    $$('#retBody tr[data-id]').forEach(r => r.onclick = () => { show('search'); runReturn(+r.dataset.id); });
  }
  async function loadHistory(){
    const rows = await call('callHistory'); if (!rows) return;
    $('#histBody').innerHTML = rows.length ? rows.map(h => `<tr class="click ${h.priority===1?'c-p1':'c-avail'}" data-id="${h.call_id}"><td>${h.call_id}</td><td>${esc(h.nature)}</td><td>${h.priority}</td><td>${esc(h.address)}</td><td>${esc(h.caller)}</td><td>${esc(h.units)}</td><td>${d24(h.createdAt)}</td><td>${d24(h.closedAt)}</td><td>${esc(h.close_reason)}${h.closed_by ? ' · ' + esc(h.closed_by) : ''}</td></tr>`).join('')
      : '<tr><td colspan="9" class="empty">No closed calls yet</td></tr>';
    $$('#histBody tr[data-id]').forEach(r => r.onclick = () => openCall(+r.dataset.id));
  }

  /* ============================ forms ============================ */
  const FORMS = { citation:'Citation', arrest:'Arrest Report', report:'Incident Report', warrant:'Warrant Request' };
  function renderForms(){
    $('#formTabs').innerHTML = Object.entries(FORMS).map(([k,l]) => `<button class="${S.formTab===k?'on':''}" data-k="${k}">${l}</button>`).join('');
    $$('#formTabs button').forEach(b => b.onclick = () => { S.formTab = b.dataset.k; S.charges = []; renderForms(); });
    const t = S.formTab;
    const subj = S.subject
      ? `<div class="subject"><b>${esc(S.subject.name.toUpperCase())}</b><span class="muted">ID ${S.subject.id} · DOB ${esc(S.subject.dob)}</span><button class="btn gray" data-go="search">Change</button></div>`
      : `<div class="subject"><span class="muted">${t === 'report' ? 'Optional. ' : ''}Run a name in Search first.</span><button class="btn gray" data-go="search">Search</button></div>`;
    const callOpts = `<option value="">NONE</option>${S.board.calls.map(c => `<option value="${c.id}" ${myCalls()[0]===c.id?'selected':''}>${c.id} - ${esc(c.nature)}</option>`).join('')}`;
    const loc = esc((meUnit().location) || '');
    const charges = `<div class="full"><label class="lbl">Charges</label><div class="charge-dd"><input class="fin" id="chargeQ" placeholder="Code, offense or abbreviation (2-01, speeding, dui)..."><div class="dd" id="chargeDD"></div></div>
      <div class="grid" style="border:1px solid var(--line-2);margin-top:6px;max-height:170px"><table><thead><tr><th>Code</th><th>Offense</th><th>Class</th><th>Points</th><th></th></tr></thead><tbody id="chargeBody"></tbody></table></div><div class="hint" id="chargeHint" style="margin-top:4px"></div></div>`;
    let body = `<div class="full"><label class="lbl">Subject</label>${subj}</div>
      <div><label class="lbl">Officer</label><input class="fin" value="${esc(S.me.short)} (${esc(S.me.callsign)}) · ${esc(S.me.dept)}" readonly></div>
      <div><label class="lbl">Linked Call</label><select class="fin" id="fCall">${callOpts}</select></div>`;
    if (t === 'citation') body += `<div><label class="lbl">Location</label><input class="fin" id="fLoc" value="${loc}"></div><div><label class="lbl">Court Date</label><input class="fin" id="fCourt" type="date"></div>${charges}
      <div class="full"><label class="lbl">Notes</label><textarea class="fin" id="fNotes" maxlength="1000" placeholder="Speed by radar, subject cooperative..."></textarea></div>
      <div class="full hint">No fines on this server. Points are added to the driver's license; ${S.cfg.suspendAt} points suspends it. Felonies must be an arrest report.</div>`;
    if (t === 'arrest') body += `<div><label class="lbl">Arrest Location</label><input class="fin" id="fLoc" value="${loc}"></div><div><label class="lbl">Booking</label><select class="fin" id="fBooking">${S.cfg.bookings.map(b=>`<option>${esc(b)}</option>`).join('')}</select></div>${charges}
      <div class="full"><label class="lbl">Narrative</label><textarea class="fin" id="fNarr" maxlength="4000" style="min-height:140px" placeholder="On the above date and time, I, ${esc(S.me.short)} (${esc(S.me.callsign)})..."></textarea></div>`;
    if (t === 'report') body += `<div><label class="lbl">Incident Type</label><select class="fin" id="fType">${S.cfg.reportTypes.map(r=>`<option>${esc(r)}</option>`).join('')}</select></div><div><label class="lbl">Location</label><input class="fin" id="fLoc" value="${loc}"></div>
      <div class="full"><label class="lbl">Involved Persons</label><input class="fin" id="fInv" maxlength="300" placeholder="Name - role (suspect, victim, witness)"></div>
      <div class="full"><label class="lbl">Narrative</label><textarea class="fin" id="fNarr" maxlength="4000" style="min-height:180px"></textarea></div>`;
    if (t === 'warrant') body += `<div><label class="lbl">Warrant Type</label><select class="fin" id="fWType">${S.cfg.warrantTypes.map(w=>`<option>${esc(w)}</option>`).join('')}</select></div><div><label class="lbl">Severity</label><select class="fin" id="fSev"><option>FELONY</option><option>MISDEMEANOR</option></select></div>${charges}
      <div class="full"><label class="lbl">Probable Cause</label><textarea class="fin" id="fNarr" maxlength="4000" style="min-height:120px" placeholder="Facts supporting this warrant..."></textarea></div>
      <div class="full hint warn">${S.cfg.warrantsNeedApproval && !S.me.supervisor ? 'A supervisor must approve this warrant before it goes active.' : 'As a supervisor, your warrant goes active right away.'}</div>`;
    $('#formBody').innerHTML = `<div class="formgrid">${body}</div><div class="actbar" style="justify-content:flex-end"><button class="btn green" id="fSubmit">${t==='warrant' && S.cfg.warrantsNeedApproval && !S.me.supervisor ? 'Submit for Approval' : 'Submit'}</button></div>`;
    $$('#formBody [data-go]').forEach(b => b.onclick = () => show(b.dataset.go));
    $('#fSubmit').onclick = submitForm;
    wireCharges();
  }
  function wireCharges(){
    const q = $('#chargeQ'); if (!q) return;
    const dd = $('#chargeDD');
    const draw = () => {
      $('#chargeBody').innerHTML = S.charges.map((l,i) => `<tr class="c-${l.class==='F'?'offdt':l.class==='M'?'enrt':'avail'}"><td>${esc(l.code)}</td><td>${esc(l.offense)}</td><td>${CLS[l.class]}</td><td>${l.points||'-'}</td><td><span class="lnk r" data-rm="${i}">Remove</span></td></tr>`).join('') || '<tr><td colspan="5" class="empty">No charges</td></tr>';
      $$('#chargeBody [data-rm]').forEach(x => x.onclick = () => { S.charges.splice(+x.dataset.rm, 1); draw(); });
      const pts = S.charges.reduce((a,l) => a + (l.points||0), 0), fel = S.charges.some(l => l.class === 'F');
      $('#chargeHint').innerHTML = S.formTab === 'citation' && fel ? '<span style="color:var(--offdt)">Felony charges cannot go on a citation. Use an arrest report.</span>' : (S.formTab === 'citation' && pts ? `Adds ${pts} license point${pts===1?'':'s'}.` : '');
    };
    const match = (l, s) => !s || l.code.includes(s) || l.offense.toLowerCase().includes(s) || (l.aliases || []).some(a => a.includes(s));
    q.oninput = q.onfocus = () => {
      const s = q.value.trim().toLowerCase();
      dd.innerHTML = S.cfg.laws.filter(l => match(l, s)).slice(0, 14).map(l => `<div data-c="${esc(l.code)}"><span>${esc(l.code)}</span><span>${esc(l.offense)}</span><span class="k-${l.class}">${CLS[l.class]}</span></div>`).join('') || '<div style="cursor:default">No match</div>';
      dd.classList.add('open');
      $$('#chargeDD [data-c]').forEach(el => el.onmousedown = e => { e.preventDefault(); const l = S.cfg.laws.find(x => x.code === el.dataset.c); if (l && !S.charges.includes(l)) S.charges.push(l); q.value = ''; dd.classList.remove('open'); draw(); });
    };
    q.onblur = () => setTimeout(() => dd.classList.remove('open'), 120);
    draw();
  }
  async function submitForm(){
    const t = S.formTab, v = id => { const el = $(id); return el ? el.value : undefined; };
    const payload = {
      type: t, subject: S.subject ? S.subject.id : null, callId: v('#fCall') ? +v('#fCall') : null,
      charges: S.charges.map(l => l.code), location: v('#fLoc'), narrative: v('#fNarr'), notes: v('#fNotes'),
      court: v('#fCourt'), booking: v('#fBooking'), incidentType: v('#fType'), involved: v('#fInv'),
      warrantType: v('#fWType'), severity: v('#fSev'),
    };
    const btn = $('#fSubmit'); btn.disabled = true;
    const r = await call('submitRecord', payload);
    btn.disabled = false;
    if (!r) return;
    toast(`${r.number} filed${r.status === 'pending' ? ' · waiting for supervisor approval' : ''}${r.note ? ' · ' + r.note : ''}`);
    S.charges = []; renderForms(); loadMyRecords();
  }
  async function loadMyRecords(){
    const rows = await call('myRecords'); if (!rows) return;
    $('#myRecBody').innerHTML = rows.length ? rows.map(r => `<tr class="click ${r.status==='pending'?'c-enrt':r.status==='denied'?'c-offdt':'c-avail'}" data-id="${r.id}"><td>${esc(r.number)}</td><td>${esc(r.type)}</td><td>${esc(r.subject_name||'-')}</td><td>${esc(r.status)}</td></tr>`).join('')
      : '<tr><td colspan="4" class="empty">Nothing filed yet</td></tr>';
    $$('#myRecBody tr[data-id]').forEach(tr => tr.onclick = () => viewRecord(+tr.dataset.id));
  }
  async function viewRecord(id){
    const r = await call('getRecord', { id }); if (!r) return;
    const d = r.data || {};
    const row = (k, v) => v ? `<div><span class="lbl">${k}</span><div style="font-weight:700;white-space:pre-wrap">${esc(v)}</div></div>` : '';
    modal(`${r.number} · ${r.type.toUpperCase()} · ${r.status.toUpperCase()}`,
      row('Subject', r.subject_name) + row('Officer', r.officer_label) + row('Filed', d24(r.at)) + row('Linked Call', r.call_id) +
      row('Charges', (d.charges || []).map(c => `§${c.code} ${c.offense} (${CLS[c.class]})`).join('\n')) +
      row('Location', d.location) + row('Court Date', d.court) + row('Booking', d.booking) + row('Type', d.incidentType || d.warrantType) +
      row('Involved', d.involved) + row(r.type === 'warrant' ? 'Probable Cause' : 'Narrative', d.narrative) + row('Notes', d.notes) + row('Reviewed By', r.reviewed_by),
      [{ label:'Close', cls:'gray' }]);
  }

  /* ============================ alerts ============================ */
  async function loadAlerts(){
    const d = await call('alerts'); if (!d) return;
    const charges = w => w.charges.map(c => `${esc(c.offense)} §${esc(c.code)}`).join(', ') || 'See probable cause';
    let html = '';
    if (d.canReview && d.pending.length){
      html += `<div class="sect" style="color:var(--enrt)">WARRANTS WAITING FOR APPROVAL (${d.pending.length})</div><table><thead><tr><th style="width:110px">Warrant</th><th>Subject / Charges</th><th>Probable Cause</th><th style="width:130px">Requested By</th><th style="width:140px">Actions</th></tr></thead><tbody>${d.pending.map(w => `
        <tr class="c-enrt"><td>${esc(w.number)}<br>${esc(w.warrantType)}</td><td class="wrap"><b>${esc(w.subject_name)}</b><br>${charges(w)}</td><td class="wrap">${esc(w.narrative || '')}</td><td>${esc(w.officer_label)}</td>
        <td><span class="lnk g" data-ap="${w.id}">Approve</span><span class="lnk r" data-dn="${w.id}">Deny</span></td></tr>`).join('')}</tbody></table>`;
    }
    html += `<div class="sect">ACTIVE WARRANTS (${d.warrants.length})</div><table><thead><tr><th style="width:150px">Subject</th><th>Warrant</th><th style="width:140px">Approved By</th><th style="width:110px">Actions</th></tr></thead><tbody>${d.warrants.map(w => `
      <tr class="c-offdt"><td class="wrap"><b>${esc(w.subject_name)}</b></td><td class="wrap"><b style="color:#fff">${esc(w.number)} · ${esc(w.warrantType)} WARRANT</b><br>${charges(w)}</td><td>${esc(w.reviewed_by || '-')}</td><td><span class="lnk" data-sv="${w.id}">Mark Served</span></td></tr>`).join('') || '<tr><td colspan="4" class="empty">No active warrants</td></tr>'}</tbody></table>`;
    html += `<div class="sect">BOLOS AND ALERTS (${d.alerts.length})</div><table><thead><tr><th style="width:150px">Type</th><th>Alert</th><th style="width:140px">Linked Civilian</th><th style="width:110px">Plate</th><th style="width:110px">Actions</th></tr></thead><tbody>${d.alerts.map(a => `
      <tr><td class="wrap"><b>${esc(a.type)}</b></td><td class="wrap"><b style="color:#fff">${esc(a.title)}</b>${a.body ? '<br><br>' + esc(a.body) : ''}<br><span class="hint">${esc(a.created_by)} · ${d24(a.at)}</span></td><td class="wrap">${esc(a.subject_name || '')}</td><td>${esc(a.plate || '')}</td><td><span class="lnk r" data-rm="${a.id}">Remove</span></td></tr>`).join('') || '<tr><td colspan="5" class="empty">No active alerts</td></tr>'}</tbody></table>`;
    $('#alertsGrid').innerHTML = html;
    $$('#alertsGrid [data-ap]').forEach(x => x.onclick = () => call('reviewWarrant', { id:+x.dataset.ap, approve:true }, 'Warrant approved'));
    $$('#alertsGrid [data-dn]').forEach(x => x.onclick = () => call('reviewWarrant', { id:+x.dataset.dn, approve:false }, 'Warrant denied'));
    $$('#alertsGrid [data-sv]').forEach(x => x.onclick = () => call('serveWarrant', { id:+x.dataset.sv }, 'Warrant marked served'));
    $$('#alertsGrid [data-rm]').forEach(x => x.onclick = () => call('removeAlert', { id:+x.dataset.rm }, 'Alert removed'));
  }
  function alertModal(subject){
    modal('Add Alert', `
      <div><label class="lbl">Type</label><select class="fin" id="aType">${S.cfg.alertTypes.map(t=>`<option>${esc(t)}</option>`).join('')}</select></div>
      <div><label class="lbl">Title</label><input class="fin" id="aTitle" maxlength="120" placeholder="e.g. Silver sedan, unknown plate"></div>
      <div><label class="lbl">Details</label><textarea class="fin" id="aBody" maxlength="1000" placeholder="Description, last seen, who to contact..."></textarea></div>
      <div><label class="lbl">Plate (optional)</label><input class="fin" id="aPlate" maxlength="12"></div>
      <div class="hint">${subject ? `Linked to ${esc(subject.name)} (ID ${subject.id}).` : 'Not linked to a person. Add it from a state return to link one.'}</div>`,
      [{ label:'Cancel', cls:'gray' }, { label:'Add Alert', cls:'red', run: () => {
        call('addAlert', { type:$('#aType').value, title:$('#aTitle').value, body:$('#aBody').value, plate:$('#aPlate').value, subject: subject ? subject.id : null }, 'Alert added')
          .then(ok => { if (ok && S.screen === 'alerts') loadAlerts(); });
      } }]);
  }
  $('#addAlert').onclick = () => alertModal(null);

  /* ============================ laws ============================ */
  function renderLaws(){
    const s = $('#lawSearch').value.trim().toLowerCase();
    $('#lawBody').innerHTML = S.cfg.laws.filter(l => !s || l.code.includes(s) || l.offense.toLowerCase().includes(s) || (l.aliases||[]).some(a => a.includes(s)))
      .map(l => `<tr class="c-${l.class==='F'?'offdt':l.class==='M'?'enrt':'avail'}"><td>§${esc(l.code)}</td><td>${esc(l.offense)}</td><td>${CLS[l.class]}</td><td>${l.points||'-'}</td><td class="wrap">${esc(l.note || '')}${(l.aliases||[]).length ? `<span class="hint"> (${esc(l.aliases.join(', '))})</span>` : ''}</td></tr>`).join('');
  }
  $('#lawSearch').oninput = renderLaws;

  /* ============================ lifecycle ============================ */
  UL.on('open', m => {
    const d = m.data;
    S.cfg = d; S.me = d.me;
    $('#brand').textContent = d.name.toUpperCase();
    $('#sbUnit').textContent = `${d.me.callsign} · ${d.me.short} · ${d.me.dept}${d.me.supervisor ? ' · SUPERVISOR' : ''}`;
    $('#tablet').classList.add('on');
    applyBoard(d.board);
    S.hist = ['cad']; S.histPos = 0;
    show('cad', false);
  });
  UL.on('close', () => { $('#tablet').classList.remove('on'); closeModal(); });
  UL.on('push', m => {
    if (!S.cfg) return;
    if (m.kind === 'board') applyBoard(m.data);
    if (m.kind === 'note' && S.callData && (S.callData.call || S.callData.closed || {}).id === m.data.callId){
      S.callData.notes.push(m.data.note);
      if (S.screen === 'call' && S.callTab === 'notes') renderCallTabs();
    }
    if (m.kind === 'callClosed' && S.callData && S.callData.call && S.callData.call.id === m.data.id){
      toast(`Call ${m.data.id} was ${m.data.reason === 'expired' ? 'expired' : 'closed'}${m.data.by ? ' by ' + m.data.by : ''}`);
      if (S.screen === 'call') loadCall(m.data.id).then(ok => ok && renderCall());
    }
    if (m.kind === 'alertsChanged' && S.screen === 'alerts') loadAlerts();
    if (m.kind === 'signal100'){ S.signal100 = m.data.on; $('#sbSignal').style.display = S.signal100 ? '' : 'none'; renderToolbar(); toast(S.signal100 ? `SIGNAL 100 set by ${m.data.by}` : `Signal 100 cleared by ${m.data.by}`, S.signal100); }
  });

  const close = () => UL.req('close');
  $('#closeBtn').onclick = close;
  document.addEventListener('keydown', e => {
    if (e.key !== 'Escape' || !$('#tablet').classList.contains('on')) return;
    if (modalOpen()) return closeModal();
    close();
  });
  setInterval(() => { const d = new Date(); $('#clock').textContent = `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`; }, 1000);
  // refresh the Age column (not every second: that would close open dropdowns)
  setInterval(() => { if (S.cfg && S.screen === 'cad' && !document.activeElement.matches('select')) renderBoard(); }, 30000);
})();
