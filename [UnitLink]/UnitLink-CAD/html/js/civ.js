/* UnitLink Civilian Portal (/civ). Same look as the department CADs.
   Profiles, dashboard, 911, records, vehicles, applications, service requests.
   Server: 'civ.*' requests (server/identity.lua + server/civ.lua). No money anywhere:
   fines are shown as records and expire on their own. */
(() => {
  'use strict';
  const $ = s => document.querySelector(s), $$ = s => [...document.querySelectorAll(s)];
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[c]));
  const pad = n => String(n).padStart(2, '0');
  const d24 = sec => { const d = new Date(sec * 1000); return `${pad(d.getMonth()+1)}/${pad(d.getDate())}/${d.getFullYear()} ${pad(d.getHours())}:${pad(d.getMinutes())}`; };
  const day = sec => d24(sec).slice(0, 10);
  const age = dob => { const d = new Date(dob); if (isNaN(d)) return ''; const n = new Date(); let a = n.getFullYear() - d.getFullYear(); if (n < new Date(n.getFullYear(), d.getMonth(), d.getDate())) a--; return a; };
  const I = {
    dash:'<rect x="3" y="3" width="8" height="8" rx="1"/><rect x="13" y="3" width="8" height="5" rx="1"/><rect x="13" y="10" width="8" height="11" rx="1"/><rect x="3" y="13" width="8" height="8" rx="1"/>',
    phone:'<path d="M5 4h4l2 5-2.5 1.5a11 11 0 005 5L15 13l5 2v4a2 2 0 01-2 2A16 16 0 013 6a2 2 0 012-2"/>',
    rec:'<path d="M6 3h9l3 3v15H6z"/><path d="M9 10h6M9 14h6M9 18h3"/>', car:'<path d="M3 13l2-6h14l2 6v5h-3v-2H6v2H3z"/><circle cx="7.5" cy="13.5" r="1"/><circle cx="16.5" cy="13.5" r="1"/>',
    app:'<rect x="4" y="3" width="16" height="18" rx="2"/><path d="M8 8h8M8 12h8M8 16h5"/>', cone:'<path d="M9 4h6l4 15H5z"/><path d="M4 20h16M8 10h8M7 14h10"/>',
    id:'<rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="9" cy="12" r="2.5"/><path d="M14 10h4M14 14h4"/>', plus:'<circle cx="12" cy="12" r="9"/><path d="M12 8v8M8 12h8"/>',
  };
  const svg = (n, c) => `<svg viewBox="0 0 24 24" ${c ? `style="--ic:${c}"` : ''}>${I[n]}</svg>`;
  const TILES = [['dash', 'Dashboard', '#fff', 'dash'], ['call', '911', '#ff6b6b', 'phone'], ['records', 'My Records', '#ffd257', 'rec'], ['vehicles', 'Vehicles', '#9cc3ff', 'car'],
    ['apps', 'Applications', '#3ee06a', 'app'], ['service', 'Service Requests', '#fb923c', 'cone'], ['|'], ['profiles', 'Profiles', '#ffd257', 'id'], ['new', 'New Profile', '#3ee06a', 'plus']];
  const TITLES = { dash: 'Dashboard', call: 'Emergency 911', records: 'My Records', vehicles: 'Vehicles & Businesses', apps: 'Applications', service: 'DOT Service Requests', profiles: 'My Profiles', new: 'New Profile' };
  const C = { data: null, screen: 'dash', sel: null, svc: 'POLICE', recTab: 'citations' };

  let toastTimer;
  const toast = (msg, err) => { const t = $('#civToast'); t.textContent = msg; t.className = 'toast on' + (err ? ' err' : ''); clearTimeout(toastTimer); toastTimer = setTimeout(() => t.className = 'toast', 3000); };
  async function call(action, payload, ok) {
    const r = await UL.req(action, payload);
    if (!r || !r.ok) { toast((r && r.data) || 'Request failed.', true); return null; }
    if (ok) toast(ok);
    return r.data === undefined ? true : r.data;
  }
  function modal(title, body, buttons) {
    $('#cmTitle').textContent = title; $('#cmBody').innerHTML = body;
    $('#cmFoot').innerHTML = buttons.map((b, i) => `<button class="btn ${b.cls || ''}" data-i="${i}">${b.label}</button>`).join('');
    $$('#cmFoot button').forEach(el => el.onclick = async () => { const b = buttons[+el.dataset.i]; if (!b.run || (await b.run()) !== false) $('#cModal').classList.remove('on'); });
    $('#cModal').classList.add('on');
  }
  async function reload() { const d = await call('civ.portal'); if (d) { C.data = d; show(C.screen); } }
  const core = () => C.data.mode === 'core';
  const dash = () => C.data.dash;
  const money = n => `${C.data.cfg.fines.symbol}${Number(n || 0).toLocaleString()}`;
  const table = (head, rows, empty) => `<table><thead><tr>${head.map(h => `<th>${h}</th>`).join('')}</tr></thead><tbody>${rows.join('') || `<tr><td colspan="${head.length}" class="empty">${empty}</td></tr>`}</tbody></table>`;
  const stCls = s => ({ VALID: 'c-avail', ACTIVE: 'c-avail', APPROVED: 'c-avail', PENDING: 'c-enrt', OUTSTANDING: 'c-enrt', STOLEN: 'c-p1', SUSPENDED: 'c-p1', REVOKED: 'c-p1', DENIED: 'c-p1', IMPOUNDED: 'c-p1' })[s] || 'c-dim';

  /* ---------------- chrome ---------------- */
  function tileOff(t) {
    if (t === 'new') return core() || C.data.profiles.length >= C.data.max;
    if (t === 'profiles') return core();
    if (t === 'service' && !C.data.cfg.dot) return true;
    return !dash();
  }
  function chrome() {
    $('#civTiles').innerHTML = TILES.map(t => t[0] === '|' ? '<div class="gap"></div>' : `<div class="tile ${tileOff(t[0]) ? 'off' : ''} ${t[0] === C.screen ? 'on' : ''}" data-s="${t[0]}">${svg(t[3], t[2])}${t[1]}</div>`).join('');
    $$('#civTiles .tile').forEach(el => el.onclick = () => { if (!el.classList.contains('off')) show(el.dataset.s); });
    $('#civActive').textContent = dash() ? dash().profile.name.toUpperCase() : 'NO PROFILE';
    $('#civCount').textContent = core() ? 'Character: UnitLink-Core' : `Profiles: ${C.data.profiles.length} / ${C.data.max}`;
    const w = dash() ? dash().warrants.length : 0;
    $('#civWarn').style.display = w ? '' : 'none'; $('#civWarn').textContent = `${w} ACTIVE WARRANT${w > 1 ? 'S' : ''}`;
    $('#civTitle').textContent = 'Civilian Portal · ' + TITLES[C.screen];
  }
  function show(s) {
    if (!dash() && !['profiles', 'new'].includes(s)) s = core() ? 'dash' : (C.data.profiles.length ? 'profiles' : 'new');
    C.screen = s;
    const el = $('#civBody'); el.className = 'fscreen civ-' + s;
    if (!dash() && core()) { el.innerHTML = '<div class="panel" style="flex:1"><div class="empty">No character loaded.</div></div>'; return chrome(); }
    ({ dash: renderDash, call: renderCall, records: renderRecords, vehicles: renderVehicles, apps: renderApps, service: renderService, profiles: renderProfiles, new: renderNew })[s](el);
    chrome();
  }

  /* ---------------- dashboard ---------------- */
  function idCard(p, lic, suspendAt) {
    const L = k => lic.find(l => l.key === k), st = l => l.status === 'VALID' ? l.status : `<span class="r">${esc(l.status)}</span>`;
    return `<span class="hd">*** SAN ANDREAS IDENTIFICATION ***</span>

NAME .......... <span class="w">${esc(p.name.toUpperCase())}</span>
ID ............ ${p.id}
DOB ........... ${esc(p.dob)}   AGE ${age(p.dob)}
SEX ........... ${esc(String(p.gender || '').toUpperCase())}   HGT ${esc(p.height || '')}CM
NATIONALITY ... ${esc(String(p.nationality || '').toUpperCase())}

<span class="hd">--- LICENSES ---</span>
DRIVERS ....... ${st(L('drivers'))}   POINTS ${L('drivers').points}/${suspendAt}
FIREARMS ...... ${st(L('firearm'))}
PILOT ......... ${st(L('pilot'))}`;
  }
  const refNo = c => c.ref_id ? (c.service === 'DOT' ? 'WO-' : c.service === 'POLICE' ? '#' : 'F-') + c.ref_id : '-';
  const trackRows = list => list.map(c => `<tr class="${['CLOSED', 'COMPLETED'].includes(c.status) ? 'c-dim' : c.status === 'NOT PLACED' ? 'c-p1' : 'c-enrt'}"><td>${d24(c.at)}</td><td>${esc(c.service)}</td><td>${refNo(c)}</td><td class="wrap">${esc(c.message)}</td><td>${esc(c.status)}${c.units ? ' · ' + esc(c.units) : ''}</td></tr>`);
  function renderDash(el) {
    const d = dash(), fines = d.citations.filter(c => c.fineStatus === 'OUTSTANDING');
    const tile = (n, label, cls) => `<div class="stat ${cls}"><b>${n}</b><span>${label}</span></div>`;
    el.innerHTML = `<div class="panel" style="flex:0 0 400px"><div class="phead"><h2>Identification</h2></div><div class="ret">${idCard(d.profile, d.licenses, d.suspendAt)}</div></div>
      <div class="panel" style="flex:1;min-width:0"><div class="stats">${tile(d.warrants.length, 'Active Warrants', d.warrants.length ? 'r' : '')}${C.data.cfg.fines.enabled ? tile(fines.length, 'Outstanding Fines', fines.length ? 'y' : '') : ''}${tile(d.citations.length, 'Citations', '')}${tile(d.arrests.length, 'Arrests', '')}${tile(d.vehicles.length, 'Vehicles', '')}${tile(d.applications.filter(a => a.status === 'PENDING').length, 'Pending Applications', '')}</div>
        <div class="grid">
          ${d.warrants.length ? `<div class="sect" style="color:#ff6b6b">ACTIVE WARRANTS</div>${table(['Number', 'Type', 'Charges', 'Issued'], d.warrants.map(w => `<tr class="c-p1"><td>${esc(w.number)}</td><td>${esc(w.warrantType || '')}</td><td class="wrap">${esc(w.charges.join(', '))}</td><td>${day(w.at)}</td></tr>`), '')}<div class="hint" style="padding:6px 12px">Turn yourself in at any police station.</div>` : ''}
          <div class="sect">MY 911 CALLS & SERVICE REQUESTS</div>${table(['Time', 'Service', 'Number', 'Message', 'Status'], trackRows(d.calls.slice(0, 8)), 'No calls yet')}
          <div class="sect">LICENSES</div>${table(['License', 'Status', 'Points'], d.licenses.map(l => `<tr class="${stCls(l.status)}"><td>${esc(l.label)}</td><td>${esc(l.status)}</td><td>${l.key === 'drivers' ? `${l.points} / ${d.suspendAt}` : '-'}</td></tr>`), '')}
          <div class="sect">MEDICAL HISTORY</div>${table(['Date', 'Incident', 'Injury', 'Severity', 'Transported To'], d.medical.map(m => `<tr><td>${day(m.at)}</td><td>F-${m.incident_id}</td><td class="wrap">${esc(m.injury)}</td><td>${esc(m.severity)}</td><td>${esc(m.destination || '-')}</td></tr>`), 'No medical history')}
        </div></div>`;
  }

  /* ---------------- 911 ---------------- */
  function renderCall(el) {
    const svcs = [['POLICE', 'Police'], ...(C.data.cfg.fire ? [['FIRE', 'Fire'], ['EMS', 'Ambulance']] : [])];
    el.innerHTML = `<div class="panel" style="flex:0 0 480px"><div class="phead"><h2>Call 911</h2><span class="sub">Your location is sent with the call</span></div>
        <div class="formgrid" style="grid-template-columns:1fr">
          <div><label class="lbl">Service</label><div class="chips" style="margin:0">${svcs.map(s => `<span class="chip ${C.svc === s[0] ? 'on' : ''}" data-svc="${s[0]}">${s[1]}</span>`).join('')}</div></div>
          <div><label class="lbl">What is happening?</label><textarea class="fin" id="c911" maxlength="300" style="min-height:140px" placeholder="Who, what, where. Is anyone hurt? Are weapons involved?"></textarea></div>
          <div class="hint">Misuse of 911 is a crime. For road problems that are not emergencies use Service Requests.</div>
        </div><div class="actbar" style="justify-content:flex-end"><button class="btn red" id="c911Go">Call 911</button></div></div>
      <div class="panel" style="flex:1;min-width:0"><div class="phead"><h2>Call Tracking</h2><span class="sub">Updates when you reopen this screen</span></div><div class="grid">${table(['Time', 'Service', 'Number', 'Message', 'Status'], trackRows(dash().calls), 'No calls yet')}</div></div>`;
    $$('#civBody [data-svc]').forEach(c => c.onclick = () => { C.svc = c.dataset.svc; renderCall(el); });
    $('#c911Go').onclick = async () => {
      const btn = $('#c911Go'); btn.disabled = true;
      const r = await call('civ.call', { service: C.svc, message: $('#c911').value });
      btn.disabled = false;
      if (r) { toast(r.police ? 'Police dispatch has your call.' : r.message); setTimeout(reload, 1200); }
    };
  }

  /* ---------------- records ---------------- */
  function renderRecords(el) {
    const d = dash(), f = C.data.cfg.fines;
    const tabs = [['citations', `Citations (${d.citations.length})`], ['arrests', `Arrests (${d.arrests.length})`], ['warrants', `Warrants (${d.warrants.length})`]];
    let body;
    if (C.recTab === 'citations') body = table(['Number', 'Date', 'Officer', 'Charges', ...(f.enabled ? ['Fine', 'Fine Status'] : [])],
      d.citations.map(c => `<tr class="${c.fineStatus === 'OUTSTANDING' ? 'c-enrt' : ''}"><td>${esc(c.number)}</td><td>${day(c.at)}</td><td>${esc(c.officer)}</td><td class="wrap">${esc(c.charges.join(', '))}</td>${f.enabled ? `<td>${c.fine ? money(c.fine) : '-'}</td><td>${c.fine ? `${esc(c.fineStatus)}${c.fineStatus === 'OUTSTANDING' ? ' · expires ' + day(c.fineExpires) : ''}` : '-'}</td>` : ''}</tr>`), 'No citations');
    else if (C.recTab === 'arrests') body = table(['Number', 'Date', 'Officer', 'Charges', 'Booked At'], d.arrests.map(a => `<tr><td>${esc(a.number)}</td><td>${day(a.at)}</td><td>${esc(a.officer)}</td><td class="wrap">${esc(a.charges.join(', '))}</td><td>${esc(a.booking || '-')}</td></tr>`), 'No arrests');
    else body = table(['Number', 'Type', 'Charges', 'Issued', 'Status'], d.warrants.map(w => `<tr class="c-p1"><td>${esc(w.number)}</td><td>${esc(w.warrantType || '')}</td><td class="wrap">${esc(w.charges.join(', '))}</td><td>${day(w.at)}</td><td>ACTIVE</td></tr>`), 'No active warrants');
    el.innerHTML = `<div class="panel" style="flex:1"><div class="ftabs">${tabs.map(t => `<button class="${C.recTab === t[0] ? 'on' : ''}" data-rt="${t[0]}">${t[1]}</button>`).join('')}</div><div class="grid" style="border-top:1px solid var(--line-2)">${body}</div>
      ${f.enabled ? `<div class="hint" style="padding:8px 12px">Fines are a record only. Nothing is ever taken from you; a fine expires ${f.expireDays} days after it was written.</div>` : ''}</div>`;
    $$('#civBody [data-rt]').forEach(b => b.onclick = () => { C.recTab = b.dataset.rt; renderRecords(el); });
  }

  /* ---------------- vehicles + businesses ---------------- */
  function renderVehicles(el) {
    const d = dash();
    el.innerHTML = `<div class="panel" style="flex:1;min-width:0"><div class="phead"><h2>Registered Vehicles</h2><span class="sub">${d.vehicles.length} / ${C.data.cfg.maxVehicles}</span><div class="tools"><button class="plus" id="cAddVeh" title="Register a vehicle">+</button></div></div>
        <div class="grid">${table(['Plate', 'Model', 'Color', 'Registered', 'Status', ''], d.vehicles.map(v => `<tr class="${stCls(v.status)}"><td><b>${esc(v.plate)}</b></td><td>${esc(v.model)}</td><td>${esc(v.color)}</td><td>${day(v.at)}</td><td>${esc(v.status)}</td>
          <td>${v.status === 'VALID' ? `<span class="lnk r" data-st="${v.id}|STOLEN">Report stolen</span>` : v.status === 'STOLEN' ? `<span class="lnk g" data-st="${v.id}|VALID">Recovered</span>` : ''}${v.status !== 'IMPOUNDED' ? `<span class="lnk" data-rm="${v.id}">Remove</span>` : ''}</td></tr>`), 'No vehicles. Press + to register one.')}</div></div>
      <div class="panel" style="flex:0 0 440px"><div class="phead"><h2>My Businesses</h2><div class="tools"><button class="plus" id="cAddBiz" title="Apply for a business license">+</button></div></div>
        <div class="grid">${table(['Name', 'Type', 'Since', 'Status', ''], d.businesses.map(b => `<tr class="${stCls(b.status)}"><td><b>${esc(b.name)}</b></td><td>${esc(b.type)}</td><td>${day(b.at)}</td><td>${esc(b.status)}</td><td>${b.status === 'ACTIVE' ? `<span class="lnk r" data-bc="${b.id}">Close</span>` : ''}</td></tr>`), 'No businesses')}</div></div>`;
    $$('#civBody [data-st]').forEach(x => x.onclick = async () => { const [id, st] = x.dataset.st.split('|'); if (await call('civ.vehicleStatus', { id: +id, status: st }, st === 'STOLEN' ? 'Reported stolen. Every department has been told.' : 'Marked recovered')) reload(); });
    $$('#civBody [data-rm]').forEach(x => x.onclick = () => modal('Remove vehicle', '<div>Remove this vehicle from your registration?</div>', [{ label: 'Cancel', cls: 'gray' }, { label: 'Remove', cls: 'red', run: async () => { if (!(await call('civ.vehicleRemove', { id: +x.dataset.rm }, 'Removed'))) return false; reload(); } }]));
    $$('#civBody [data-bc]').forEach(x => x.onclick = async () => { if (await call('civ.businessClose', { id: +x.dataset.bc }, 'Business closed')) reload(); });
    $('#cAddVeh').onclick = () => applyModal('vehicle');
    $('#cAddBiz').onclick = () => applyModal('business');
  }

  /* ---------------- applications ---------------- */
  const APPS = [['drivers', "Driver's License"], ['firearm', 'Firearm License'], ['pilot', 'Pilot License'], ['vehicle', 'Vehicle Registration'], ['business', 'Business License']];
  function applyModal(type) {
    const cfg = C.data.cfg, label = APPS.find(a => a[0] === type)[1];
    let body = `<div class="hint">${cfg.approval && cfg.approval[type] === false ? 'Approved instantly.' : 'An admin reviews this. You will see the decision here.'}</div>`;
    if (type === 'vehicle') body = `<div><label class="lbl">Plate</label><input class="fin" id="caPlate" maxlength="8" style="text-transform:uppercase"></div><div><label class="lbl">Model</label><input class="fin" id="caModel" maxlength="40" placeholder="e.g. Bravado Buffalo"></div><div><label class="lbl">Color</label><select class="fin" id="caColor">${cfg.colors.map(c => `<option>${esc(c)}</option>`).join('')}</select></div>` + body;
    if (type === 'business') body = `<div><label class="lbl">Business Name</label><input class="fin" id="caName" maxlength="64"></div><div><label class="lbl">Type</label><select class="fin" id="caType">${cfg.businessTypes.map(c => `<option>${esc(c)}</option>`).join('')}</select></div>` + body;
    modal('Apply: ' + label, body, [{ label: 'Cancel', cls: 'gray' }, { label: 'Submit Application', cls: 'green', run: async () => {
      const data = type === 'vehicle' ? { plate: $('#caPlate').value, model: $('#caModel').value, color: $('#caColor').value } : type === 'business' ? { name: $('#caName').value, btype: $('#caType').value } : {};
      const r = await call('civ.apply', { type, data }); if (!r) return false;
      toast(r.pending ? `${r.label} application sent for review` : `${r.label} approved`); reload();
    } }]);
  }
  function renderApps(el) {
    const d = dash();
    const detail = a => a.type === 'vehicle' ? `${esc(a.data.plate)} · ${esc(a.data.color)} ${esc(a.data.model)}` : a.type === 'business' ? `${esc(a.data.name)} · ${esc(a.data.btype)}` : '';
    el.innerHTML = `<div class="panel" style="flex:0 0 360px"><div class="phead"><h2>Apply</h2></div><div class="grid">${table(['Application', ''], APPS.map(a => {
        const lic = d.licenses.find(l => l.key === a[0]);
        return `<tr><td><b>${a[1]}</b>${lic ? `<div class="hint">Current: ${esc(lic.status)}</div>` : ''}</td><td style="text-align:right"><button class="btn" data-ap="${a[0]}" ${lic && lic.status === 'VALID' ? 'disabled' : ''}>Apply</button></td></tr>`; }), '')}</div></div>
      <div class="panel" style="flex:1;min-width:0"><div class="phead"><h2>My Applications</h2></div><div class="grid">${table(['Submitted', 'Application', 'Details', 'Status', 'Reviewed By', ''], d.applications.map(a => `<tr class="${stCls(a.status)}"><td>${d24(a.at)}</td><td>${esc(a.label)}</td><td>${detail(a)}</td><td>${esc(a.status)}${a.reason ? `<div class="hint">${esc(a.reason)}</div>` : ''}</td><td>${esc(a.reviewed_by || '-')}</td><td>${a.status === 'PENDING' ? `<span class="lnk r" data-cx="${a.id}">Cancel</span>` : ''}</td></tr>`), 'No applications yet')}</div></div>`;
    $$('#civBody [data-ap]').forEach(b => b.onclick = () => applyModal(b.dataset.ap));
    $$('#civBody [data-cx]').forEach(x => x.onclick = async () => { if (await call('civ.cancelApp', { id: +x.dataset.cx }, 'Cancelled')) reload(); });
  }

  /* ---------------- DOT service requests ---------------- */
  function renderService(el) {
    const s = C.data.cfg.services, mine = dash().calls.filter(c => c.service === 'DOT');
    el.innerHTML = `<div class="panel" style="flex:0 0 480px"><div class="phead"><h2>New Service Request</h2><span class="sub">Goes to the Department of Transportation</span></div>
        <div class="formgrid" style="grid-template-columns:1fr"><div><label class="lbl">What are you reporting?</label><select class="fin" id="csType">${s.map(x => `<option value="${x.id}">${esc(x.label)}</option>`).join('')}</select></div>
        <div><label class="lbl">Details</label><textarea class="fin" id="csMsg" maxlength="300" style="min-height:120px" placeholder="Where exactly, which lane, how bad..."></textarea></div><div class="hint">Your current location is sent with the request.</div></div>
        <div class="actbar" style="justify-content:flex-end"><button class="btn green" id="csGo">Send Request</button></div></div>
      <div class="panel" style="flex:1;min-width:0"><div class="phead"><h2>My Requests</h2></div><div class="grid">${table(['Time', 'Service', 'Work Order', 'Details', 'Status'], trackRows(mine), 'No requests yet')}</div></div>`;
    $('#csGo').onclick = async () => { const r = await call('civ.service', { type: +$('#csType').value, message: $('#csMsg').value }); if (r) { toast(`Sent as WO-${r.ref}`); reload(); } };
  }

  /* ---------------- profiles ---------------- */
  function renderProfiles(el) {
    const d = C.data;
    if (!C.sel || !d.profiles.some(p => p.id === C.sel)) C.sel = d.active || (d.profiles[0] && d.profiles[0].id) || null;
    const sel = d.profiles.find(p => p.id === C.sel);
    el.innerHTML = `<div class="panel" style="flex:0 0 55%"><div class="phead"><h2>My Profiles</h2><span class="sub">Who you are playing. Officers see this person when they run your name.</span></div>
      <div class="grid">${table(['ID', 'Name', 'DOB', 'Sex', "Driver's License"], d.profiles.map(p =>
        `<tr class="click ${p.id === d.active ? 'c-avail' : ''} ${p.id === C.sel ? 'sel' : ''}" data-id="${p.id}"><td>${p.id}</td><td>${esc(p.lastname)}, ${esc(p.firstname)}${p.id === d.active ? ' ★' : ''}</td><td>${esc(p.dateofbirth)}</td><td>${esc(p.gender[0])}</td><td>${esc(p.licenses.drivers.status)} · ${p.licenses.drivers.points} PTS</td></tr>`), 'No profiles yet. Press <b>New Profile</b> to make one.')}</div></div>
      <div class="panel" style="flex:1"><div class="phead"><h2>Profile</h2></div>
        <div class="ret">${sel ? `NAME .......... <span class="w">${esc(sel.lastname.toUpperCase())}, ${esc(sel.firstname.toUpperCase())}</span>\nID ............ ${sel.id}\nDOB ........... ${esc(sel.dateofbirth)}   AGE ${age(sel.dateofbirth)}\nNATIONALITY ... ${esc(sel.nationality.toUpperCase())}\n\n<span class="w">${sel.id === d.active ? '*** YOU ARE PLAYING AS THIS PERSON ***' : 'Not active. Press "Play as" to use this profile.'}</span>` : '<span class="w">Pick a profile.</span>'}</div>
        ${sel ? `<div class="actbar">${sel.id === d.active ? '<button class="btn" disabled>Playing as this person</button>' : '<button class="btn green" id="civPlay">Play as</button>'}<button class="btn red" id="civDel" style="margin-left:auto">Delete Profile</button></div>` : ''}</div>`;
    $$('#civBody tr[data-id]').forEach(r => r.onclick = () => { C.sel = +r.dataset.id; renderProfiles(el); });
    const play = $('#civPlay');
    if (play) play.onclick = async () => { if (await call('civ.select', { id: sel.id }, `Now playing as ${sel.firstname} ${sel.lastname}`)) { C.screen = 'dash'; reload(); } };
    const del = $('#civDel');
    if (del) del.onclick = () => modal('Delete profile', `<div>Delete <b>${esc(sel.firstname)} ${esc(sel.lastname)}</b>? Their records stay on file but you can no longer play them.</div>`,
      [{ label: 'Cancel', cls: 'gray' }, { label: 'Delete', cls: 'red', run: async () => { if (!(await call('civ.delete', { id: sel.id }, 'Profile deleted'))) return false; reload(); } }]);
  }

  function renderNew(el) {
    const d = C.data, y = d.serverYear || new Date().getFullYear();
    el.innerHTML = `<div class="panel" style="flex:1"><div class="phead"><h2>New Civilian Profile</h2><span class="sub">This is the person officers and medics will see. You can have up to ${d.max}.</span></div>
      <div class="formgrid">
        <div><label class="lbl">First Name</label><input class="fin" id="cvFirst" maxlength="32"></div>
        <div><label class="lbl">Last Name</label><input class="fin" id="cvLast" maxlength="32"></div>
        <div><label class="lbl">Date of Birth</label><input class="fin" id="cvDob" type="date" min="${y - d.maxAge}-01-01" max="${y - d.minAge}-12-31" value="${y - 25}-01-01"></div>
        <div><label class="lbl">Sex</label><select class="fin" id="cvSex"><option>Male</option><option>Female</option><option>Non-binary</option></select></div>
        <div><label class="lbl">Nationality</label><select class="fin" id="cvNat">${d.nationalities.map(n => `<option>${esc(n)}</option>`).join('')}</select></div>
        <div><label class="lbl">Height (cm)</label><input class="fin" id="cvHeight" type="number" min="120" max="230" value="175"></div>
        <div class="full hint">New profiles start with a valid driver's license and no firearm or pilot license.</div>
      </div>
      <div class="actbar" style="justify-content:flex-end"><button class="btn gray" id="cvCancel">Cancel</button><button class="btn green" id="cvCreate">Create Profile</button></div></div>`;
    $('#cvCancel').onclick = () => show(dash() ? 'dash' : 'profiles');
    $('#cvCreate').onclick = async () => {
      const r = await call('civ.create', { firstname: $('#cvFirst').value, lastname: $('#cvLast').value, dateofbirth: $('#cvDob').value,
        gender: $('#cvSex').value, nationality: $('#cvNat').value, height: +$('#cvHeight').value }, 'Profile created. You are now playing as them.');
      if (r) { C.screen = 'dash'; C.sel = r.id; reload(); }
    };
    $('#cvFirst').focus();
  }

  UL.on('openCiv', m => { C.data = m.data; C.sel = null; $('#civ').classList.add('on'); show(m.data.dash ? 'dash' : (m.data.profiles || []).length ? 'profiles' : 'new'); });
  UL.on('closeCiv', () => { $('#civ').classList.remove('on'); $('#cModal').classList.remove('on'); });
  $('#civClose').onclick = () => UL.req('close');
  document.addEventListener('keydown', e => {
    if (e.key !== 'Escape' || !$('#civ').classList.contains('on')) return;
    if ($('#cModal').classList.contains('on')) return $('#cModal').classList.remove('on');
    UL.req('close');
  });
  setInterval(() => { const d = new Date(); $('#civClock').textContent = `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`; }, 1000);
})();
