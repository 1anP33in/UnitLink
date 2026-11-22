/* UnitLink SAFR: Fire & Rescue CAD. Same look as the police CAD.
   Everything comes from the server ('fire.*' requests + firePush). */
(() => {
  'use strict';
  const $ = s => document.querySelector(s), $$ = s => [...document.querySelectorAll(s)];
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[c]));
  const pad = n => String(n).padStart(2, '0');
  const t24 = sec => { const d = new Date(sec * 1000); return `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`; };
  const d24 = sec => { const d = new Date(sec * 1000); return `${pad(d.getMonth()+1)}/${pad(d.getDate())}/${d.getFullYear()} ${t24(sec)}`; };
  const age = sec => { const m = Math.max(0, Math.floor((Date.now()/1000 - sec) / 60)); return m < 60 ? m + 'm' : Math.floor(m/60) + 'h' + (m%60) + 'm'; };
  const yrs = dob => { const d = new Date(dob); return isNaN(d) ? '' : Math.floor((Date.now() - d) / (365.25 * 864e5)); };
  const I = {
    cad:'<rect x="3" y="4" width="18" height="12" rx="1.5"/><path d="M8 20h8M12 16v4"/>', star:'<path d="M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1L3.2 9.5l6.1-.9z"/>',
    cross:'<path d="M9 3h6v6h6v6h-6v6H9v-6H3V9h6z"/>', forms:'<path d="M6 3h9l3 3v15H6z"/><path d="M9 10h6M9 14h6M9 18h3"/>', alert:'<path d="M12 3l9 16H3z"/><path d="M12 10v4M12 17v.1"/>',
    station:'<path d="M3 21V9l9-6 9 6v12"/><path d="M9 21v-6h6v6"/>', history:'<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>', phone:'<path d="M5 4h4l2 5-2.5 1.5a11 11 0 005 5L15 13l5 2v4a2 2 0 01-2 2A16 16 0 013 6a2 2 0 012-2"/>',
    mega:'<path d="M3 10v4h3l7 4V6L6 10z"/><path d="M17 9a4 4 0 010 6"/>', bell:'<path d="M6 16v-5a6 6 0 0112 0v5l1.5 2h-15z"/><path d="M10 20a2 2 0 004 0"/>',
    route:'<circle cx="6" cy="18" r="2"/><circle cx="18" cy="6" r="2"/><path d="M8 18h7a3 3 0 000-6H9a3 3 0 010-6h7"/>', trash:'<path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/>',
    search:'<circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/>',
  };
  const svg = (n, c) => `<svg viewBox="0 0 24 24" ${c ? `style="--ic:${c}"` : ''}>${I[n]}</svg>`;
  const SEV = { MINOR: 'avail', MODERATE: 'enrt', SERIOUS: 'busy', CRITICAL: 'offdt', DECEASED: 'dim' };

  const S = { cfg: null, me: null, board: { incidents: [], units: [], apparatus: [] }, screen: 'cad', sel: null, open: null, data: null, tab: 'notes',
    formKey: null, formPrefill: {}, sub: 'roster', patient: null, q: '', uq: '', typeFilter: '' };

  /* ---------------- helpers ---------------- */
  let toastTimer;
  const toast = (msg, err) => { const t = $('#fToast'); t.textContent = msg; t.className = 'toast on' + (err ? ' err' : ''); clearTimeout(toastTimer); toastTimer = setTimeout(() => t.className = 'toast', 2800); };
  async function call(action, payload, okMsg) {
    const r = await UL.req(action, payload);
    if (!r || !r.ok) { toast((r && r.data) || 'Request failed.', true); return null; }
    if (okMsg) toast(okMsg);
    return r.data === undefined ? true : r.data;
  }
  const stCfg = code => (S.cfg.statuses.find(s => s.code === code) || { color: 'dim', label: code });
  const stCls = code => 'c-' + stCfg(code).color;
  const myUnit = () => S.board.units.find(u => u.source === S.me.src) || null;
  const myIncidents = () => (myUnit() || { incidents: [] }).incidents;
  const findInc = id => S.board.incidents.find(i => i.id === id);
  const incStatus = i => !i.units.length ? 'PENDING' : i.units.some(u => ['ONSCN', 'TRANS', 'ATHSP'].includes(u.status)) ? 'ON SCENE' : 'DISPATCHED';
  const priOpts = sel => [1, 2, 3].map(p => `<option value="${p}" ${p === sel ? 'selected' : ''}>${p}</option>`).join('');

  /* ---------------- modal ---------------- */
  function modal(title, body, buttons, wide) {
    $('#fmTitle').textContent = title; $('#fmBody').innerHTML = body;
    $('#fModal .mbox').style.width = wide ? '640px' : '';
    $('#fmFoot').innerHTML = buttons.map((b, i) => `<button class="btn ${b.cls || ''}" data-i="${i}">${b.label}</button>`).join('');
    $$('#fmFoot button').forEach(el => el.onclick = async () => { const b = buttons[+el.dataset.i]; if (!b.run || (await b.run()) !== false) closeModal(); });
    $('#fModal').classList.add('on');
    const first = $('#fmBody input, #fmBody select, #fmBody textarea'); if (first) first.focus();
  }
  const closeModal = () => $('#fModal').classList.remove('on');

  /* ---------------- chrome ---------------- */
  const TILES = [
    ['cad', 'CAD', '#fff', 'cad'], ['mycall', 'My Incident', '#cbd5e1', 'star'], ['patients', 'Patients', '#ff8a8a', 'cross'], ['forms', 'Reports', '#fff', 'forms'],
    ['alerts', 'Alerts', '#ff6b6b', 'alert'], ['mgmt', 'Station Mgmt', '#9cc3ff', 'station'], ['history', 'History', '#9cc3ff', 'history'], ['|'],
    ['newcall', 'New Incident', '#3ee06a', 'phone'], ['assign', 'Assign Self', '#3ee06a', 'phone'], ['|'], ['announce', 'Announce', '#ffd257', 'mega'], ['mayday', 'Mayday', '#ff6b6b', 'bell'],
  ];
  function tileOff(t) {
    if (t === 'mycall') return !myIncidents().length;
    if (t === 'assign') return !S.sel || !findInc(S.sel) || myIncidents().includes(S.sel);
    if (t === 'announce') return !S.me.supervisor;
    return false;
  }
  function chrome() {
    $('#fToolbar').innerHTML = TILES.map(t => t[0] === '|' ? '<div class="gap"></div>' :
      `<div class="tile ${t[0] === 'mayday' ? 'panic' + (S.board.mayday ? ' blinking' : '') : ''} ${tileOff(t[0]) ? 'off' : ''} ${t[0] === S.screen || (S.screen === 'call' && t[0] === 'mycall' && myIncidents().includes(S.open)) ? 'on' : ''}" data-t="${t[0]}"${t[0] === 'announce' && !S.me.supervisor ? ' title="Supervisors only"' : ''}>${svg(t[3], t[2])}${t[1]}</div>`).join('') +
      '<div class="seal"><div>SAFR</div></div>';
    $$('#fToolbar .tile').forEach(el => el.onclick = () => !el.classList.contains('off') && action(el.dataset.t));
    const u = myUnit();
    $('#fsStatus').innerHTML = S.cfg.statuses.map(s => `<option value="${s.code}" ${u && s.code === u.status ? 'selected' : ''}>${s.code}</option>`).join('');
    $('#fsApp').innerHTML = '<option value="">NONE</option>' + S.board.apparatus.map(a => `<option value="${esc(a.id)}" ${u && a.id === u.apparatus ? 'selected' : ''} ${a.oos ? 'disabled' : ''}>${esc(a.id)}${a.oos ? ' (OOS)' : ''}</option>`).join('');
    $('#fsCall').textContent = myIncidents().length ? `Active Incident: ${myIncidents().join(', ')}` : 'No Active Incident';
    $('#fsUnit').textContent = `${S.me.callsign} · ${S.me.short} · ${S.me.dept}${S.me.supervisor ? ' · SUPERVISOR' : ''}`;
    $('#fsMayday').style.display = S.board.mayday ? '' : 'none';
    if (S.board.mayday) $('#fsMayday').textContent = `MAYDAY · ${S.board.mayday.unit}`;
  }
  const TITLES = { cad: 'SAFR · CAD', patients: 'SAFR · Patients', forms: 'SAFR · Reports', alerts: 'SAFR · Alerts', mgmt: 'SAFR · Station Management', history: 'SAFR · Incident History' };
  function show(screen) {
    S.screen = screen;
    const sc = $('#fScreen'); sc.className = 'fscreen ' + screen;
    const c = S.data && (S.data.incident || S.data.closed);
    $('#fTitle').textContent = screen === 'call' && c ? `#${c.id} - ${c.nature}` : TITLES[screen];
    ({ cad: renderBoard, call: renderCall, patients: renderPatients, forms: renderForms, alerts: renderAlerts, mgmt: renderMgmt, history: renderHistory })[screen](sc);
    chrome();
  }
  async function action(t) {
    if (t === 'mycall') return openIncident(myIncidents()[0]);
    if (t === 'newcall') return newIncidentModal();
    if (t === 'assign') { if (await call('fire.assign', { id: S.sel }, `Attached to #${S.sel}`)) refresh(); return; }
    if (t === 'announce') return announceModal();
    if (t === 'mayday') return maydayModal();
    show(t);
  }
  async function refresh() { const b = await call('fire.board'); if (b) applyBoard(b); }
  function applyBoard(b) {
    S.board = b;
    if (S.screen === 'cad') renderBoard($('#fScreen'));
    if (S.screen === 'call' && S.data && S.data.incident) {
      const live = findInc(S.data.incident.id);
      if (live) { S.data.incident = live; renderCall($('#fScreen')); } else loadIncident(S.data.incident.id).then(ok => ok && renderCall($('#fScreen')));
    }
    if (S.screen === 'alerts') renderAlerts($('#fScreen'));
    chrome();
  }
  async function setStatus(code) { await call('fire.setStatus', { code }); refresh(); }
  $('#fsStatus').onchange = e => setStatus(e.target.value);
  $('#fsApp').onchange = async e => { await call('fire.setApparatus', { id: e.target.value }, e.target.value ? `Riding on ${e.target.value}` : 'No apparatus'); refresh(); };

  /* ---------------- board ---------------- */
  function renderBoard(sc) {
    const q = S.q.toLowerCase();
    const list = S.board.incidents.filter(i => (!q || JSON.stringify(i).toLowerCase().includes(q)) && (!S.typeFilter || i.type === S.typeFilter));
    const rows = list.map(i => {
      const st = incStatus(i), cls = i.priority === 1 ? 'c-p1' : st === 'PENDING' ? 'c-pend' : 'c-avail';
      return `<tr class="click ${cls} ${i.id === S.sel ? 'sel' : ''}" data-id="${i.id}"><td>${i.id}</td><td>${esc(i.type)}</td><td>${esc(i.nature)}</td><td>${esc(i.address)}</td><td>${esc(i.city)}</td><td>${i.priority}</td><td>${st}</td><td>${i.units.map(u => esc(u.callsign)).join(', ')}</td><td>${i.patients || '-'}</td><td>${age(i.createdAt)}</td></tr>`;
    }).join('') || '<tr><td colspan="10" class="empty">No active incidents</td></tr>';
    const uq = S.uq.toLowerCase();
    const urows = S.board.units.filter(u => !uq || JSON.stringify(u).toLowerCase().includes(uq)).map(u => {
      const mine = u.source === S.me.src;
      const status = mine ? `<select class="cellsel" id="fMyStatus">${S.cfg.statuses.map(s => `<option ${s.code === u.status ? 'selected' : ''}>${s.code}</option>`).join('')}</select>` : u.status;
      return `<tr class="${stCls(u.status)} ${mine ? 'sel' : ''}"><td>${esc(u.callsign)}</td><td>${esc(u.name)}</td><td>${esc(u.apparatus || '-')}</td><td>${esc(u.station || '-')}</td><td>${status}</td><td>${u.incidents.join(', ')}</td><td>${esc(u.location || '')}</td></tr>`;
    }).join('') || '<tr><td colspan="7" class="empty">No SAFR units on duty</td></tr>';
    const count = t => S.board.incidents.filter(i => i.type === t).length;
    sc.innerHTML = `${S.board.mayday ? `<div class="mayday">MAYDAY · ${esc(S.board.mayday.unit)} · ${esc(S.board.mayday.location)} · ${t24(S.board.mayday.at)}${S.board.mayday.detail ? ' · ' + esc(S.board.mayday.detail) : ''}</div>` : ''}
      <div class="panel fcalls"><div class="phead"><h2>Active Incidents</h2>
        <div class="chips"><span class="chip ${!S.typeFilter ? 'on' : ''}" data-f="">All <b>${S.board.incidents.length}</b></span>${S.cfg.typeOrder.map(t => `<span class="chip ${S.typeFilter === t ? 'on' : ''}" data-f="${t}">${t} <b>${count(t)}</b></span>`).join('')}</div>
        <div class="tools"><div class="pill">${svg('search')}<input id="fCallQ" placeholder="Search..." value="${esc(S.q)}"></div><button class="plus" id="fPlus" title="New incident">+</button></div></div>
        <div class="grid"><table><thead><tr><th>Inc#</th><th>Type</th><th>Nature</th><th>Location</th><th>City</th><th>Pr.</th><th>Status</th><th>Units</th><th>Pts</th><th>Age</th></tr></thead><tbody>${rows}</tbody></table></div></div>
      <div class="panel funits"><div class="phead"><h2>SAFR Units</h2><span class="sub">${S.board.units.filter(u => u.status === 'AVAIL').length} available of ${S.board.units.length}</span><div class="tools"><div class="pill">${svg('search')}<input id="fUnitQ" placeholder="Search..." value="${esc(S.uq)}"></div></div></div>
        <div class="grid"><table><thead><tr><th>Unit</th><th>Name</th><th>Apparatus</th><th>Station</th><th>Status</th><th>Inc#</th><th>Location</th></tr></thead><tbody>${urows}</tbody></table></div></div>`;
    $$('#fScreen tr[data-id]').forEach(r => { r.onclick = () => { S.sel = +r.dataset.id; renderBoard(sc); chrome(); }; r.ondblclick = () => openIncident(+r.dataset.id); });
    $$('#fScreen [data-f]').forEach(c => c.onclick = () => { S.typeFilter = c.dataset.f; renderBoard(sc); });
    const keep = (id, key) => { const i = $('#' + id); i.oninput = () => { S[key] = i.value; const p = i.selectionStart; renderBoard(sc); const n = $('#' + id); n.focus(); n.setSelectionRange(p, p); }; };
    keep('fCallQ', 'q'); keep('fUnitQ', 'uq');
    $('#fPlus').onclick = () => newIncidentModal();
    const ms = $('#fMyStatus'); if (ms) ms.onchange = () => setStatus(ms.value);
  }

  /* ---------------- incident record ---------------- */
  async function loadIncident(id) { const d = await call('fire.get', { id }); if (!d) return false; S.data = d; S.sel = id; return true; }
  async function openIncident(id) { if (await loadIncident(id)) { S.open = id; S.tab = 'notes'; show('call'); } }
  function renderCall(sc) {
    const d = S.data; if (!d) return;
    const live = d.incident, c = live || d.closed;
    const mine = live && myIncidents().includes(live.id);
    const ro = live ? '' : 'disabled';
    const chips = (live ? live.units.map(u => `<span class="uchip ${stCls(u.status)}">${esc(u.callsign)} · ${u.status}</span>`) : (c.units || '').split(', ').filter(Boolean).map(u => `<span class="uchip">${esc(u)}</span>`)).join('') || '<span class="hint">None</span>';
    const crew = live ? live.units.map(u => `${esc(u.name)} (${esc(u.callsign)}${u.apparatus ? ' · ' + esc(u.apparatus) : ''})`).join(', ') : '';
    const natures = [...new Set([c.nature, ...(S.cfg.types[c.type] || [])])];
    sc.innerHTML = `<div class="panel left"><div class="callhead ${live ? '' : 'closed'}"><h2>#${c.id} - ${esc(c.type)}</h2>
        <div class="tools">${live ? `<div class="sq" title="Set GPS" data-a="gps">${svg('route')}</div><div class="sq red" title="Close incident" data-a="close">${svg('trash')}</div>` : ''}</div></div>
      <div class="fields">${live ? '' : `<div class="hint warn">Closed (${esc(c.disposition || 'closed')}${c.closed_by ? ' by ' + esc(c.closed_by) : ''}). Read only.</div>`}
        <div class="frow"><label>Units</label><div class="uchips">${chips}</div></div>
        <div class="frow"><label>Created On</label><input class="fin" value="${d24(c.createdAt).replace(' ', ' @ ')}" readonly></div>
        <div class="frow"><label>Source</label><input class="fin" value="${c.origin === 'cad' ? 'CAD (SELF-INITIATED)' : '911'}" readonly></div>
        <div class="frow"><label>Call Type</label><select class="fin" id="fType" ${ro}>${S.cfg.typeOrder.map(t => `<option ${t === c.type ? 'selected' : ''}>${t}</option>`).join('')}</select></div>
        <div class="frow"><label>Nature</label><select class="fin" id="fNature" ${ro}>${natures.map(n => `<option ${n === c.nature ? 'selected' : ''}>${esc(n)}</option>`).join('')}</select></div>
        <div class="frow"><label>Status</label><input class="fin" value="${live ? incStatus(live) : 'CLOSED'}" readonly></div>
        <div class="frow"><label>Priority</label><select class="fin" id="fPri" ${ro}>${priOpts(c.priority)}</select></div>
        <div class="frow"><label>Address</label><input class="fin" value="${esc(live ? live.address : (c.street || ''))}" readonly></div>
        <div class="frow"><label>City</label><input class="fin" value="${esc(live ? live.city : '')}" readonly></div>
        <div class="frow"><label>Caller</label><input class="fin" value="${esc(c.caller || '')}${c.callback ? ' · ' + esc(c.callback) : ''}" readonly></div>
        <div class="frow"><label>Patient Count</label><input class="fin" type="number" min="0" max="50" id="fPts" value="${c.patients || 0}" ${ro}></div>
        ${live ? `<div class="frow"><label>Personnel</label><input class="fin" value="${crew || 'NONE'}" readonly></div>
        <div class="frow"><label></label><div style="display:flex;gap:6px;flex-wrap:wrap">${mine
          ? `${S.cfg.statuses.filter(s => s.onCall).map(s => `<button class="btn" data-st="${s.code}">${s.code}</button>`).join('')}<button class="btn gray" data-a="detach">Clear Self</button>`
          : '<button class="btn green" data-a="assign">Assign Self</button>'}</div></div>` : ''}</div></div>
      <div class="panel right"><div class="tabs" id="fTabs"></div><div class="tabbody" id="fTabBody"></div></div>`;
    $$('#fScreen [data-a]').forEach(b => b.onclick = async () => {
      const a = b.dataset.a, id = c.id;
      if (a === 'assign') { if (await call('fire.assign', { id }, `Attached to #${id}`)) refresh(); }
      if (a === 'detach') { if (await call('fire.detach', { id }, `Cleared from #${id}`)) refresh(); }
      if (a === 'gps') call('fire.waypoint', { id }, 'Waypoint set');
      if (a === 'close') closeModalFor(id);
    });
    $$('#fScreen [data-st]').forEach(b => b.onclick = () => setStatus(b.dataset.st));
    if (live) {
      const upd = (id, field, conv) => { const el = $(id); el.onchange = async () => { if (await call('fire.update', { id: c.id, [field]: conv(el.value) })) { await loadIncident(c.id); refresh(); } }; };
      upd('#fType', 'type', v => v); upd('#fNature', 'nature', v => v); upd('#fPri', 'priority', v => +v); upd('#fPts', 'patients', v => +v);
    }
    renderTabs();
  }
  function closeModalFor(id) {
    modal(`Close incident #${id}?`, `<div><label class="lbl">Disposition</label><select class="fin" id="fDispo">${S.cfg.dispositions.map(d => `<option>${esc(d)}</option>`).join('')}</select></div>
      <div class="hint">It's removed for every unit and saved to History.</div>`,
      [{ label: 'Cancel', cls: 'gray' }, { label: 'Close Incident', cls: 'red', run: async () => { if (await call('fire.close', { id, disposition: $('#fDispo').value }, `Incident #${id} closed`)) { S.data = null; show('cad'); refresh(); } } }]);
  }
  function renderTabs() {
    const d = S.data, live = d.incident, c = live || d.closed;
    const TABS = [['notes', 'Notes'], ['patients', `Patients (${d.patients.length})`], ['info', 'Info'], ['history', 'Nearby History']];
    $('#fTabs').innerHTML = TABS.map(([k, l]) => `<button class="${S.tab === k ? 'on' : ''}" data-k="${k}">${l}</button>`).join('');
    $$('#fTabs button').forEach(b => b.onclick = () => { S.tab = b.dataset.k; renderTabs(); });
    const body = $('#fTabBody');
    if (S.tab === 'notes') {
      body.innerHTML = `<div class="notes" id="fNotes">${d.notes.map(n => `<div class="note ${n.system ? 'sys' : ''} ${/MAYDAY/.test(n.body) ? 'md' : ''}"><div class="h">${d24(n.at)}${n.author === 'SYSTEM' ? '' : `<b>${esc(n.author)}</b>`}</div><div class="t">${esc(n.body)}</div></div>`).join('') || '<div class="empty">No notes yet</div>'}</div>
        ${live ? '<form class="cmt" id="fCmt"><input class="fin" id="fCmtIn" maxlength="500" placeholder="Type comment here..."><button class="btn">Add</button></form>' : ''}`;
      const nl = $('#fNotes'); nl.scrollTop = nl.scrollHeight;
      const f = $('#fCmt'); if (f) f.onsubmit = async e => { e.preventDefault(); const v = $('#fCmtIn').value.trim(); if (!v) return; if (await call('fire.note', { id: c.id, body: v })) $('#fCmtIn').value = ''; };
    } else if (S.tab === 'patients') {
      body.innerHTML = `<div class="grid" style="border-top:0"><table><thead><tr><th>Patient</th><th>Severity</th><th>Injury</th><th>Treatment</th><th>Destination</th><th>Condition</th><th>By</th></tr></thead><tbody>${d.patients.map(p =>
        `<tr class="${p.subject_char ? 'click' : ''} c-${SEV[p.severity] || 'dim'}" data-pt="${p.subject_char || ''}"><td>${esc(p.name)}</td><td>${p.severity}</td><td class="wrap">${esc(p.injury)}</td><td class="wrap">${esc(p.treatment || '')}</td><td>${esc(p.destination || '')}</td><td>${esc(p.cond || '')}</td><td>${esc(p.created_by)}</td></tr>`).join('') || '<tr><td colspan="7" class="empty">No patients recorded</td></tr>'}</tbody></table></div>
        ${live ? '<div class="actbar"><button class="btn green" id="fAddPt">+ Add Patient</button><button class="btn gray" id="fPcr">Write Patient Care Report</button></div>' : ''}`;
      const a = $('#fAddPt'); if (a) a.onclick = () => patientModal(c.id);
      const p = $('#fPcr'); if (p) p.onclick = () => { S.formKey = 'pcr'; S.formPrefill = { incident: c.id }; show('forms'); };
      $$('#fTabBody [data-pt]').forEach(r => r.onclick = () => { if (r.dataset.pt) { S.patient = +r.dataset.pt; show('patients'); } });
    } else if (S.tab === 'info') {
      body.innerHTML = `<dl class="kvtab"><dt>Incident</dt><dd>#${c.id}</dd><dt>Caller</dt><dd>${esc(c.caller || '')}</dd><dt>Callback</dt><dd>${esc(c.callback || '')}</dd><dt>Received</dt><dd>${d24(c.createdAt)}</dd><dt>Open For</dt><dd>${live ? age(c.createdAt) : 'CLOSED'}</dd>${c.message ? `<dt>Caller Statement</dt><dd style="white-space:pre-wrap;font-weight:600">${esc(c.message)}</dd>` : ''}${!live ? `<dt>Closed</dt><dd>${d24(c.closedAt)} · ${esc(c.closed_by || '')}</dd>` : ''}</dl>`;
    } else {
      body.innerHTML = d.history.length ? `<div class="grid" style="border-top:0"><table><thead><tr><th>Closed</th><th>Inc#</th><th>Nature</th><th>Units</th><th>Disposition</th></tr></thead><tbody>${d.history.map(h => `<tr class="click c-avail" data-id="${h.id}"><td>${d24(h.at)}</td><td>${h.id}</td><td>${esc(h.type)} · ${esc(h.nature)}</td><td>${esc(h.units || '')}</td><td>${esc(h.disposition || '')}</td></tr>`).join('')}</tbody></table></div>`
        : '<div class="empty">No earlier incidents at this location.</div>';
      $$('#fTabBody tr[data-id]').forEach(r => r.onclick = () => openIncident(+r.dataset.id));
    }
  }

  /* ---------------- people picker (search civilians) ---------------- */
  function personPicker(idPrefix, label, required) {
    return `<div><label class="lbl">${label}${required ? ' *' : ''}</label><div style="display:flex;gap:6px"><input class="fin" id="${idPrefix}Q" placeholder="Name or ID"><button class="btn gray" type="button" id="${idPrefix}Go">Search</button></div>
      <select class="fin" id="${idPrefix}" style="margin-top:4px"><option value="">${required ? 'Search, then pick...' : 'UNKNOWN / NONE'}</option></select></div>`;
  }
  function wirePicker(idPrefix, preset) {
    const go = async () => {
      const list = await call('fire.searchPeople', { q: $('#' + idPrefix + 'Q').value }); if (!list) return;
      const sel = $('#' + idPrefix);
      sel.innerHTML = `<option value="">${list.length ? 'Pick a person...' : 'NO MATCHES'}</option>` + list.map(p => `<option value="${p.id}">${esc(p.last)}, ${esc(p.first)} · ID ${p.id} · DOB ${esc(p.dob)}</option>`).join('');
      if (list.length === 1) sel.value = list[0].id;
    };
    $('#' + idPrefix + 'Go').onclick = go;
    $('#' + idPrefix + 'Q').onkeydown = e => { if (e.key === 'Enter') { e.preventDefault(); go(); } };
    if (preset) { $('#' + idPrefix).innerHTML = `<option value="${preset.id}">${esc(preset.label)}</option><option value="">UNKNOWN / NONE</option>`; }
  }

  function patientModal(id) {
    modal(`Add patient · #${id}`, `${personPicker('fPtWho', 'Patient (leave empty if unidentified)')}
      <div><label class="lbl">Injury / Illness</label><input class="fin" id="fPtInj" maxlength="200"></div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px"><div><label class="lbl">Severity</label><select class="fin" id="fPtSev">${S.cfg.severities.map(s => `<option>${s}</option>`).join('')}</select></div>
      <div><label class="lbl">Condition</label><select class="fin" id="fPtCon">${S.cfg.conditions.map(s => `<option>${s}</option>`).join('')}</select></div></div>
      <div><label class="lbl">Treatment Provided</label><textarea class="fin" id="fPtTx" maxlength="500" style="min-height:60px"></textarea></div>
      <div><label class="lbl">Transport Destination</label><select class="fin" id="fPtDest">${S.cfg.hospitals.concat(['REFUSED TRANSPORT', 'NOT TRANSPORTED']).map(h => `<option>${h}</option>`).join('')}</select></div>`,
      [{ label: 'Cancel', cls: 'gray' }, { label: 'Add Patient', cls: 'green', run: async () => {
        const r = await call('fire.addPatient', { id, subject: $('#fPtWho').value ? +$('#fPtWho').value : null, injury: $('#fPtInj').value, severity: $('#fPtSev').value,
          condition: $('#fPtCon').value, treatment: $('#fPtTx').value, destination: $('#fPtDest').value }, 'Patient added');
        if (!r) return false;
        await loadIncident(id); S.tab = 'patients'; renderCall($('#fScreen'));
      } }], true);
    wirePicker('fPtWho');
  }

  /* ---------------- new incident / announce / mayday ---------------- */
  function newIncidentModal() {
    modal('New Incident (self-initiated)', `<div><label class="lbl">Call Type</label><select class="fin" id="fNcType">${S.cfg.typeOrder.map(t => `<option>${t}</option>`).join('')}</select></div>
      <div><label class="lbl">Nature</label><select class="fin" id="fNcNature"></select></div>
      <div><label class="lbl">Priority</label><select class="fin" id="fNcPri">${priOpts(2)}</select></div>
      <div><label class="lbl">Notes</label><textarea class="fin" id="fNcNotes" maxlength="500" placeholder="What you see, patients, hazards..."></textarea></div>
      <label class="xcheck"><input type="checkbox" id="fNcSelf" checked> Attach me (${esc(S.me.callsign)})</label>
      <div class="hint">Created at your current location.</div>`,
      [{ label: 'Cancel', cls: 'gray' }, { label: 'Create Incident', cls: 'green', run: async () => {
        const r = await call('fire.create', { type: $('#fNcType').value, nature: $('#fNcNature').value, priority: +$('#fNcPri').value, notes: $('#fNcNotes').value, attach: $('#fNcSelf').checked });
        if (!r) return false;
        toast(`Incident #${r.id} created`); await refresh(); openIncident(r.id);
      } }]);
    const fill = () => { $('#fNcNature').innerHTML = (S.cfg.types[$('#fNcType').value] || []).map(n => `<option>${esc(n)}</option>`).join(''); };
    $('#fNcType').onchange = fill; fill();
  }
  function announceModal() {
    modal('Station-wide Announcement', `<div><label class="lbl">Title</label><input class="fin" id="fAnT" maxlength="80"></div><div><label class="lbl">Message</label><textarea class="fin" id="fAnB" maxlength="600"></textarea></div><div class="hint">Goes to every on-duty SAFR unit.</div>`,
      [{ label: 'Cancel', cls: 'gray' }, { label: 'Send', run: async () => { if (!(await call('fire.announce', { title: $('#fAnT').value, body: $('#fAnB').value }, 'Announcement sent'))) return false; if (S.screen === 'alerts') renderAlerts($('#fScreen')); } }]);
  }
  function maydayModal() {
    const m = S.board.mayday;
    if (m) return modal('Clear MAYDAY?', `<div class="hint warn">MAYDAY from ${esc(m.unit)} at ${esc(m.location)} (${t24(m.at)}).</div><div class="hint">Only clear it once the firefighter is accounted for (PAR). The unit that called it or a supervisor can clear it.</div>`,
      [{ label: 'Cancel', cls: 'gray' }, { label: 'Clear MAYDAY · PAR', cls: 'green', run: async () => { if (!(await call('fire.maydayClear', {}, 'MAYDAY cleared'))) return false; refresh(); } }]);
    modal('Declare MAYDAY', `<div class="hint warn" style="font-size:13px">Firefighter down, lost, trapped or out of air. Every on-duty unit is alerted with your location.</div><div><label class="lbl">Situation (LUNAR)</label><input class="fin" id="fMd" maxlength="200" placeholder="Location, Unit, Name, Assignment, Resources needed"></div>`,
      [{ label: 'Cancel', cls: 'gray' }, { label: 'MAYDAY', cls: 'red', run: async () => { if (!(await call('fire.mayday', { detail: $('#fMd').value }))) return false; refresh(); } }]);
  }

  /* ---------------- patients ---------------- */
  async function renderPatients(sc) {
    sc.innerHTML = `<div class="panel left" style="flex:0 0 420px"><div class="phead"><h2>Patient Records</h2><span class="sub">Civilian medical history</span></div>
        <form class="sform" id="fPtForm"><input class="fin" id="fPtQ" placeholder="Name or ID" value="${esc(S.pq || '')}"><button class="btn">Search</button></form>
        <div class="grid" style="border-top:0"><table><thead><tr><th>ID</th><th>Name</th><th>DOB</th><th>Visits</th></tr></thead><tbody id="fPtRes"><tr><td colspan="4" class="empty">Search by name or ID.</td></tr></tbody></table></div></div>
      <div class="panel right" id="fPtRight"><div class="empty">Loading...</div></div>`;
    $('#fPtForm').onsubmit = async e => {
      e.preventDefault(); S.pq = $('#fPtQ').value;
      const list = await call('fire.searchPeople', { q: S.pq }); if (!list) return;
      $('#fPtRes').innerHTML = list.map(p => `<tr class="click c-avail ${p.id === S.patient ? 'sel' : ''}" data-id="${p.id}"><td>${p.id}</td><td>${esc(p.last)}, ${esc(p.first)}</td><td>${esc(p.dob)}</td><td>${p.visits}</td></tr>`).join('') || '<tr><td colspan="4" class="empty">NO RECORD FOUND</td></tr>';
      $$('#fPtRes tr[data-id]').forEach(r => r.onclick = () => { S.patient = +r.dataset.id; patientRight(); });
    };
    patientRight();
  }
  async function patientRight() {
    const el = $('#fPtRight'); if (!el) return;
    if (!S.patient) {
      const rows = await call('fire.recentPatients'); if (!rows) return;
      el.innerHTML = `<div class="phead"><h2>Recent Patients</h2><span class="sub">Pick a person to see their history</span></div><div class="grid"><table><thead><tr><th>Time</th><th>Patient</th><th>Inc#</th><th>Severity</th><th>Destination</th><th>By</th></tr></thead><tbody>${rows.map(h =>
        `<tr class="${h.subject_char ? 'click' : ''} c-${SEV[h.severity] || 'dim'}" data-id="${h.subject_char || ''}"><td>${d24(h.at)}</td><td>${esc(h.name)}</td><td>${h.incident_id}</td><td>${h.severity}</td><td>${esc(h.destination || '')}</td><td>${esc(h.created_by)}</td></tr>`).join('') || '<tr><td colspan="6" class="empty">No patients yet</td></tr>'}</tbody></table></div>`;
      $$('#fPtRight tr[data-id]').forEach(r => r.onclick = () => { if (r.dataset.id) { S.patient = +r.dataset.id; patientRight(); } });
      return;
    }
    const d = await call('fire.patientHistory', { id: S.patient }); if (!d) return;
    const p = d.person;
    el.innerHTML = `<div class="phead"><h2>${esc(p.last.toUpperCase())}, ${esc(p.first.toUpperCase())}</h2><span class="sub">ID ${p.id} · DOB ${esc(p.dob)} (${yrs(p.dob)}) · ${esc(p.gender)} · ${p.height} cm · ${esc(p.nationality)}</span><div class="tools"><button class="btn gray" id="fPtBack">Recent</button></div></div>
      <div class="sect">MEDICAL HISTORY (${d.visits.length})</div><div class="grid" style="border-top:0"><table><thead><tr><th>Date</th><th>Inc#</th><th>Incident</th><th>Injury</th><th>Severity</th><th>Treatment</th><th>Destination</th><th>Condition</th></tr></thead><tbody>${d.visits.map(v =>
        `<tr class="click c-${SEV[v.severity] || 'dim'}" data-inc="${v.incident_id}"><td>${d24(v.at)}</td><td>${v.incident_id}</td><td>${esc(v.nature || '')}</td><td class="wrap">${esc(v.injury)}</td><td>${v.severity}</td><td class="wrap">${esc(v.treatment || '')}</td><td>${esc(v.destination || '')}</td><td>${esc(v.cond || '')}</td></tr>`).join('') || '<tr><td colspan="8" class="empty">No medical history</td></tr>'}</tbody></table></div>
      <div class="actbar"><button class="btn" id="fPtPcr">Write Patient Care Report</button><button class="btn gray" id="fPtTr">Hospital Transport Report</button></div>`;
    $('#fPtBack').onclick = () => { S.patient = null; patientRight(); };
    $$('#fPtRight tr[data-inc]').forEach(r => r.onclick = () => openIncident(+r.dataset.inc));
    const go = key => () => { S.formKey = key; S.formPrefill = { person: { id: p.id, label: `${p.last}, ${p.first} · ID ${p.id}` } }; show('forms'); };
    $('#fPtPcr').onclick = go('pcr'); $('#fPtTr').onclick = go('transport');
  }

  /* ---------------- reports ---------------- */
  let historyCache = [];
  async function renderForms(sc) {
    const forms = S.cfg.forms;
    if (!S.formKey || !forms.some(f => f.key === S.formKey)) S.formKey = forms[0].key;
    const F = forms.find(f => f.key === S.formKey);
    const pre = S.formPrefill || {};
    const incOpts = sel => `<option value="">NONE</option>${S.board.incidents.map(i => `<option value="${i.id}" ${i.id === sel ? 'selected' : ''}>#${i.id} - ${esc(i.nature)}</option>`).join('')}${historyCache.map(h => `<option value="${h.id}" ${h.id === sel ? 'selected' : ''}>#${h.id} - ${esc(h.nature)} (closed)</option>`).join('')}`;
    const field = f => {
      const id = 'fF_' + f.key, full = f.type === 'narr' || f.type === 'area';
      if (f.type === 'person') return `<div class="${full ? 'full' : ''}">${personPicker(id, f.label, f.required)}</div>`;
      let h;
      if (f.type === 'list') h = `<select class="fin" id="${id}"><option value="">${f.required ? 'Select...' : '-'}</option>${f.options.map(o => `<option>${esc(o)}</option>`).join('')}</select>`;
      else if (f.type === 'incident') h = `<select class="fin" id="${id}">${incOpts(pre.incident || myIncidents()[0])}</select>`;
      else if (f.type === 'unit') h = `<select class="fin" id="${id}">${S.board.units.map(u => `<option ${u.source === S.me.src ? 'selected' : ''}>${esc(u.apparatus || u.callsign)}</option>`).join('')}</select>`;
      else if (f.type === 'number') h = `<input class="fin" type="number" min="0" max="999" id="${id}">`;
      else if (f.type === 'narr') h = `<textarea class="fin" id="${id}" maxlength="4000" style="min-height:130px" placeholder="At least ${S.cfg.minNarrative} characters..."></textarea>`;
      else if (f.type === 'area') h = `<textarea class="fin" id="${id}" maxlength="1000" style="min-height:60px"></textarea>`;
      else h = `<input class="fin" id="${id}" maxlength="200">`;
      return `<div class="${full ? 'full' : ''}"><label class="lbl">${esc(f.label)}${f.required ? ' *' : ''}</label>${h}</div>`;
    };
    sc.innerHTML = `<div class="panel main"><div class="ftabs" id="fFTabs">${forms.map(f => `<button class="${f.key === S.formKey ? 'on' : ''}" data-k="${f.key}">${esc(f.label)}</button>`).join('')}</div>
        <div class="tabbody" style="border-top:1px solid var(--line-2)"><div class="formgrid"><div><label class="lbl">Author</label><input class="fin" value="${esc(S.me.short)} (${esc(S.me.callsign)}) · ${esc(S.me.dept)}" readonly></div><div><label class="lbl">Date</label><input class="fin" value="${d24(Date.now() / 1000)}" readonly></div>
        ${F.fields.map(field).join('')}<div class="full hint">Narratives need at least ${S.cfg.minNarrative} characters.</div></div>
        <div class="actbar" style="justify-content:flex-end"><button class="btn gray" id="fFClear">Clear</button><button class="btn green" id="fFSubmit">Submit ${esc(F.label)}</button></div></div></div>
      <div class="panel side"><div class="phead"><h2>My Reports</h2></div><div class="grid"><table><thead><tr><th>Number</th><th>Type</th><th>Patient</th><th>Filed</th></tr></thead><tbody id="fMyRep"><tr><td colspan="4" class="empty">Loading...</td></tr></tbody></table></div></div>`;
    F.fields.filter(f => f.type === 'person').forEach(f => wirePicker('fF_' + f.key, pre.person));
    $$('#fFTabs button').forEach(b => b.onclick = () => { S.formKey = b.dataset.k; S.formPrefill = {}; renderForms(sc); });
    $('#fFClear').onclick = () => { S.formPrefill = {}; renderForms(sc); };
    $('#fFSubmit').onclick = async () => {
      const data = {};
      F.fields.forEach(f => { const el = $('#fF_' + f.key); if (!el) return; let v = el.value; if (v === '') return; data[f.key] = (f.type === 'number' || f.type === 'incident' || f.type === 'person') ? +v : v; });
      const btn = $('#fFSubmit'); btn.disabled = true;
      const r = await call('fire.submitReport', { form: F.key, data });
      btn.disabled = false;
      if (r) { toast(`${r.number} filed`); S.formPrefill = {}; renderForms(sc); }
    };
    if (!historyCache.length) { const h = await call('fire.history'); if (h) { historyCache = h.slice(0, 25); if (S.screen === 'forms' && $('#fF_incident')) $('#fF_incident').innerHTML = incOpts(pre.incident || myIncidents()[0]); } }
    const mine = await call('fire.myReports'); if (!mine || S.screen !== 'forms') return;
    const label = k => (forms.find(f => f.key === k) || { label: k }).label;
    const prefix = { pcr: 'PCR', fireinc: 'FIR', rescue: 'RES', mvc: 'MVC', hazmat: 'HAZ', transport: 'TRN' };
    $('#fMyRep').innerHTML = mine.map(r => `<tr class="click c-avail" data-r="${r.id}"><td>${prefix[r.form] || 'RPT'}-${r.id}</td><td>${esc(label(r.form))}</td><td>${esc(r.subject_name || '-')}</td><td>${d24(r.at).slice(0, 10)}</td></tr>`).join('') || '<tr><td colspan="4" class="empty">Nothing filed yet</td></tr>';
    $$('#fMyRep [data-r]').forEach(tr => tr.onclick = async () => {
      const r = await call('fire.getReport', { id: +tr.dataset.r }); if (!r) return;
      const F2 = forms.find(f => f.key === r.form) || { fields: [], label: r.form };
      modal(`${prefix[r.form] || 'RPT'}-${r.id} · ${F2.label.toUpperCase()}`, `<div><span class="lbl">Author</span><b>${esc(r.author_label)}</b> · ${d24(r.at)}</div>` +
        F2.fields.map(f => { let v = r.data[f.key]; if (v === undefined || v === null || v === '') return ''; if (f.type === 'person') v = r.subject_name || ('ID ' + v); if (f.type === 'incident') v = '#' + v;
          return `<div><span class="lbl">${esc(f.label)}</span><div style="font-weight:700;white-space:pre-wrap">${esc(v)}</div></div>`; }).join(''), [{ label: 'Close', cls: 'gray' }], true);
    });
  }

  /* ---------------- alerts ---------------- */
  async function renderAlerts(sc) {
    const tbl = (title, color, rows, empty, extra = '') => `<div class="sect" style="${color ? 'color:' + color : ''}">${title}${extra}</div><table><thead><tr><th>Inc#</th><th>Nature</th><th>Location</th><th>Pr.</th><th>Status</th><th>Units</th><th>Age</th></tr></thead><tbody>${rows || `<tr><td colspan="7" class="empty">${empty}</td></tr>`}</tbody></table>`;
    const row = i => `<tr class="click ${i.priority === 1 ? 'c-p1' : 'c-avail'}" data-id="${i.id}"><td>${i.id}</td><td>${esc(i.nature)}</td><td class="wrap">${esc(i.address)}</td><td>${i.priority}</td><td>${incStatus(i)}</td><td>${i.units.map(u => esc(u.callsign)).join(', ')}</td><td>${age(i.createdAt)}</td></tr>`;
    const by = types => S.board.incidents.filter(i => types.includes(i.type)).map(row).join('');
    const a = await call('fire.alerts'); if (!a || S.screen !== 'alerts') return;
    const m = a.mayday;
    let html = m ? `<div class="mayday big">MAYDAY · ${esc(m.unit)} · ${esc(m.location)} · ${t24(m.at)}<br><span>${esc(m.detail || 'No details')}</span><button class="btn green" id="fMdClear">Clear · PAR</button></div>` : '';
    html += tbl('ACTIVE MEDICAL CALLS', '#ff8a8a', by(['MEDICAL']), 'No active medical calls');
    html += tbl('ACTIVE FIRE & HAZMAT CALLS', '#fb923c', by(['FIRE', 'HAZMAT']), 'No active fire calls');
    html += tbl('RESCUE REQUESTS & MVCs', '#38d9f0', by(['RESCUE', 'MVC']), 'No rescue requests');
    html += `<div class="sect" style="color:#f4d03f">MUTUAL AID REQUESTS <span class="lnk" id="fMaNew" style="margin-left:10px">+ Request mutual aid</span></div><table><thead><tr><th>From</th><th>To</th><th>Need</th><th>Status</th><th>By</th><th>Age</th><th></th></tr></thead><tbody>${a.mutualAid.map(r =>
      `<tr class="${r.status === 'OPEN' ? 'c-enrt' : 'c-dim'}"><td>${esc(r.from_station)}</td><td>${esc(r.to_dept)}</td><td class="wrap">${esc(r.need)}</td><td>${r.status}</td><td>${esc(r.created_by)}</td><td>${age(r.at)}</td><td>${r.status === 'OPEN' ? `<span class="lnk g" data-ma="${r.id}">Mark filled</span>` : ''}</td></tr>`).join('') || '<tr><td colspan="7" class="empty">No mutual aid requests</td></tr>'}</tbody></table>`;
    html += `<div class="sect">STATION ANNOUNCEMENTS${S.me.supervisor ? ' <span class="lnk" id="fAnNew" style="margin-left:10px">+ Post</span>' : ''}</div><table><thead><tr><th style="width:150px">Time</th><th style="width:170px">From</th><th>Announcement</th></tr></thead><tbody>${a.announcements.map(n =>
      `<tr><td>${d24(n.at)}</td><td>${esc(n.created_by)}</td><td class="wrap"><b style="color:#fff">${esc(n.title)}</b>${n.body ? '<br>' + esc(n.body) : ''}</td></tr>`).join('') || '<tr><td colspan="3" class="empty">No announcements</td></tr>'}</tbody></table>`;
    sc.innerHTML = `<div class="panel" style="flex:1"><div class="alerthead"><h2>${svg('alert')}SAFR Alerts</h2></div><div class="grid">${html}</div></div>`;
    $$('#fScreen tr[data-id]').forEach(r => r.onclick = () => openIncident(+r.dataset.id));
    const b = (id, f) => { const e = $('#' + id); if (e) e.onclick = f; };
    b('fMdClear', maydayModal); b('fAnNew', announceModal);
    b('fMaNew', () => modal('Request mutual aid', `<div><label class="lbl">From</label><select class="fin" id="fMaFrom">${S.cfg.stations.map(s => `<option>${esc(s.name)}</option>`).join('')}</select></div>
      <div><label class="lbl">Request to</label><select class="fin" id="fMaTo">${S.cfg.mutualAidTo.map(d => `<option>${esc(d)}</option>`).join('')}</select></div>
      <div><label class="lbl">What you need</label><textarea class="fin" id="fMaNeed" maxlength="300"></textarea></div><div class="hint">Every on-duty unit in that department is notified.</div>`,
      [{ label: 'Cancel', cls: 'gray' }, { label: 'Send Request', run: async () => { if (!(await call('fire.mutualAid', { from: $('#fMaFrom').value, to: $('#fMaTo').value, need: $('#fMaNeed').value }, 'Mutual aid requested'))) return false; renderAlerts(sc); } }]));
    $$('#fScreen [data-ma]').forEach(x => x.onclick = async () => { if (await call('fire.mutualAidFill', { id: +x.dataset.ma }, 'Marked filled')) renderAlerts(sc); });
  }

  /* ---------------- history ---------------- */
  async function renderHistory(sc) {
    sc.innerHTML = '<div class="panel" style="flex:1"><div class="phead"><h2>Incident History</h2><span class="sub">Last 100 closed incidents</span></div><div class="grid"><table><thead><tr><th>Inc#</th><th>Type / Nature</th><th>Pr.</th><th>Address</th><th>Caller</th><th>Units</th><th>Opened</th><th>Closed</th><th>Disposition</th></tr></thead><tbody id="fHist"><tr><td colspan="9" class="empty">Loading...</td></tr></tbody></table></div></div>';
    const rows = await call('fire.history'); if (!rows || S.screen !== 'history') return;
    historyCache = rows.slice(0, 25);
    $('#fHist').innerHTML = rows.map(h => `<tr class="click ${h.priority === 1 ? 'c-p1' : 'c-avail'}" data-id="${h.id}"><td>${h.id}</td><td>${esc(h.type)} · ${esc(h.nature)}</td><td>${h.priority}</td><td>${esc(h.street || '')}</td><td>${esc(h.caller || '')}</td><td>${esc(h.units || '')}</td><td>${d24(h.createdAt)}</td><td>${h.closedAt ? d24(h.closedAt) : ''}</td><td>${esc(h.disposition || '')}</td></tr>`).join('') || '<tr><td colspan="9" class="empty">Nothing closed yet</td></tr>';
    $$('#fHist tr[data-id]').forEach(r => r.onclick = () => openIncident(+r.dataset.id));
  }

  /* ---------------- management ---------------- */
  async function renderMgmt(sc) {
    const tabs = [['roster', 'Personnel Roster'], ['stations', 'Fire Stations'], ['apparatus', 'Apparatus & Vehicles'], ['certs', 'Certifications']];
    const sup = S.me.supervisor;
    sc.innerHTML = `<div class="panel" style="flex:1"><div class="ftabs">${tabs.map(t => `<button class="${t[0] === S.sub ? 'on' : ''}" data-sub="${t[0]}">${t[1]}</button>`).join('')}<span class="hint" style="margin-left:auto;align-self:center;padding-right:8px">${sup ? 'Supervisor: you can edit' : 'Read only · supervisors can edit'}</span></div><div class="grid" id="fMgmt" style="border-top:1px solid var(--line-2)"><div class="empty">Loading...</div></div></div>`;
    $$('#fScreen [data-sub]').forEach(b => b.onclick = () => { S.sub = b.dataset.sub; renderMgmt(sc); });
    const el = $('#fMgmt');
    if (S.sub === 'stations') {
      el.innerHTML = `<table><thead><tr><th>Station</th><th>Address</th><th>Apparatus</th><th>On Duty</th></tr></thead><tbody>${S.cfg.stations.map(st => {
        const apps = S.board.apparatus.filter(a => a.station === st.name), crew = S.board.units.filter(u => u.station === st.name).length;
        return `<tr><td><b>${esc(st.name)}</b></td><td>${esc(st.address)}</td><td>${apps.map(a => `<span class="uchip ${a.oos ? 'c-offdt' : a.crew.length ? 'c-avail' : ''}">${esc(a.id)}</span>`).join(' ')}</td><td>${crew}</td></tr>`; }).join('')}</tbody></table>`;
      return;
    }
    if (S.sub === 'apparatus') {
      el.innerHTML = `<table><thead><tr><th>Apparatus</th><th>Type</th><th>Station</th><th>Crew</th><th>Status</th><th></th></tr></thead><tbody>${S.board.apparatus.map(a =>
        `<tr class="${a.oos ? 'c-offdt' : a.crew.length ? 'c-avail' : ''}"><td><b>${esc(a.id)}</b></td><td>${esc(a.type)}</td><td>${esc(a.station)}</td><td>${a.crew.map(esc).join(', ') || '-'}</td><td>${a.oos ? 'OUT OF SERVICE' : a.crew.length ? 'IN SERVICE' : 'AVAILABLE'}</td>
        <td>${sup ? `<span class="lnk ${a.oos ? 'g' : 'r'}" data-oos="${esc(a.id)}" data-v="${a.oos ? 0 : 1}">${a.oos ? 'Return to service' : 'Out of service'}</span>` : ''}</td></tr>`).join('')}</tbody></table>
        <div class="hint" style="padding:8px 12px">Units pick the apparatus they ride on in the status bar. Apparatus are set in config.lua (Config.Fire.apparatus).</div>`;
      $$('#fMgmt [data-oos]').forEach(x => x.onclick = async () => { if (await call('fire.apparatusOOS', { id: x.dataset.oos, oos: x.dataset.v === '1' })) { await refresh(); renderMgmt(sc); } });
      return;
    }
    const rows = await call('fire.roster'); if (!rows || S.screen !== 'mgmt') return;
    if (S.sub === 'roster') {
      el.innerHTML = `<table><thead><tr><th>Name</th><th>Callsign</th><th>Status</th><th>Apparatus</th><th>Certifications</th><th>Last Seen</th><th></th></tr></thead><tbody>${rows.map(r =>
        `<tr class="${r.onDuty ? stCls(r.onDuty.status) : 'c-dim'}"><td><b>${esc(r.name)}</b></td><td>${esc(r.callsign || '')}</td><td>${r.onDuty ? 'ON DUTY · ' + r.onDuty.status : 'OFF DUTY'}</td><td>${esc((r.onDuty && r.onDuty.apparatus) || '-')}</td><td class="wrap">${esc((r.certs || []).join(', ') || '-')}</td><td>${d24(r.seen).slice(0, 10)}</td><td>${sup ? `<span class="lnk" data-m="${r.member_id}">Certifications</span>` : ''}</td></tr>`).join('') || '<tr><td colspan="7" class="empty">No members yet. Members are added the first time they open the SAFR CAD.</td></tr>'}</tbody></table>
        <div class="hint" style="padding:8px 12px">Who can go on duty as SAFR, and who is a supervisor, is set with ACE permissions (unitlink.safr.duty / unitlink.safr.supervisor), not here.</div>`;
      $$('#fMgmt [data-m]').forEach(x => x.onclick = () => certModal(rows.find(r => r.member_id === +x.dataset.m), () => renderMgmt(sc)));
      return;
    }
    el.innerHTML = `<table><thead><tr><th>Name</th>${S.cfg.certifications.map(c => `<th style="text-align:center">${esc(c)}</th>`).join('')}</tr></thead><tbody>${rows.map(r =>
      `<tr><td><b>${esc(r.name)}</b></td>${S.cfg.certifications.map(c => `<td style="text-align:center" class="${sup ? 'click' : ''}" data-c="${r.member_id}|${esc(c)}">${(r.certs || []).includes(c) ? '<span style="color:var(--avail)">✔</span>' : '<span style="color:var(--dim)">-</span>'}</td>`).join('')}</tr>`).join('') || '<tr><td class="empty">No members yet</td></tr>'}</tbody></table>
      ${sup ? '<div class="hint" style="padding:8px 12px">Click a cell to grant or remove a certification.</div>' : ''}`;
    if (sup) $$('#fMgmt [data-c]').forEach(x => x.onclick = async () => {
      const [mid, c] = x.dataset.c.split('|'); const r = rows.find(z => z.member_id === +mid);
      const certs = (r.certs || []).includes(c) ? r.certs.filter(z => z !== c) : [...(r.certs || []), c];
      if (await call('fire.setCerts', { member: +mid, certs })) renderMgmt(sc);
    });
  }
  function certModal(r, done) {
    modal(`Certifications · ${r.name}`, `<div class="xchecks">${S.cfg.certifications.map(c => `<label><input type="checkbox" value="${esc(c)}" ${(r.certs || []).includes(c) ? 'checked' : ''}> ${esc(c)}</label>`).join('')}</div>`,
      [{ label: 'Cancel', cls: 'gray' }, { label: 'Save', cls: 'green', run: async () => {
        const certs = $$('#fmBody .xchecks input:checked').map(i => i.value);
        if (!(await call('fire.setCerts', { member: r.member_id, certs }, 'Certifications saved'))) return false; done();
      } }]);
  }

  /* ---------------- lifecycle ---------------- */
  UL.on('openFire', m => {
    const d = m.data;
    S.cfg = d; S.me = d.me; S.board = d.board; S.screen = 'cad'; S.data = null;
    $('#fire').classList.add('on');
    show('cad');
  });
  UL.on('closeFire', () => { $('#fire').classList.remove('on'); closeModal(); });
  UL.on('firePush', m => {
    if (!S.cfg) return;
    if (m.kind === 'fireBoard') applyBoard(m.data);
    if (m.kind === 'fireNote' && S.data && (S.data.incident || S.data.closed || {}).id === m.data.id) {
      S.data.notes.push(m.data.note);
      if (S.screen === 'call' && S.tab === 'notes') renderTabs();
    }
    if (m.kind === 'fireClosed' && S.data && S.data.incident && S.data.incident.id === m.data.id) {
      toast(`Incident #${m.data.id} closed by ${m.data.by}: ${m.data.disposition}`);
      if (S.screen === 'call') loadIncident(m.data.id).then(ok => ok && renderCall($('#fScreen')));
    }
    if (m.kind === 'fireAlerts' && S.screen === 'alerts') renderAlerts($('#fScreen'));
  });
  $('#fClose').onclick = () => UL.req('close');
  document.addEventListener('keydown', e => {
    if (e.key !== 'Escape' || !$('#fire').classList.contains('on')) return;
    if ($('#fModal').classList.contains('on')) return closeModal();
    UL.req('close');
  });
  setInterval(() => { const d = new Date(); $('#fClock').textContent = `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`; }, 1000);
  setInterval(() => { if (S.cfg && S.screen === 'cad' && $('#fire').classList.contains('on') && !document.activeElement.matches('select,input')) renderBoard($('#fScreen')); }, 30000);
})();
