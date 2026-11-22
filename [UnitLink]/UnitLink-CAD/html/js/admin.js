/* UnitLink Admin Dashboard (/cadadmin). Same look as the department CADs.
   Server: 'admin.*' requests (server/admin.lua), ACE unitlink.admin only.
   Departments and permissions are read only; they live in config + server.cfg. */
(() => {
  'use strict';
  const $ = s => document.querySelector(s), $$ = s => [...document.querySelectorAll(s)];
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[c]));
  const pad = n => String(n).padStart(2, '0');
  const d24 = sec => { const d = new Date(sec * 1000); return `${pad(d.getMonth()+1)}/${pad(d.getDate())}/${d.getFullYear()} ${pad(d.getHours())}:${pad(d.getMinutes())}`; };
  const I = {
    dash:'<rect x="3" y="3" width="8" height="8" rx="1"/><rect x="13" y="3" width="8" height="5" rx="1"/><rect x="13" y="10" width="8" height="11" rx="1"/><rect x="3" y="13" width="8" height="8" rx="1"/>',
    station:'<path d="M3 21V9l9-6 9 6v12"/><path d="M9 21v-6h6v6"/>', app:'<rect x="4" y="3" width="16" height="18" rx="2"/><path d="M8 8h8M8 12h8M8 16h5"/>',
    people:'<circle cx="9" cy="8" r="3"/><path d="M3 20a6 6 0 0112 0M16 4a3 3 0 010 6M21 20a6 6 0 00-4-5.6"/>', laws:'<path d="M12 3v18M5 7h14M7 7l-3 7a3 3 0 006 0zM17 7l-3 7a3 3 0 006 0z"/>',
    gear:'<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M2 12h3M19 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1"/>',
    key:'<circle cx="8" cy="15" r="4"/><path d="M11 12l9-9M17 6l3 3"/>', act:'<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>', audit:'<path d="M6 3h9l3 3v15H6z"/><path d="M9 12l2 2 4-4"/>',
    search:'<circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/>',
  };
  const svg = (n, c) => `<svg viewBox="0 0 24 24" ${c ? `style="--ic:${c}"` : ''}>${I[n]}</svg>`;
  const TILES = [['overview', 'Overview', '#fff', 'dash'], ['depts', 'Departments', '#9cc3ff', 'station'], ['apps', 'Applications', '#3ee06a', 'app'], ['civs', 'Civilians', '#ffd257', 'people'], ['|'],
    ['laws', 'Laws & Fines', '#ffd257', 'laws'], ['settings', 'Settings', '#fff', 'gear'], ['perms', 'Permissions', '#ff6b6b', 'key'], ['|'], ['activity', 'Activity', '#9cc3ff', 'act'], ['audit', 'Audit Log', '#9cc3ff', 'audit']];
  const TITLES = { overview: 'Overview', depts: 'Departments', apps: 'Civilian Applications', civs: 'Civilians', laws: 'Laws & Fines', settings: 'Settings', perms: 'Permissions (read only)', activity: 'Employee Activity', audit: 'Admin Audit Log' };
  const A = { cfg: null, screen: 'overview', appStatus: 'PENDING', cq: '', civ: null, lq: '', aq: '' };

  let toastTimer;
  const toast = (msg, err) => { const t = $('#aToast'); t.textContent = msg; t.className = 'toast on' + (err ? ' err' : ''); clearTimeout(toastTimer); toastTimer = setTimeout(() => t.className = 'toast', 2800); };
  async function call(action, payload, ok) {
    const r = await UL.req(action, payload);
    if (!r || !r.ok) { toast((r && r.data) || 'Request failed.', true); return null; }
    if (ok) toast(ok);
    return r.data === undefined ? true : r.data;
  }
  function modal(title, body, buttons) {
    $('#amTitle').textContent = title; $('#amBody').innerHTML = body;
    $('#amFoot').innerHTML = buttons.map((b, i) => `<button class="btn ${b.cls || ''}" data-i="${i}">${b.label}</button>`).join('');
    $$('#amFoot button').forEach(el => el.onclick = async () => { const b = buttons[+el.dataset.i]; if (!b.run || (await b.run()) !== false) $('#aModal').classList.remove('on'); });
    $('#aModal').classList.add('on');
  }
  const table = (head, rows, empty) => `<table><thead><tr>${head.map(h => `<th>${h}</th>`).join('')}</tr></thead><tbody>${rows.join('') || `<tr><td colspan="${head.length}" class="empty">${empty}</td></tr>`}</tbody></table>`;
  const stCls = s => ({ VALID: 'c-avail', ACTIVE: 'c-avail', APPROVED: 'c-avail', PENDING: 'c-enrt', STOLEN: 'c-p1', SUSPENDED: 'c-p1', REVOKED: 'c-p1', DENIED: 'c-p1', IMPOUNDED: 'c-p1' })[s] || 'c-dim';
  const loading = '<div class="empty">Loading...</div>';

  function chrome() {
    const o = A.cfg.overview;
    $('#aToolbar').innerHTML = TILES.map(t => t[0] === '|' ? '<div class="gap"></div>' : `<div class="tile ${t[0] === A.screen ? 'on' : ''}" data-t="${t[0]}">${svg(t[3], t[2])}${t[1]}${t[0] === 'apps' && o.pendingApps ? `<i class="badge">${o.pendingApps}</i>` : ''}</div>`).join('') + '<div class="seal"><div>ADMIN</div></div>';
    $$('#aToolbar .tile').forEach(el => el.onclick = () => show(el.dataset.t));
    $('#aTitle').textContent = 'Admin Dashboard · ' + TITLES[A.screen];
    $('#asWho').textContent = `Admin: ${A.cfg.who}`;
    $('#asPending').textContent = `Pending applications: ${o.pendingApps}`;
    $('#asIdentity').textContent = `Identity: ${A.cfg.identity === 'core' ? 'UnitLink-Core' : 'Standalone profiles'}`;
  }
  async function refreshOverview() { const o = await call('admin.overview'); if (o) { A.cfg.overview = o; chrome(); } return o; }
  function show(s) {
    A.screen = s;
    const sc = $('#aScreen'); sc.className = 'fscreen adm-' + s;
    ({ overview: renderOverview, depts: renderDepts, apps: renderApps, civs: renderCivs, laws: renderLaws, settings: renderSettings, perms: renderPerms, activity: renderActivity, audit: renderAudit })[s](sc);
    chrome();
  }

  /* ---- overview ---- */
  async function renderOverview(sc) {
    const o = A.cfg.overview;
    const tile = (n, label, cls) => `<div class="stat ${cls || ''}"><b>${n}</b><span>${label}</span></div>`;
    sc.innerHTML = `<div class="panel" style="flex:0 0 auto"><div class="stats">${tile(o.onDuty, 'Units On Duty', 'g')}${tile(o.policeCalls, 'Active Police Calls')}${tile(o.fireActive, 'Active SAFR Incidents')}${tile(o.dotOpen, 'Open DOT Work Orders')}${tile(o.pendingApps, 'Pending Applications', o.pendingApps ? 'y' : '')}${tile(o.warrants, 'Active Warrants', o.warrants ? 'r' : '')}${tile(o.bolos, 'Active BOLOs', o.bolos ? 'r' : '')}${tile(o.civilians, 'Civilians')}${tile(o.vehicles, 'Registered Vehicles')}${tile(o.records24, 'Records (24h)')}${tile(o.employees, 'Employees')}</div></div>
      <div style="display:flex;gap:8px;flex:1;min-height:0"><div class="panel" style="flex:1;min-width:0"><div class="phead"><h2>On Duty by Department</h2></div><div class="grid">${table(['Department', 'Name', 'Type', 'On Duty'], o.departments.map(d => `<tr class="${d.onDuty ? 'c-avail' : 'c-dim'}"><td><b>${esc(d.short)}</b></td><td>${esc(d.name)}</td><td>${esc(String(d.type).toUpperCase())}</td><td>${d.onDuty}</td></tr>`), 'UnitLink-Police is not running')}</div></div>
      <div class="panel" style="flex:1;min-width:0"><div class="phead"><h2>Recent Admin Changes</h2></div><div class="grid">${table(['Time', 'Admin', 'Area', 'Change'], o.recentAudit.map(a => `<tr><td>${d24(a.at)}</td><td>${esc(a.admin)}</td><td>${esc(a.area.toUpperCase())}</td><td class="wrap">${esc(a.change_text)}</td></tr>`), 'No changes yet')}</div></div></div>`;
  }

  /* ---- departments (read only) ---- */
  function renderDepts(sc) {
    const o = A.cfg.overview;
    sc.innerHTML = `<div class="panel" style="flex:1"><div class="phead"><h2>Departments</h2><span class="sub">Read only · set in UnitLink-Police config/departments.lua and config/permissions.lua</span></div>
      <div class="grid">${table(['Key', 'Short', 'Name', 'Type', 'Callsign Example', 'Duty ACE', 'Supervisor ACE', 'On Duty'], o.departments.map(d => `<tr class="${d.onDuty ? 'c-avail' : ''}"><td>${esc(d.key)}</td><td><b>${esc(d.short)}</b></td><td>${esc(d.name)}</td><td>${esc(String(d.type).toUpperCase())}</td><td>${esc(d.callsignExample || '')}</td><td><code>${esc(d.duty || '')}</code></td><td><code>${esc(d.supervisor || '')}</code></td><td>${d.onDuty}</td></tr>`), 'UnitLink-Police is not running')}</div>
      <div class="hint" style="padding:8px 12px">To let someone go on duty, give them the duty ACE in server.cfg (see aceperms.md). Supervisor ACE unlocks approvals and announcements.</div></div>`;
  }

  /* ---- applications ---- */
  async function renderApps(sc) {
    const tabs = ['PENDING', 'APPROVED', 'DENIED'];
    sc.innerHTML = `<div class="panel" style="flex:1"><div class="ftabs">${tabs.map(t => `<button class="${A.appStatus === t ? 'on' : ''}" data-as="${t}">${t[0] + t.slice(1).toLowerCase()}</button>`).join('')}</div><div class="grid" id="aApps" style="border-top:1px solid var(--line-2)">${loading}</div></div>`;
    $$('#aScreen [data-as]').forEach(b => b.onclick = () => { A.appStatus = b.dataset.as; renderApps(sc); });
    const rows = await call('admin.apps', { status: A.appStatus }); if (!rows || A.screen !== 'apps') return;
    const detail = a => a.type === 'vehicle' ? `${esc(a.data.plate)} · ${esc(a.data.color)} ${esc(a.data.model)}` : a.type === 'business' ? `${esc(a.data.name)} · ${esc(a.data.btype)}` : '-';
    const pending = A.appStatus === 'PENDING';
    $('#aApps').innerHTML = table(['#', 'Submitted', 'Civilian', 'Application', 'Details', ...(pending ? [''] : ['Reviewed By', 'Reason'])], rows.map(a => `<tr class="${stCls(a.status)}"><td>${a.id}</td><td>${d24(a.at)}</td><td><b>${esc(a.civ_name)}</b> <span class="hint">#${a.civ_id}</span></td><td>${esc(a.label)}</td><td>${detail(a)}</td>${pending
      ? `<td style="white-space:nowrap"><button class="btn green" data-ok="${a.id}">Approve</button> <button class="btn red" data-no="${a.id}">Deny</button></td>`
      : `<td>${esc(a.reviewed_by || '')}</td><td class="wrap">${esc(a.reason || '')}</td>`}</tr>`), pending ? 'Nothing waiting. Nice.' : 'Nothing here');
    $$('#aApps [data-ok]').forEach(b => b.onclick = async () => { if (await call('admin.review', { id: +b.dataset.ok, approve: true }, 'Approved')) { await refreshOverview(); renderApps(sc); } });
    $$('#aApps [data-no]').forEach(b => b.onclick = () => modal('Deny application', '<div><label class="lbl">Reason (the civilian sees this)</label><input class="fin" id="aDenyR" maxlength="255"></div>',
      [{ label: 'Cancel', cls: 'gray' }, { label: 'Deny', cls: 'red', run: async () => { if (!(await call('admin.review', { id: +b.dataset.no, approve: false, reason: $('#aDenyR').value }, 'Denied'))) return false; await refreshOverview(); renderApps(sc); } }]));
  }

  /* ---- civilians ---- */
  async function renderCivs(sc) {
    sc.innerHTML = `<div class="panel" style="flex:0 0 46%"><div class="phead"><h2>Civilians</h2></div><form class="sform" id="aCivF"><input class="fin" id="aCq" placeholder="Name or ID (blank = newest)" value="${esc(A.cq)}"><button class="btn">Search</button></form><div class="grid" id="aCivs" style="border-top:0">${loading}</div></div>
      <div class="panel" style="flex:1;min-width:0"><div class="phead"><h2>Civilian Record</h2></div><div class="grid" id="aCiv"><div class="empty">Pick a civilian.</div></div></div>`;
    $('#aCivF').onsubmit = e => { e.preventDefault(); A.cq = $('#aCq').value.trim(); loadCivs(); };
    loadCivs(); if (A.civ) loadCiv(A.civ);
  }
  async function loadCivs() {
    const rows = await call('admin.civilians', { q: A.cq }); if (!rows || A.screen !== 'civs') return;
    $('#aCivs').innerHTML = table(['ID', 'Name', 'DOB', 'Sex'], rows.map(c => `<tr class="click ${c.id === A.civ ? 'sel' : ''}" data-c="${c.id}"><td>${c.id}</td><td><b>${esc(c.name)}</b></td><td>${esc(c.dob)}</td><td>${esc(String(c.gender || '')[0] || '')}</td></tr>`), 'No civilians found');
    $$('#aCivs [data-c]').forEach(tr => tr.onclick = () => { A.civ = +tr.dataset.c; $$('#aCivs tr').forEach(x => x.classList.toggle('sel', x === tr)); loadCiv(A.civ); });
  }
  async function loadCiv(id) {
    const c = await call('admin.civilian', { id }); if (!c || A.screen !== 'civs') return;
    const st = A.cfg.licenseStatuses, vs = A.cfg.vehicleStatuses;
    $('#aCiv').innerHTML = `<div class="sect">${esc(c.name.toUpperCase())} · #${c.id} · DOB ${esc(c.dob)} · ${c.records} RECORDS</div>
      ${table(['License', 'Status', 'Points', ''], c.licenses.map(l => `<tr class="${stCls(l.status)}"><td><b>${esc(l.label)}</b></td><td><select class="cellsel" id="aLs_${l.key}">${st.map(s => `<option ${s === l.status ? 'selected' : ''}>${s}</option>`).join('')}</select></td>
        <td>${l.key === 'drivers' ? `<input class="fin" type="number" min="0" max="99" id="aLp_${l.key}" value="${l.points}" style="width:70px;padding:2px 6px"> / ${c.suspendAt}` : '-'}</td><td><span class="lnk g" data-sl="${l.key}">Save</span></td></tr>`), '')}
      <div class="sect">VEHICLES</div>${table(['Plate', 'Model', 'Color', 'Status'], c.vehicles.map(v => `<tr class="${stCls(v.status)}"><td><b>${esc(v.plate)}</b></td><td>${esc(v.model)}</td><td>${esc(v.color)}</td><td><select class="cellsel" data-veh="${v.id}">${vs.map(s => `<option ${s === v.status ? 'selected' : ''}>${s}</option>`).join('')}</select></td></tr>`), 'No vehicles')}
      <div class="sect">BUSINESSES</div>${table(['Name', 'Type', 'Status'], c.businesses.map(b => `<tr class="${stCls(b.status)}"><td><b>${esc(b.name)}</b></td><td>${esc(b.type)}</td><td>${esc(b.status)}</td></tr>`), 'No businesses')}`;
    $$('#aCiv [data-sl]').forEach(x => x.onclick = async () => { const k = x.dataset.sl, p = $('#aLp_' + k); if (await call('admin.setLicense', { id: c.id, key: k, status: $('#aLs_' + k).value, points: p ? +p.value : undefined }, 'License saved')) loadCiv(c.id); });
    $$('#aCiv [data-veh]').forEach(s => s.onchange = async () => { if (await call('admin.setVehicle', { id: +s.dataset.veh, status: s.value }, 'Vehicle saved')) loadCiv(c.id); });
  }

  /* ---- laws & fines ---- */
  async function renderLaws(sc) {
    sc.innerHTML = `<div class="panel" style="flex:1"><div class="phead"><h2>Laws & Fines</h2><span class="sub">Fines are records only, nobody is ever charged. Changes apply right away and survive restarts.</span><div class="tools"><div class="pill">${svg('search')}<input id="aLq" placeholder="Code or offense..." value="${esc(A.lq)}"></div></div></div><div class="grid" id="aLaws">${loading}</div></div>`;
    let t; $('#aLq').oninput = e => { clearTimeout(t); t = setTimeout(() => { A.lq = e.target.value; drawLaws(); }, 150); };
    const d = await call('admin.laws'); if (!d || A.screen !== 'laws') return;
    A.laws = d; drawLaws();
  }
  function drawLaws() {
    const d = A.laws, q = A.lq.toLowerCase();
    if (!d) return;
    $('#aLaws').innerHTML = table(['Code', 'Offense', 'Class', `Fine (${esc(d.symbol)})`, 'License Points', ''], d.laws.filter(l => !q || (l.code + ' ' + l.offense).toLowerCase().includes(q)).map(l => `<tr class="${l.changed ? 'c-enrt' : ''}"><td>${esc(l.code)}</td><td>${esc(l.offense)}</td><td>${esc(l.class)}</td>
      <td><input class="fin" type="number" min="0" data-lf="${esc(l.code)}" value="${l.fine}" style="width:100px;padding:2px 6px"></td><td><input class="fin" type="number" min="0" max="50" data-lp="${esc(l.code)}" value="${l.points}" style="width:70px;padding:2px 6px"></td>
      <td><span class="lnk g" data-ls="${esc(l.code)}">Save</span>${l.changed ? `<span class="lnk" data-lr="${esc(l.code)}" title="Default ${l.defaultFine} / ${l.defaultPoints} pts">Reset</span>` : ''}</td></tr>`), 'No laws match');
    const reload = async () => { const n = await call('admin.laws'); if (n) { A.laws = n; drawLaws(); } };
    $$('#aLaws [data-ls]').forEach(x => x.onclick = async () => { const c = x.dataset.ls; if (await call('admin.setLaw', { code: c, fine: +$(`[data-lf="${CSS.escape(c)}"]`).value, points: +$(`[data-lp="${CSS.escape(c)}"]`).value }, `${c} saved`)) reload(); });
    $$('#aLaws [data-lr]').forEach(x => x.onclick = async () => { if (await call('admin.setLaw', { code: x.dataset.lr, reset: true }, 'Reset to default')) reload(); });
  }

  /* ---- settings ---- */
  async function renderSettings(sc) {
    sc.innerHTML = `<div class="panel" style="flex:1"><div class="phead"><h2>Settings</h2><span class="sub">Saved in the database, applied right away and on every restart. Everything else is in config.lua.</span></div><div class="grid" id="aSet">${loading}</div></div>`;
    const rows = await call('admin.settings'); if (!rows || A.screen !== 'settings') return;
    const groups = [...new Set(rows.map(r => r.group))];
    $('#aSet').innerHTML = groups.map(g => `<div class="sect">${esc(g.toUpperCase())}</div>` + table(['Setting', 'Value', ''], rows.filter(r => r.group === g).map(r => `<tr><td>${esc(r.label)}</td><td>${r.type === 'bool'
      ? `<select class="cellsel" data-sv="${r.key}"><option value="true" ${r.value ? 'selected' : ''}>ON</option><option value="false" ${!r.value ? 'selected' : ''}>OFF</option></select>`
      : `<input class="fin" type="number" min="${r.min}" max="${r.max}" data-sv="${r.key}" value="${r.value}" style="width:90px;padding:2px 6px"> <span class="hint">${r.min} to ${r.max}</span>`}</td><td><span class="lnk g" data-ss="${r.key}">Save</span></td></tr>`), '')).join('');
    $$('#aSet [data-ss]').forEach(x => x.onclick = async () => { const el = $(`[data-sv="${x.dataset.ss}"]`); const v = el.tagName === 'SELECT' ? el.value === 'true' : +el.value; if (await call('admin.setSetting', { key: x.dataset.ss, value: v }, 'Saved')) renderSettings(sc); });
  }

  /* ---- permissions (read only) ---- */
  async function renderPerms(sc) {
    sc.innerHTML = `<div class="panel" style="flex:1"><div class="phead"><h2>Permissions</h2><span class="sub">Read only · who online has which UnitLink ACE. Change them in server.cfg (see aceperms.md).</span><div class="tools"><button class="btn gray" id="aPermR">Refresh</button></div></div><div class="grid" id="aPerms">${loading}</div></div>`;
    $('#aPermR').onclick = () => renderPerms(sc);
    const d = await call('admin.perms'); if (!d || A.screen !== 'perms') return;
    $('#aPerms').innerHTML = table(['ID', 'Player', 'Playing As', ...d.nodes.map(n => `<span title="${esc(n.node)}">${esc(n.label)}</span>`)], d.players.map(p => `<tr><td>${p.src}</td><td><b>${esc(p.name || '')}</b></td><td>${esc(p.civ || '-')}</td>${p.has.map(h => `<td style="text-align:center">${h ? '<span style="color:var(--avail)">✔</span>' : '<span style="color:var(--dim)">-</span>'}</td>`).join('')}</tr>`), 'Nobody online') +
      `<div class="hint" style="padding:8px 12px">Columns: ${d.nodes.map(n => `${esc(n.label)} = <code>${esc(n.node)}</code>`).join(' · ')}</div>`;
  }

  /* ---- activity + audit ---- */
  async function renderActivity(sc) {
    sc.innerHTML = `<div class="panel" style="flex:1"><div class="phead"><h2>Employee Activity</h2><span class="sub">Every department · last 200</span><div class="tools"><div class="pill">${svg('search')}<input id="aAq" placeholder="Name, unit, dept, action..." value="${esc(A.aq)}"></div></div></div><div class="grid" id="aAct">${loading}</div></div>`;
    let t; $('#aAq').oninput = e => { clearTimeout(t); t = setTimeout(() => { A.aq = e.target.value; loadActivity(); }, 250); };
    loadActivity();
  }
  async function loadActivity() {
    const rows = await call('admin.activity', { q: A.aq }); if (!rows || A.screen !== 'activity') return;
    $('#aAct').innerHTML = table(['Time', 'Employee', 'Unit', 'Dept', 'Action'], rows.map(a => `<tr><td>${d24(a.at)}</td><td>${esc(a.name)}</td><td>${esc(a.callsign || '')}</td><td>${esc(a.dept || '')}</td><td class="wrap">${esc(a.action)}</td></tr>`), 'No activity');
  }
  async function renderAudit(sc) {
    sc.innerHTML = `<div class="panel" style="flex:1"><div class="phead"><h2>Admin Audit Log</h2><span class="sub">Every change made in this dashboard</span></div><div class="grid" id="aAud">${loading}</div></div>`;
    const rows = await call('admin.audit'); if (!rows || A.screen !== 'audit') return;
    $('#aAud').innerHTML = table(['Time', 'Admin', 'Area', 'Change'], rows.map(a => `<tr><td>${d24(a.at)}</td><td>${esc(a.admin)}</td><td>${esc(a.area.toUpperCase())}</td><td class="wrap">${esc(a.change_text)}</td></tr>`), 'No changes yet');
  }

  UL.on('openAdmin', m => { A.cfg = m.data; $('#admin').classList.add('on'); show('overview'); });
  UL.on('closeAdmin', () => { $('#admin').classList.remove('on'); $('#aModal').classList.remove('on'); });
  $('#aClose').onclick = () => UL.req('close');
  document.addEventListener('keydown', e => {
    if (e.key !== 'Escape' || !$('#admin').classList.contains('on')) return;
    if ($('#aModal').classList.contains('on')) return $('#aModal').classList.remove('on');
    UL.req('close');
  });
  setInterval(() => { const d = new Date(); $('#aClock').textContent = `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`; }, 1000);
})();
