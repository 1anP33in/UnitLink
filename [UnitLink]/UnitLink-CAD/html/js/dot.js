/* UnitLink DOT: Work Orders. Same look as the police CAD.
   Everything comes from the server ('dot.*' requests + dotPush). */
(() => {
  'use strict';
  const $ = s => document.querySelector(s), $$ = s => [...document.querySelectorAll(s)];
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[c]));
  const pad = n => String(n).padStart(2, '0');
  const t24 = sec => { const d = new Date(sec * 1000); return `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`; };
  const d24 = sec => { const d = new Date(sec * 1000); return `${pad(d.getMonth()+1)}/${pad(d.getDate())}/${d.getFullYear()} ${t24(sec)}`; };
  const age = sec => { const m = Math.max(0, Math.floor((Date.now()/1000 - sec) / 60)); return m < 60 ? m + 'm' : m < 1440 ? Math.floor(m/60) + 'h' + (m%60) + 'm' : Math.floor(m/1440) + 'd'; };
  const I = {
    cad:'<rect x="3" y="4" width="18" height="12" rx="1.5"/><path d="M8 20h8M12 16v4"/>', star:'<path d="M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1L3.2 9.5l6.1-.9z"/>',
    truck:'<path d="M2 6h11v10H2zM13 10h5l3 3v3h-8"/><circle cx="6" cy="18" r="2"/><circle cx="17" cy="18" r="2"/>', forms:'<path d="M6 3h9l3 3v15H6z"/><path d="M9 10h6M9 14h6M9 18h3"/>',
    alert:'<path d="M12 3l9 16H3z"/><path d="M12 10v4M12 17v.1"/>', station:'<path d="M3 21V9l9-6 9 6v12"/><path d="M9 21v-6h6v6"/>', history:'<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    phone:'<path d="M5 4h4l2 5-2.5 1.5a11 11 0 005 5L15 13l5 2v4a2 2 0 01-2 2A16 16 0 013 6a2 2 0 012-2"/>', mega:'<path d="M3 10v4h3l7 4V6L6 10z"/><path d="M17 9a4 4 0 010 6"/>',
    route:'<circle cx="6" cy="18" r="2"/><circle cx="18" cy="6" r="2"/><path d="M8 18h7a3 3 0 000-6H9a3 3 0 010-6h7"/>', trash:'<path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/>',
    search:'<circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/>', tools:'<circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4M8 11h6M11 8v6"/>',
  };
  const svg = (n, c) => `<svg viewBox="0 0 24 24" ${c ? `style="--ic:${c}"` : ''}>${I[n]}</svg>`;

  const S = { cfg: null, me: null, board: { orders: [], units: [] }, screen: 'cad', sel: null, open: null, data: null, tab: 'notes',
    formKey: null, formPrefill: {}, sub: 'roster', fsub: 'vehicles', q: '', uq: '', filter: '' };
  let toastTimer;
  const toast = (msg, err) => { const t = $('#dToast'); t.textContent = msg; t.className = 'toast on' + (err ? ' err' : ''); clearTimeout(toastTimer); toastTimer = setTimeout(() => t.className = 'toast', 2800); };
  async function call(action, payload, okMsg) {
    const r = await UL.req(action, payload);
    if (!r || !r.ok) { toast((r && r.data) || 'Request failed.', true); return null; }
    if (okMsg) toast(okMsg);
    return r.data === undefined ? true : r.data;
  }
  const stCls = code => 'c-' + ((S.cfg.statuses.find(s => s.code === code) || { color: 'dim' }).color);
  const myUnit = () => S.board.units.find(u => u.source === S.me.src) || null;
  const myOrders = () => (myUnit() || { orders: [] }).orders;
  const findOrder = id => S.board.orders.find(o => o.id === id);
  const priOpts = sel => [1, 2, 3].map(p => `<option value="${p}" ${p === sel ? 'selected' : ''}>${p}</option>`).join('');

  function modal(title, body, buttons, wide) {
    $('#dmTitle').textContent = title; $('#dmBody').innerHTML = body;
    $('#dModal .mbox').style.width = wide ? '640px' : '';
    $('#dmFoot').innerHTML = buttons.map((b, i) => `<button class="btn ${b.cls || ''}" data-i="${i}">${b.label}</button>`).join('');
    $$('#dmFoot button').forEach(el => el.onclick = async () => { const b = buttons[+el.dataset.i]; if (!b.run || (await b.run()) !== false) closeModal(); });
    $('#dModal').classList.add('on');
    const first = $('#dmBody input, #dmBody select, #dmBody textarea'); if (first) first.focus();
  }
  const closeModal = () => $('#dModal').classList.remove('on');

  /* ---------------- chrome ---------------- */
  const TILES = [
    ['cad', 'Job Board', '#fff', 'cad'], ['mycall', 'My Job', '#cbd5e1', 'star'], ['fleet', 'Fleet & Equip', '#ffd257', 'truck'], ['forms', 'Reports', '#fff', 'forms'],
    ['alerts', 'Road Alerts', '#ff6b6b', 'alert'], ['mgmt', 'Crew Roster', '#9cc3ff', 'station'], ['history', 'History', '#9cc3ff', 'history'], ['|'],
    ['newcall', 'New Job', '#3ee06a', 'phone'], ['assign', 'Assign Self', '#3ee06a', 'phone'], ['|'], ['tools', 'Tools', '#ffd257', 'tools'], ['announce', 'Announce', '#ffd257', 'mega'],
  ];
  function tileOff(t) {
    if (t === 'mycall') return !myOrders().length;
    if (t === 'assign') return !S.sel || !findOrder(S.sel) || myOrders().includes(S.sel);
    if (t === 'announce') return !S.me.supervisor;
    return false;
  }
  function chrome() {
    $('#dToolbar').innerHTML = TILES.map(t => t[0] === '|' ? '<div class="gap"></div>' :
      `<div class="tile ${tileOff(t[0]) ? 'off' : ''} ${t[0] === S.screen || (S.screen === 'call' && t[0] === 'mycall' && myOrders().includes(S.open)) ? 'on' : ''}" data-t="${t[0]}">${svg(t[3], t[2])}${t[1]}${t[0] === 'tools' && window.ULTools && ULTools.unread() ? `<i class="badge">${ULTools.unread()}</i>` : ''}</div>`).join('') +
      '<div class="seal"><div>DOT</div></div>';
    $$('#dToolbar .tile').forEach(el => el.onclick = () => !el.classList.contains('off') && action(el.dataset.t));
    const u = myUnit();
    $('#dsStatus').innerHTML = S.cfg.statuses.map(s => `<option value="${s.code}" ${u && s.code === u.status ? 'selected' : ''}>${s.code}</option>`).join('');
    $('#dsVeh').innerHTML = '<option value="">NONE</option>' + S.cfg.fleet.map(v => `<option ${u && v.id === u.vehicle ? 'selected' : ''}>${esc(v.id)}</option>`).join('');
    $('#dsCall').textContent = myOrders().length ? `Active Job: ${myOrders().map(i => 'WO-' + i).join(', ')}` : 'No Active Job';
    $('#dsUnit').textContent = `${S.me.callsign} · ${S.me.short} · ${S.me.dept}${S.me.supervisor ? ' · SUPERVISOR' : ''}`;
  }
  const TITLES = { cad: 'DOT · Job Board', fleet: 'DOT · Fleet & Equipment', forms: 'DOT · Reports', alerts: 'DOT · Road Alerts', mgmt: 'DOT · Crew Roster', history: 'DOT · Completed Work Orders' };
  function show(screen) {
    S.screen = screen;
    const sc = $('#dScreen'); sc.className = 'fscreen ' + screen;
    const c = S.data && (S.data.order || S.data.closed);
    $('#dTitle').textContent = screen === 'call' && c ? `WO-${c.id} - ${c.category}` : TITLES[screen];
    ({ cad: renderBoard, call: renderOrder, fleet: renderFleet, forms: renderForms, alerts: renderAlerts, mgmt: renderMgmt, history: renderHistory })[screen](sc);
    chrome();
  }
  async function action(t) {
    if (t === 'mycall') return openOrder(myOrders()[0]);
    if (t === 'newcall') return newJobModal();
    if (t === 'assign') { if (await call('dot.assign', { id: S.sel }, `Attached to WO-${S.sel}`)) refresh(); return; }
    if (t === 'announce') return announceModal();
    if (t === 'tools') return window.ULTools && ULTools.open();
    show(t);
  }
  async function refresh() { const b = await call('dot.board'); if (b) applyBoard(b); }
  function applyBoard(b) {
    S.board = b;
    if (S.screen === 'cad') renderBoard($('#dScreen'));
    if (S.screen === 'call' && S.data && S.data.order) {
      const live = findOrder(S.data.order.id);
      if (live) { S.data.order = live; renderOrder($('#dScreen')); } else loadOrder(S.data.order.id).then(ok => ok && renderOrder($('#dScreen')));
    }
    chrome();
  }
  async function setStatus(code) { await call('dot.setStatus', { code }); refresh(); }
  $('#dsStatus').onchange = e => setStatus(e.target.value);
  $('#dsVeh').onchange = async e => { await call('dot.setVehicle', { vehicle: e.target.value }, e.target.value ? `Driving ${e.target.value}` : 'No vehicle'); refresh(); };

  /* ---------------- board ---------------- */
  function renderBoard(sc) {
    const q = S.q.toLowerCase();
    const f = S.cfg.filters.find(x => x.label === S.filter);
    const list = S.board.orders.filter(o => (!q || JSON.stringify(o).toLowerCase().includes(q)) && (!f || f.categories.includes(o.category)));
    const rows = list.map(o => {
      const cls = o.priority === 1 ? 'c-p1' : o.status === 'OPEN' ? 'c-pend' : o.status === 'ON HOLD' ? 'c-dim' : 'c-avail';
      return `<tr class="click ${cls} ${o.id === S.sel ? 'sel' : ''}" data-id="${o.id}"><td>WO-${o.id}</td><td>${esc(o.category)}</td><td class="trunc">${esc(o.description)}</td><td>${esc(o.address)}</td><td>${o.priority}</td><td>${esc(o.status)}</td><td>${o.units.map(u => esc(u.callsign)).join(', ')}</td><td class="trunc">${esc((o.equipment || []).join(', '))}</td><td>${age(o.createdAt)}</td></tr>`;
    }).join('') || '<tr><td colspan="9" class="empty">No open work orders</td></tr>';
    const uq = S.uq.toLowerCase();
    const urows = S.board.units.filter(u => !uq || JSON.stringify(u).toLowerCase().includes(uq)).map(u => {
      const mine = u.source === S.me.src;
      const st = mine ? `<select class="cellsel" id="dMyStatus">${S.cfg.statuses.map(s => `<option ${s.code === u.status ? 'selected' : ''}>${s.code}</option>`).join('')}</select>` : u.status;
      return `<tr class="${stCls(u.status)} ${mine ? 'sel' : ''}"><td>${esc(u.callsign)}</td><td>${esc(u.name)}</td><td>${esc(u.vehicle || '-')}</td><td>${st}</td><td>${u.orders.map(i => 'WO-' + i).join(', ')}</td><td>${esc(u.location || '')}</td></tr>`;
    }).join('') || '<tr><td colspan="6" class="empty">No DOT units on duty</td></tr>';
    const count = fl => S.board.orders.filter(o => !fl || fl.categories.includes(o.category)).length;
    sc.innerHTML = `<div class="panel fcalls"><div class="phead"><h2>Work Orders & Requests</h2>
        <div class="chips"><span class="chip ${!S.filter ? 'on' : ''}" data-f="">All jobs <b>${count(null)}</b></span>${S.cfg.filters.map(fl => `<span class="chip ${S.filter === fl.label ? 'on' : ''}" data-f="${esc(fl.label)}">${esc(fl.label)} <b>${count(fl)}</b></span>`).join('')}</div>
        <div class="tools"><div class="pill">${svg('search')}<input id="dCallQ" placeholder="Search..." value="${esc(S.q)}"></div><button class="plus" id="dPlus" title="New job">+</button></div></div>
        <div class="grid"><table><thead><tr><th>WO#</th><th>Category</th><th>Description</th><th>Location</th><th>Pr.</th><th>Status</th><th>Assigned</th><th>Equipment</th><th>Age</th></tr></thead><tbody>${rows}</tbody></table></div></div>
      <div class="panel funits"><div class="phead"><h2>DOT Units</h2><span class="sub">${S.board.units.filter(u => u.status === 'AVAIL').length} available of ${S.board.units.length}</span><div class="tools"><div class="pill">${svg('search')}<input id="dUnitQ" placeholder="Search..." value="${esc(S.uq)}"></div></div></div>
        <div class="grid"><table><thead><tr><th>Unit</th><th>Employee</th><th>Vehicle</th><th>Status</th><th>WO#</th><th>Location</th></tr></thead><tbody>${urows}</tbody></table></div></div>`;
    $$('#dScreen tr[data-id]').forEach(r => { r.onclick = () => { S.sel = +r.dataset.id; renderBoard(sc); chrome(); }; r.ondblclick = () => openOrder(+r.dataset.id); });
    $$('#dScreen [data-f]').forEach(c => c.onclick = () => { S.filter = c.dataset.f; renderBoard(sc); });
    const keep = (id, key) => { const i = $('#' + id); i.oninput = () => { S[key] = i.value; const p = i.selectionStart; renderBoard(sc); const n = $('#' + id); n.focus(); n.setSelectionRange(p, p); }; };
    keep('dCallQ', 'q'); keep('dUnitQ', 'uq');
    $('#dPlus').onclick = () => newJobModal();
    const ms = $('#dMyStatus'); if (ms) ms.onchange = () => setStatus(ms.value);
  }

  /* ---------------- work order record ---------------- */
  async function loadOrder(id) { const d = await call('dot.get', { id }); if (!d) return false; S.data = d; S.sel = id; return true; }
  async function openOrder(id) { if (await loadOrder(id)) { S.open = id; S.tab = 'notes'; show('call'); } }
  window.ULDotOpen = id => openOrder(id);
  function renderOrder(sc) {
    const d = S.data; if (!d) return;
    const live = d.order, c = live || d.closed;
    const mine = live && myOrders().includes(live.id);
    const ro = live ? '' : 'disabled';
    const chips = (live ? live.units.map(u => `<span class="uchip ${stCls(u.status)}">${esc(u.callsign)} · ${u.status}</span>`) : (c.units || '').split(', ').filter(Boolean).map(u => `<span class="uchip">${esc(u)}</span>`)).join('') || '<span class="hint">None</span>';
    const crew = live ? live.units.map(u => `${esc(u.name)} (${esc(u.callsign)}${u.vehicle ? ' · ' + esc(u.vehicle) : ''})`).join(', ') : '';
    const statuses = live ? S.cfg.orderStatuses : ['CLOSED'];
    sc.innerHTML = `<div class="panel left"><div class="callhead ${live ? '' : 'closed'}"><h2>WO-${c.id} · ${esc(c.category)}</h2>
        <div class="tools">${live ? `<div class="sq" title="Set GPS" data-a="gps">${svg('route')}</div><div class="sq red" title="Complete job" data-a="close">${svg('trash')}</div>` : ''}</div></div>
      <div class="fields">${live ? '' : `<div class="hint warn">Completed (${esc(c.disposition || 'closed')}${c.closed_by ? ' by ' + esc(c.closed_by) : ''}). Read only.</div>`}
        <div class="frow"><label>Units</label><div class="uchips">${chips}</div></div>
        <div class="frow"><label>Opened</label><input class="fin" value="${d24(c.createdAt).replace(' ', ' @ ')}" readonly></div>
        <div class="frow"><label>Source</label><input class="fin" value="${({ cad: 'CAD (SELF-INITIATED)', '311': 'CIVILIAN SERVICE REQUEST', agency: 'AGENCY REQUEST' })[c.origin] || 'CAD'}" readonly></div>
        <div class="frow"><label>Category</label><select class="fin" id="dCat" ${ro}>${S.cfg.categories.map(t => `<option ${t === c.category ? 'selected' : ''}>${t}</option>`).join('')}</select></div>
        <div class="frow"><label>Job Status</label><select class="fin" id="dSt" ${ro}>${statuses.map(t => `<option ${t === c.status ? 'selected' : ''}>${t}</option>`).join('')}</select></div>
        <div class="frow"><label>Priority</label><select class="fin" id="dPri" ${ro}>${priOpts(c.priority)}</select></div>
        <div class="frow"><label>Location</label><input class="fin" value="${esc(live ? live.address : (c.street || ''))}" readonly></div>
        <div class="frow"><label>Requested By</label><input class="fin" value="${esc(c.requester || '')}" readonly></div>
        <div class="frow" style="align-items:start"><label>Description</label><textarea class="fin" id="dDesc" style="min-height:58px" ${ro}>${esc(c.description)}</textarea></div>
        <div class="frow"><label>Equipment</label><div class="uchips">${(c.equipment || []).map((e, i) => `<span class="uchip eq">${esc(e)}${live ? ` <b data-rmeq="${i + 1}">×</b>` : ''}</span>`).join('')}${live ? '<span class="uchip add" id="dAddEq">+ Add</span>' : ''}</div></div>
        ${live ? `<div class="frow"><label>Assigned</label><input class="fin" value="${crew || 'NONE'}" readonly></div>
        <div class="frow"><label></label><div style="display:flex;gap:6px;flex-wrap:wrap">${mine
          ? `${S.cfg.statuses.filter(s => s.onCall).map(s => `<button class="btn" data-st="${s.code}">${s.code}</button>`).join('')}<button class="btn gray" data-a="detach">Clear Self</button>`
          : '<button class="btn green" data-a="assign">Assign Self</button>'}</div></div>` : ''}</div></div>
      <div class="panel right"><div class="tabs" id="dTabs"></div><div class="tabbody" id="dTabBody"></div></div>`;
    $$('#dScreen [data-a]').forEach(b => b.onclick = async () => {
      const a = b.dataset.a, id = c.id;
      if (a === 'assign') { if (await call('dot.assign', { id }, `Attached to WO-${id}`)) refresh(); }
      if (a === 'detach') { if (await call('dot.detach', { id }, `Cleared from WO-${id}`)) refresh(); }
      if (a === 'gps') call('dot.waypoint', { id }, 'Waypoint set');
      if (a === 'close') { S.tab = 'completion'; renderTabs(); }
    });
    $$('#dScreen [data-st]').forEach(b => b.onclick = () => setStatus(b.dataset.st));
    if (live) {
      const upd = (sel, field, conv) => { const el = $(sel); el.onchange = async () => { if (await call('dot.update', { id: c.id, [field]: conv(el.value) })) { await loadOrder(c.id); refresh(); } }; };
      upd('#dCat', 'category', v => v); upd('#dSt', 'status', v => v); upd('#dPri', 'priority', v => +v); upd('#dDesc', 'description', v => v);
      $$('#dScreen [data-rmeq]').forEach(x => x.onclick = async () => { if (await call('dot.equipment', { id: c.id, remove: +x.dataset.rmeq })) { await loadOrder(c.id); renderOrder(sc); } });
      $('#dAddEq').onclick = () => modal('Add required equipment', `<div><label class="lbl">From inventory</label><select class="fin" id="dEqSel"><option value="">Other (type below)</option>${S.cfg.equipment.map(e => `<option>${esc(e.item)}</option>`).join('')}${S.cfg.fleet.map(v => `<option>${esc(v.id)}</option>`).join('')}</select></div><div><label class="lbl">Item</label><input class="fin" id="dEqTxt" maxlength="60"></div>`,
        [{ label: 'Cancel', cls: 'gray' }, { label: 'Add', run: async () => { const v = ($('#dEqSel').value || $('#dEqTxt').value).trim(); if (!v) return false; if (!(await call('dot.equipment', { id: c.id, add: v }))) return false; await loadOrder(c.id); renderOrder(sc); } }]);
    }
    renderTabs();
  }
  function renderTabs() {
    const d = S.data, live = d.order, c = live || d.closed;
    const TABS = [['notes', 'Activity'], ['completion', 'Completion'], ['info', 'Info'], ['history', 'Location History']];
    $('#dTabs').innerHTML = TABS.map(([k, l]) => `<button class="${S.tab === k ? 'on' : ''}" data-k="${k}">${l}</button>`).join('');
    $$('#dTabs button').forEach(b => b.onclick = () => { S.tab = b.dataset.k; renderTabs(); });
    const body = $('#dTabBody');
    if (S.tab === 'notes') {
      body.innerHTML = `<div class="notes" id="dNotes">${d.notes.map(n => `<div class="note ${n.system ? 'sys' : ''}"><div class="h">${d24(n.at)}${n.author === 'SYSTEM' ? '' : `<b>${esc(n.author)}</b>`}</div><div class="t">${esc(n.body)}</div></div>`).join('') || '<div class="empty">No activity yet</div>'}</div>
        ${live ? '<form class="cmt" id="dCmt"><input class="fin" id="dCmtIn" maxlength="500" placeholder="Type comment here..."><button class="btn">Add</button></form>' : ''}`;
      const nl = $('#dNotes'); nl.scrollTop = nl.scrollHeight;
      const f = $('#dCmt'); if (f) f.onsubmit = async e => { e.preventDefault(); const v = $('#dCmtIn').value.trim(); if (!v) return; if (await call('dot.note', { id: c.id, body: v })) $('#dCmtIn').value = ''; };
    } else if (S.tab === 'completion') {
      body.innerHTML = `<div class="formgrid"><div class="full"><label class="lbl">Completion Notes</label><textarea class="fin" id="dDone" style="min-height:160px" ${live ? '' : 'readonly'} placeholder="What was done, materials, follow-up needed... (at least ${S.cfg.minNarrative} characters)">${esc(c.completion || '')}</textarea></div>
        ${live ? `<div><label class="lbl">Disposition</label><select class="fin" id="dDispo">${S.cfg.dispositions.map(x => `<option>${esc(x)}</option>`).join('')}</select></div>` : `<div><label class="lbl">Disposition</label><input class="fin" value="${esc(c.disposition || '')}" readonly></div>`}
        <div class="full hint">Opened ${d24(c.createdAt)}${live ? ` · open for ${age(c.createdAt)}` : ` · closed ${c.closedAt ? d24(c.closedAt) : ''} by ${esc(c.closed_by || '')}`}</div></div>
        ${live ? '<div class="actbar" style="justify-content:flex-end"><button class="btn gray" id="dSaveDone">Save Notes</button><button class="btn green" id="dComplete">Complete Job</button></div>' : ''}`;
      const s = $('#dSaveDone'); if (s) s.onclick = () => call('dot.update', { id: c.id, completion: $('#dDone').value }, 'Saved');
      const k = $('#dComplete'); if (k) k.onclick = async () => { if (await call('dot.complete', { id: c.id, completion: $('#dDone').value, disposition: $('#dDispo').value }, `WO-${c.id} completed`)) { S.data = null; show('cad'); refresh(); } };
    } else if (S.tab === 'info') {
      body.innerHTML = `<dl class="kvtab"><dt>Work Order</dt><dd>WO-${c.id}</dd><dt>Requested By</dt><dd>${esc(c.requester || '')}</dd><dt>Opened</dt><dd>${d24(c.createdAt)}</dd><dt>Open For</dt><dd>${live ? age(c.createdAt) : 'CLOSED'}</dd><dt>Priority</dt><dd>${c.priority}</dd><dt>Job Description</dt><dd style="white-space:pre-wrap;font-weight:600">${esc(c.description)}</dd></dl>`;
    } else {
      body.innerHTML = d.history.length ? `<div class="grid" style="border-top:0"><table><thead><tr><th>Closed</th><th>WO#</th><th>Category</th><th>Units</th><th>Disposition</th></tr></thead><tbody>${d.history.map(h => `<tr class="click c-avail" data-id="${h.id}"><td>${d24(h.at)}</td><td>WO-${h.id}</td><td>${esc(h.category)}</td><td>${esc(h.units || '')}</td><td>${esc(h.disposition || '')}</td></tr>`).join('')}</tbody></table></div>` : '<div class="empty">No earlier jobs at this location.</div>';
      $$('#dTabBody tr[data-id]').forEach(r => r.onclick = () => openOrder(+r.dataset.id));
    }
  }

  function newJobModal() {
    modal('New Job (self-initiated)', `<div><label class="lbl">Category</label><select class="fin" id="dNcCat">${S.cfg.categories.map(t => `<option>${t}</option>`).join('')}</select></div>
      <div><label class="lbl">Priority</label><select class="fin" id="dNcPri">${priOpts(3)}</select></div>
      <div><label class="lbl">Job Description</label><textarea class="fin" id="dNcDesc" maxlength="500" placeholder="What needs doing, lanes affected, equipment..."></textarea></div>
      <label class="xcheck"><input type="checkbox" id="dNcSelf" checked> Attach me (${esc(S.me.callsign)})</label><div class="hint">Created at your current location.</div>`,
      [{ label: 'Cancel', cls: 'gray' }, { label: 'Create Job', cls: 'green', run: async () => {
        const r = await call('dot.create', { category: $('#dNcCat').value, priority: +$('#dNcPri').value, description: $('#dNcDesc').value, attach: $('#dNcSelf').checked });
        if (!r) return false;
        toast(`WO-${r.id} created`); await refresh(); openOrder(r.id);
      } }]);
  }
  function announceModal() {
    modal('Department Announcement', `<div><label class="lbl">Title</label><input class="fin" id="dAnT" maxlength="80"></div><div><label class="lbl">Message</label><textarea class="fin" id="dAnB" maxlength="600"></textarea></div><div class="hint">Goes to every on-duty DOT unit.</div>`,
      [{ label: 'Cancel', cls: 'gray' }, { label: 'Send', run: async () => { if (!(await call('dot.announce', { title: $('#dAnT').value, body: $('#dAnB').value }, 'Announcement sent'))) return false; if (S.screen === 'alerts') renderAlerts($('#dScreen')); } }]);
  }

  /* ---------------- fleet ---------------- */
  async function renderFleet(sc) {
    const tabs = [['vehicles', 'Vehicles'], ['equipment', 'Equipment Inventory'], ['maintenance', 'Maintenance Records']];
    sc.innerHTML = `<div class="panel" style="flex:1"><div class="ftabs">${tabs.map(t => `<button class="${t[0] === S.fsub ? 'on' : ''}" data-fs="${t[0]}">${t[1]}</button>`).join('')}</div><div class="grid" id="dFleet" style="border-top:1px solid var(--line-2)"><div class="empty">Loading...</div></div></div>`;
    $$('#dScreen [data-fs]').forEach(b => b.onclick = () => { S.fsub = b.dataset.fs; renderFleet(sc); });
    const f = await call('dot.fleet'); if (!f || S.screen !== 'fleet') return;
    const el = $('#dFleet'), R = () => renderFleet(sc);
    if (S.fsub === 'vehicles') {
      el.innerHTML = `<table><thead><tr><th>Vehicle</th><th>Type</th><th>Assigned Employee</th><th>Availability</th><th>Last Service</th><th></th></tr></thead><tbody>${f.fleet.map(v =>
        `<tr class="${v.status === 'AVAILABLE' ? 'c-avail' : v.status === 'IN USE' ? 'c-enrt' : 'c-offdt'}"><td><b>${esc(v.id)}</b></td><td>${esc(v.type)}</td><td>${esc(v.assigned || '-')}</td><td>${esc(v.status)}</td><td>${v.service ? d24(v.service).slice(0, 10) : '-'}</td>
        <td><span class="lnk" data-asg="${esc(v.id)}">Assign</span>${v.status === 'OUT OF SERVICE' ? `<span class="lnk g" data-rts="${esc(v.id)}">Return to service</span>` : `<span class="lnk r" data-oos="${esc(v.id)}">Out of service</span>`}</td></tr>`).join('')}</tbody></table>`;
      $$('#dFleet [data-asg]').forEach(x => x.onclick = () => modal(`Assign ${x.dataset.asg}`, `<div><label class="lbl">Employee</label><select class="fin" id="dAsg"><option value="">UNASSIGNED</option>${S.board.units.map(u => `<option>${esc(u.name)} (${esc(u.callsign)})</option>`).join('')}</select></div>`,
        [{ label: 'Cancel', cls: 'gray' }, { label: 'Save', run: async () => { if (!(await call('dot.fleetAssign', { vehicle: x.dataset.asg, assigned: $('#dAsg').value || null }, 'Saved'))) return false; R(); } }]));
      $$('#dFleet [data-oos]').forEach(x => x.onclick = async () => { if (await call('dot.fleetService', { vehicle: x.dataset.oos, oos: true }, 'Out of service')) R(); });
      $$('#dFleet [data-rts]').forEach(x => x.onclick = async () => { if (await call('dot.fleetService', { vehicle: x.dataset.rts, oos: false }, 'Back in service')) R(); });
    } else if (S.fsub === 'equipment') {
      el.innerHTML = `<table><thead><tr><th>Item</th><th>Total</th><th>Available</th><th>Checked Out</th><th></th></tr></thead><tbody>${f.equipment.map(e =>
        `<tr class="${e.available > 0 ? 'c-avail' : 'c-offdt'}"><td><b>${esc(e.item)}</b></td><td>${e.qty}</td><td>${e.available}</td><td class="wrap">${e.out.map(o => `${esc(o.who)} ×${o.qty} <span class="lnk" data-ret="${o.id}">Return</span>`).join('<br>') || '-'}</td><td><span class="lnk g" data-co="${e.id}" data-av="${e.available}">Check out</span></td></tr>`).join('')}</tbody></table>`;
      $$('#dFleet [data-co]').forEach(x => x.onclick = () => modal('Check out', `<div><label class="lbl">Quantity (${x.dataset.av} available)</label><input class="fin" type="number" id="dCoQ" min="1" max="${x.dataset.av}" value="1"></div>`,
        [{ label: 'Cancel', cls: 'gray' }, { label: 'Check Out', cls: 'green', run: async () => { if (!(await call('dot.checkout', { item: x.dataset.co, qty: +$('#dCoQ').value }, 'Checked out'))) return false; R(); } }]));
      $$('#dFleet [data-ret]').forEach(x => x.onclick = async () => { if (await call('dot.return', { id: +x.dataset.ret }, 'Returned')) R(); });
    } else {
      el.innerHTML = `<table><thead><tr><th>Date</th><th>Vehicle / Equipment</th><th>Work</th><th>Logged By</th><th>Status</th><th></th></tr></thead><tbody>${f.maintenance.map(m =>
        `<tr class="${m.status === 'OPEN' ? 'c-enrt' : 'c-avail'}"><td>${d24(m.at)}</td><td>${esc(m.asset)}</td><td class="wrap">${esc(m.work)}</td><td>${esc(m.logged_by)}</td><td>${m.status}</td><td>${m.status === 'OPEN' ? `<span class="lnk g" data-md="${m.id}">Mark done</span>` : ''}</td></tr>`).join('') || '<tr><td colspan="6" class="empty">No maintenance records</td></tr>'}</tbody></table><div class="actbar"><button class="btn" id="dAddMt">+ Log Maintenance</button></div>`;
      $$('#dFleet [data-md]').forEach(x => x.onclick = async () => { if (await call('dot.maintDone', { id: +x.dataset.md }, 'Marked done')) R(); });
      $('#dAddMt').onclick = () => modal('Log maintenance', `<div><label class="lbl">Vehicle / Equipment</label><select class="fin" id="dMtA">${S.cfg.fleet.map(v => `<option>${esc(v.id)}</option>`).join('')}${S.cfg.equipment.map(e => `<option>${esc(e.item)}</option>`).join('')}</select></div><div><label class="lbl">Work</label><input class="fin" id="dMtW" maxlength="255"></div><div><label class="lbl">Status</label><select class="fin" id="dMtS"><option>DONE</option><option>OPEN</option></select></div>`,
        [{ label: 'Cancel', cls: 'gray' }, { label: 'Save', run: async () => { if (!(await call('dot.maintAdd', { asset: $('#dMtA').value, work: $('#dMtW').value, status: $('#dMtS').value }, 'Logged'))) return false; R(); } }]);
    }
  }

  /* ---------------- reports ---------------- */
  let historyCache = [];
  async function renderForms(sc) {
    const forms = S.cfg.forms;
    if (!S.formKey || !forms.some(f => f.key === S.formKey)) S.formKey = forms[0].key;
    const F = forms.find(f => f.key === S.formKey);
    const pre = S.formPrefill || {};
    const ordOpts = sel => `<option value="">NONE</option>${S.board.orders.map(o => `<option value="${o.id}" ${o.id === sel ? 'selected' : ''}>WO-${o.id} - ${esc(o.category)}</option>`).join('')}${historyCache.map(h => `<option value="${h.id}">WO-${h.id} - ${esc(h.category)} (closed)</option>`).join('')}`;
    const field = f => {
      const id = 'dF_' + f.key, full = f.type === 'narr' || f.type === 'area';
      let h;
      if (f.type === 'list') h = `<select class="fin" id="${id}"><option value="">${f.required ? 'Select...' : '-'}</option>${f.options.map(o => `<option>${esc(o)}</option>`).join('')}</select>`;
      else if (f.type === 'incident') h = `<select class="fin" id="${id}">${ordOpts(pre.incident || myOrders()[0])}</select>`;
      else if (f.type === 'number') h = `<input class="fin" type="number" min="0" max="999" id="${id}">`;
      else if (f.type === 'narr') h = `<textarea class="fin" id="${id}" maxlength="4000" style="min-height:130px" placeholder="At least ${S.cfg.minNarrative} characters..."></textarea>`;
      else if (f.type === 'area') h = `<textarea class="fin" id="${id}" maxlength="1000" style="min-height:60px"></textarea>`;
      else h = `<input class="fin" id="${id}" maxlength="200">`;
      return `<div class="${full ? 'full' : ''}"><label class="lbl">${esc(f.label)}${f.required ? ' *' : ''}</label>${h}</div>`;
    };
    sc.innerHTML = `<div class="panel main"><div class="ftabs" id="dFTabs">${forms.map(f => `<button class="${f.key === S.formKey ? 'on' : ''}" data-k="${f.key}">${esc(f.label)}</button>`).join('')}</div>
        <div class="tabbody" style="border-top:1px solid var(--line-2)"><div class="formgrid"><div><label class="lbl">Author</label><input class="fin" value="${esc(S.me.short)} (${esc(S.me.callsign)}) · ${esc(S.me.dept)}" readonly></div><div><label class="lbl">Date</label><input class="fin" value="${d24(Date.now() / 1000)}" readonly></div>
        ${F.fields.map(field).join('')}<div class="full hint">Narratives need at least ${S.cfg.minNarrative} characters.${F.key === 'closure' ? ' Supervisors activate closures; your request waits for approval.' : ''}</div></div>
        <div class="actbar" style="justify-content:flex-end"><button class="btn gray" id="dFClear">Clear</button><button class="btn green" id="dFSubmit">Submit ${esc(F.label)}</button></div></div></div>
      <div class="panel side"><div class="phead"><h2>My Reports</h2></div><div class="grid"><table><thead><tr><th>Number</th><th>Type</th><th>WO#</th><th>Filed</th></tr></thead><tbody id="dMyRep"><tr><td colspan="4" class="empty">Loading...</td></tr></tbody></table></div></div>`;
    $$('#dFTabs button').forEach(b => b.onclick = () => { S.formKey = b.dataset.k; S.formPrefill = {}; renderForms(sc); });
    $('#dFClear').onclick = () => { S.formPrefill = {}; renderForms(sc); };
    $('#dFSubmit').onclick = async () => {
      const data = {};
      F.fields.forEach(f => { const el = $('#dF_' + f.key); if (!el || el.value === '') return; data[f.key] = (f.type === 'number' || f.type === 'incident') ? +el.value : el.value; });
      const btn = $('#dFSubmit'); btn.disabled = true;
      const r = await call('dot.submitReport', { form: F.key, data });
      btn.disabled = false;
      if (r) { toast(`${r.number} filed${r.note ? ' · ' + r.note : ''}`); S.formPrefill = {}; renderForms(sc); }
    };
    if (!historyCache.length) { const h = await call('dot.history'); if (h) historyCache = h.slice(0, 25); }
    const mine = await call('dot.myReports'); if (!mine || S.screen !== 'forms') return;
    const prefix = { hazard: 'RHZ', recovery: 'VRR', closure: 'RCR', inspection: 'RIN', maintdone: 'MCR', damage: 'EDR' };
    const label = k => (forms.find(f => f.key === k) || { label: k }).label;
    $('#dMyRep').innerHTML = mine.map(r => `<tr class="click c-avail" data-r="${r.id}"><td>${prefix[r.form] || 'RPT'}-${r.id}</td><td>${esc(label(r.form))}</td><td>${r.order_id ? 'WO-' + r.order_id : '-'}</td><td>${d24(r.at).slice(0, 10)}</td></tr>`).join('') || '<tr><td colspan="4" class="empty">Nothing filed yet</td></tr>';
    $$('#dMyRep [data-r]').forEach(tr => tr.onclick = async () => {
      const r = await call('dot.getReport', { id: +tr.dataset.r }); if (!r) return;
      const F2 = forms.find(f => f.key === r.form) || { fields: [], label: r.form };
      modal(`${prefix[r.form] || 'RPT'}-${r.id} · ${F2.label.toUpperCase()}`, `<div><span class="lbl">Author</span><b>${esc(r.author_label)}</b> · ${d24(r.at)}</div>` +
        F2.fields.map(f => { let v = r.data[f.key]; if (v === undefined || v === null || v === '') return ''; if (f.type === 'incident') v = 'WO-' + v;
          return `<div><span class="lbl">${esc(f.label)}</span><div style="font-weight:700;white-space:pre-wrap">${esc(v)}</div></div>`; }).join(''), [{ label: 'Close', cls: 'gray' }], true);
    });
  }

  /* ---------------- road alerts ---------------- */
  async function renderAlerts(sc) {
    const row = o => `<tr class="click ${o.priority === 1 ? 'c-p1' : 'c-avail'}" data-id="${o.id}"><td>WO-${o.id}</td><td>${esc(o.category)}</td><td class="wrap">${esc(o.address)}</td><td>${o.priority}</td><td>${esc(o.status)}</td><td>${o.units.map(u => esc(u.callsign)).join(', ')}</td><td>${age(o.createdAt)}</td></tr>`;
    const tbl = (title, color, list, empty, extra = '') => `<div class="sect" style="${color ? 'color:' + color : ''}">${title}${extra}</div><table><thead><tr><th>WO#</th><th>Category</th><th>Location</th><th>Pr.</th><th>Status</th><th>Units</th><th>Age</th></tr></thead><tbody>${list.map(row).join('') || `<tr><td colspan="7" class="empty">${empty}</td></tr>`}</tbody></table>`;
    const by = cats => S.board.orders.filter(o => cats.includes(o.category));
    const a = await call('dot.alerts'); if (!a || S.screen !== 'alerts') return;
    let html = `<div class="sect" style="color:#ff6b6b">ROAD CLOSURES <span class="lnk" id="dClNew" style="margin-left:10px">+ Road Closure Request</span></div><table><thead><tr><th>Road</th><th>Direction</th><th>Reason</th><th>Until</th><th>Detour</th><th>By</th><th>Status</th><th></th></tr></thead><tbody>${a.closures.map(c =>
      `<tr class="${c.status === 'REQUESTED' ? 'c-enrt' : 'c-offdt'}"><td><b>${esc(c.road)}</b></td><td>${esc(c.direction || '')}</td><td>${esc(c.reason)}</td><td>${esc(c.until_text || '')}</td><td>${esc(c.detour || '')}</td><td>${esc(c.created_by)}</td><td>${c.status}</td>
      <td>${c.status === 'REQUESTED' && S.me.supervisor ? `<span class="lnk g" data-cla="${c.id}">Approve</span>` : ''}${c.status === 'REQUESTED' || S.me.supervisor ? `<span class="lnk r" data-clr="${c.id}">${c.status === 'REQUESTED' ? 'Cancel' : 'Reopen road'}</span>` : ''}</td></tr>`).join('') || '<tr><td colspan="8" class="empty">No road closures</td></tr>'}</tbody></table>`;
    html += tbl('MAJOR HIGHWAY HAZARDS', '#fb923c', S.board.orders.filter(o => ['HIGHWAY HAZARDS', 'DEBRIS REMOVAL'].includes(o.category) || (o.priority === 1 && o.category === 'VEHICLE RECOVERY')), 'No major hazards');
    html += tbl('TRAFFIC CONTROL REQUESTS', '#f4d03f', by(['TRAFFIC MANAGEMENT']), 'No traffic control requests');
    html += tbl('EMERGENCY ROADSIDE REQUESTS', '#38d9f0', S.board.orders.filter(o => ['ROADSIDE ASSISTANCE', 'VEHICLE RECOVERY'].includes(o.category) && o.priority <= 2), 'No emergency roadside requests');
    html += tbl('ACTIVE CONSTRUCTION ZONES', '#a78bfa', by(['CONSTRUCTION ZONES']), 'No construction zones');
    html += `<div class="sect">DEPARTMENT ANNOUNCEMENTS${S.me.supervisor ? ' <span class="lnk" id="dAnNew" style="margin-left:10px">+ Post</span>' : ''}</div><table><thead><tr><th style="width:150px">Time</th><th style="width:170px">From</th><th>Announcement</th></tr></thead><tbody>${a.announcements.map(n =>
      `<tr><td>${d24(n.at)}</td><td>${esc(n.created_by)}</td><td class="wrap"><b style="color:#fff">${esc(n.title)}</b>${n.body ? '<br>' + esc(n.body) : ''}</td></tr>`).join('') || '<tr><td colspan="3" class="empty">No announcements</td></tr>'}</tbody></table>`;
    sc.innerHTML = `<div class="panel" style="flex:1"><div class="alerthead"><h2>${svg('alert')}Road Alerts</h2></div><div class="grid">${html}</div></div>`;
    $$('#dScreen tr[data-id]').forEach(r => r.onclick = () => openOrder(+r.dataset.id));
    const b = (id, f) => { const e = $('#' + id); if (e) e.onclick = f; };
    b('dClNew', () => { S.formKey = 'closure'; show('forms'); }); b('dAnNew', announceModal);
    $$('#dScreen [data-cla]').forEach(x => x.onclick = async () => { if (await call('dot.closureApprove', { id: +x.dataset.cla }, 'Road closed')) renderAlerts(sc); });
    $$('#dScreen [data-clr]').forEach(x => x.onclick = async () => { if (await call('dot.closureReopen', { id: +x.dataset.clr }, 'Road open')) renderAlerts(sc); });
  }

  /* ---------------- history ---------------- */
  async function renderHistory(sc) {
    sc.innerHTML = '<div class="panel" style="flex:1"><div class="phead"><h2>Completed Work Orders</h2><span class="sub">Last 100</span></div><div class="grid"><table><thead><tr><th>WO#</th><th>Category</th><th>Pr.</th><th>Location</th><th>Requested By</th><th>Units</th><th>Opened</th><th>Closed</th><th>Disposition</th></tr></thead><tbody id="dHist"><tr><td colspan="9" class="empty">Loading...</td></tr></tbody></table></div></div>';
    const rows = await call('dot.history'); if (!rows || S.screen !== 'history') return;
    historyCache = rows.slice(0, 25);
    $('#dHist').innerHTML = rows.map(h => `<tr class="click ${h.priority === 1 ? 'c-p1' : 'c-avail'}" data-id="${h.id}"><td>WO-${h.id}</td><td>${esc(h.category)}</td><td>${h.priority}</td><td>${esc(h.street || '')}</td><td>${esc(h.requester || '')}</td><td>${esc(h.units || '')}</td><td>${d24(h.createdAt)}</td><td>${h.closedAt ? d24(h.closedAt) : ''}</td><td>${esc(h.disposition || '')}</td></tr>`).join('') || '<tr><td colspan="9" class="empty">Nothing completed yet</td></tr>';
    $$('#dHist tr[data-id]').forEach(r => r.onclick = () => openOrder(+r.dataset.id));
  }

  /* ---------------- crew roster ---------------- */
  async function renderMgmt(sc) {
    const tabs = [['roster', 'Crew Roster'], ['certs', 'Certifications']];
    const sup = S.me.supervisor;
    sc.innerHTML = `<div class="panel" style="flex:1"><div class="ftabs">${tabs.map(t => `<button class="${t[0] === S.sub ? 'on' : ''}" data-sub="${t[0]}">${t[1]}</button>`).join('')}<span class="hint" style="margin-left:auto;align-self:center;padding-right:8px">${sup ? 'Supervisor: you can edit' : 'Read only · supervisors can edit'}</span></div><div class="grid" id="dMgmt" style="border-top:1px solid var(--line-2)"><div class="empty">Loading...</div></div></div>`;
    $$('#dScreen [data-sub]').forEach(b => b.onclick = () => { S.sub = b.dataset.sub; renderMgmt(sc); });
    const rows = await call('dot.roster'); if (!rows || S.screen !== 'mgmt') return;
    const el = $('#dMgmt');
    if (S.sub === 'roster') {
      el.innerHTML = `<table><thead><tr><th>Name</th><th>Callsign</th><th>Status</th><th>Vehicle</th><th>Certifications</th><th>Last Seen</th></tr></thead><tbody>${rows.map(r =>
        `<tr class="${r.onDuty ? stCls(r.onDuty.status) : 'c-dim'}"><td><b>${esc(r.name)}</b></td><td>${esc(r.callsign || '')}</td><td>${r.onDuty ? 'ON DUTY · ' + r.onDuty.status : 'OFF DUTY'}</td><td>${esc((r.onDuty && r.onDuty.vehicle) || '-')}</td><td class="wrap">${esc((r.certs || []).join(', ') || '-')}</td><td>${d24(r.seen).slice(0, 10)}</td></tr>`).join('') || '<tr><td colspan="6" class="empty">No members yet. Members are added the first time they open the DOT CAD.</td></tr>'}</tbody></table>
        <div class="hint" style="padding:8px 12px">Who can go on duty as DOT, and who is a supervisor, is set with ACE permissions (unitlink.dot.duty / unitlink.dot.supervisor).</div>`;
      return;
    }
    el.innerHTML = `<table><thead><tr><th>Name</th>${S.cfg.certifications.map(c => `<th style="text-align:center">${esc(c)}</th>`).join('')}</tr></thead><tbody>${rows.map(r =>
      `<tr><td><b>${esc(r.name)}</b></td>${S.cfg.certifications.map(c => `<td style="text-align:center" class="${sup ? 'click' : ''}" data-c="${r.member_id}|${esc(c)}">${(r.certs || []).includes(c) ? '<span style="color:var(--avail)">✔</span>' : '<span style="color:var(--dim)">-</span>'}</td>`).join('')}</tr>`).join('') || '<tr><td class="empty">No members yet</td></tr>'}</tbody></table>
      ${sup ? '<div class="hint" style="padding:8px 12px">Click a cell to grant or remove a certification.</div>' : ''}`;
    if (sup) $$('#dMgmt [data-c]').forEach(x => x.onclick = async () => {
      const [mid, c] = x.dataset.c.split('|'); const r = rows.find(z => z.member_id === +mid);
      const certs = (r.certs || []).includes(c) ? r.certs.filter(z => z !== c) : [...(r.certs || []), c];
      if (await call('dot.setCerts', { member: +mid, certs })) renderMgmt(sc);
    });
  }

  /* ---------------- lifecycle ---------------- */
  UL.on('openDot', m => { const d = m.data; S.cfg = d; S.me = d.me; S.board = d.board; S.screen = 'cad'; S.data = null; $('#dot').classList.add('on'); show('cad'); if (window.ULTools) ULTools.attach('dot', d.me, chrome); });
  UL.on('closeDot', () => { $('#dot').classList.remove('on'); closeModal(); if (window.ULTools) ULTools.close(); });
  UL.on('dotPush', m => {
    if (!S.cfg) return;
    if (m.kind === 'dotBoard') applyBoard(m.data);
    if (m.kind === 'dotNote' && S.data && (S.data.order || S.data.closed || {}).id === m.data.id) { S.data.notes.push(m.data.note); if (S.screen === 'call' && S.tab === 'notes') renderTabs(); }
    if (m.kind === 'dotClosed' && S.data && S.data.order && S.data.order.id === m.data.id) { toast(`WO-${m.data.id} completed by ${m.data.by}`); if (S.screen === 'call') loadOrder(m.data.id).then(ok => ok && renderOrder($('#dScreen'))); }
    if (m.kind === 'dotAlerts' && S.screen === 'alerts') renderAlerts($('#dScreen'));
  });
  $('#dClose').onclick = () => UL.req('close');
  document.addEventListener('keydown', e => {
    if (e.key !== 'Escape' || !$('#dot').classList.contains('on')) return;
    if ($('#dModal').classList.contains('on')) return closeModal();
    if (window.ULTools && ULTools.isOpen()) return ULTools.close();
    UL.req('close');
  });
  setInterval(() => { const d = new Date(); $('#dClock').textContent = `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`; }, 1000);
})();
