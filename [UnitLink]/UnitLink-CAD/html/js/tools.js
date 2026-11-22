/* UnitLink shared Tools window: same CAD look, opened from the Tools tile on
   the police, SAFR and DOT tablets. Server: 'tools.*' requests + toolsPush. */
window.ULTools = (() => {
  'use strict';
  const $ = s => document.querySelector(s), $$ = s => [...document.querySelectorAll(s)];
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[c]));
  const pad = n => String(n).padStart(2, '0');
  const d24 = sec => { const d = new Date(sec * 1000); return `${pad(d.getMonth()+1)}/${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`; };
  const I = {
    search:'<circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/>', msg:'<path d="M4 5h16v11H8l-4 4z"/>', bolo:'<path d="M12 3l9 16H3z"/><path d="M12 10v4M12 17v.1"/>',
    link:'<path d="M10 14a4 4 0 005.7 0l3-3a4 4 0 00-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 00-5.7 0l-3 3a4 4 0 005.7 5.7l1-1"/>',
    act:'<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>', people:'<circle cx="9" cy="8" r="3"/><path d="M3 20a6 6 0 0112 0M16 4a3 3 0 010 6M21 20a6 6 0 00-4-5.6"/>',
  };
  const svg = (n, c) => `<svg viewBox="0 0 24 24" ${c ? `style="--ic:${c}"` : ''}>${I[n]}</svg>`;
  const TILES = [['search', 'Global Search', '#ffd257', 'search'], ['messages', 'Messages', '#fff', 'msg'], ['bolos', 'BOLOs', '#ff6b6b', 'bolo'],
    ['links', 'Incident Links', '#9cc3ff', 'link'], ['activity', 'Activity', '#9cc3ff', 'act'], ['profiles', 'Employees', '#3ee06a', 'people']];
  const TYPE_LABEL = { call: 'Police Call', fire: 'SAFR Incident', dot: 'DOT Work Order' };
  const PREFIX = { call: '#', fire: 'F-', dot: 'WO-' };
  const S = { on: false, screen: 'search', info: null, me: null, kind: null, onChange: null, unread: 0, q: '', results: null, actScope: 'me', pq: '', linkType: 'call', linkId: '' };

  document.body.insertAdjacentHTML('beforeend', `<div id="tools"><div class="win">
    <div class="menubar"><span>File</span><span>View</span><span>Help</span><span class="title" id="tTitle">Tools</span><span class="brand">UNITLINK · TOOLS</span><span class="x" id="tClose" title="Close (Esc)">✕ Close</span></div>
    <div class="toolbar" id="tToolbar"></div>
    <div class="screens"><section class="fscreen" id="tScreen"></section>
      <div class="modal" id="tModal"><div class="mbox"><div class="mh" id="tmTitle"></div><div class="mb" id="tmBody"></div><div class="mf" id="tmFoot"></div></div></div>
      <div class="toast" id="tToast"></div></div>
    <div class="statusbar"><div><span class="dot"></span>Connected</div><div id="tsMe"></div><div id="tsUnits"></div><div class="clock" id="tClock">--:--:--</div></div>
  </div></div>`);

  let toastTimer;
  const toast = (msg, err) => { const t = $('#tToast'); t.textContent = msg; t.className = 'toast on' + (err ? ' err' : ''); clearTimeout(toastTimer); toastTimer = setTimeout(() => t.className = 'toast', 2800); };
  async function call(action, payload, okMsg) {
    const r = await UL.req(action, payload);
    if (!r || !r.ok) { toast((r && r.data) || 'Request failed.', true); return null; }
    if (okMsg) toast(okMsg);
    return r.data === undefined ? true : r.data;
  }
  function modal(title, body, buttons) {
    $('#tmTitle').textContent = title; $('#tmBody').innerHTML = body;
    $('#tmFoot').innerHTML = buttons.map((b, i) => `<button class="btn ${b.cls || ''}" data-i="${i}">${b.label}</button>`).join('');
    $$('#tmFoot button').forEach(el => el.onclick = async () => { const b = buttons[+el.dataset.i]; if (!b.run || (await b.run()) !== false) $('#tModal').classList.remove('on'); });
    $('#tModal').classList.add('on');
  }

  function chrome() {
    $('#tToolbar').innerHTML = TILES.map(t => `<div class="tile ${t[0] === S.screen ? 'on' : ''}" data-t="${t[0]}">${svg(t[3], t[2])}${t[1]}${t[0] === 'messages' && S.unread ? `<i class="badge">${S.unread}</i>` : ''}</div>`).join('') + '<div class="seal"><div>TOOLS</div></div>';
    $$('#tToolbar .tile').forEach(el => el.onclick = () => show(el.dataset.t));
    $('#tTitle').textContent = 'Tools · ' + TILES.find(t => t[0] === S.screen)[1];
    if (S.info) { $('#tsMe').textContent = `${S.info.me.label} · ${S.info.me.dept}`; $('#tsUnits').textContent = `${S.info.units.length} units on duty`; }
  }
  function show(screen) {
    S.screen = screen;
    if (screen === 'messages') { S.unread = 0; if (S.onChange) S.onChange(); }
    const sc = $('#tScreen'); sc.className = 'fscreen tools-' + screen;
    ({ search: renderSearch, messages: renderMessages, bolos: renderBolos, links: renderLinks, activity: renderActivity, profiles: renderProfiles })[screen](sc);
    chrome();
  }
  const table = (head, rows, empty, cls = '') => `<table class="${cls}"><thead><tr>${head.map(h => `<th>${h}</th>`).join('')}</tr></thead><tbody>${rows.join('') || `<tr><td colspan="${head.length}" class="empty">${empty}</td></tr>`}</tbody></table>`;

  /* ---- search ---- */
  function renderSearch(sc) {
    sc.innerHTML = `<div class="panel" style="flex:1"><div class="phead"><h2>Global Search</h2><span class="sub">People, vehicles, police calls, SAFR incidents, DOT work orders${S.kind === 'leo' ? ', records' : ''}, BOLOs</span></div>
      <form class="sform" id="tSearchF"><input class="fin" id="tQ" placeholder="Name, plate, call number, street..." value="${esc(S.q)}"><button class="btn">Search</button></form>
      <div class="grid" id="tRes" style="border-top:0"></div></div>`;
    $('#tSearchF').onsubmit = async e => { e.preventDefault(); S.q = $('#tQ').value.trim(); const r = await call('tools.search', { q: S.q }); if (r) { S.results = r; drawResults(); } };
    drawResults(); $('#tQ').focus();
  }
  function drawResults() {
    const r = S.results, el = $('#tRes');
    if (!r) { el.innerHTML = '<div class="empty">Search everything UnitLink knows about.</div>'; return; }
    const sect = (title, head, rows) => rows.length ? `<div class="sect">${title} <b style="color:#9cc3ff">${rows.length}</b></div>${table(head, rows, '')}` : '';
    let html = sect('PEOPLE', ['ID', 'Name', 'DOB', 'Sex'], r.people.map(p => `<tr><td>${p.id}</td><td><b>${esc(p.name)}</b></td><td>${esc(p.dob)}</td><td>${esc(p.gender)}</td></tr>`));
    html += sect('VEHICLES', ['Plate', 'Model', 'Color', 'Owner', 'Status'], r.vehicles.map(v => `<tr class="${v.status === 'STOLEN' ? 'c-p1' : ''}"><td><b>${esc(v.plate)}</b></td><td>${esc(v.model)}</td><td>${esc(v.color)}</td><td>${esc(v.owner || '')}</td><td>${esc(v.status)}</td></tr>`));
    html += sect('POLICE CALLS', ['Call#', 'Nature', 'Location', 'Status'], r.calls.map(c => `<tr class="click" data-lk="call:${c.id}"><td>#${c.id}</td><td>${esc(c.nature)}</td><td>${esc(c.street || '')}</td><td>${esc(c.status)}</td></tr>`));
    html += sect('SAFR INCIDENTS', ['Incident', 'Type', 'Nature', 'Location', 'Status'], r.fire.map(c => `<tr class="click" data-lk="fire:${c.id}"><td>F-${c.id}</td><td>${esc(c.type)}</td><td>${esc(c.nature)}</td><td>${esc(c.street || '')}</td><td>${esc(c.status === 'closed' ? 'CLOSED · ' + (c.disposition || '') : 'ACTIVE')}</td></tr>`));
    html += sect('DOT WORK ORDERS', ['WO#', 'Category', 'Description', 'Location', 'Status'], r.dot.map(c => `<tr class="click" data-lk="dot:${c.id}"><td>WO-${c.id}</td><td>${esc(c.category)}</td><td class="trunc">${esc(c.description)}</td><td>${esc(c.street || '')}</td><td>${esc(c.status)}</td></tr>`));
    html += sect('RECORDS', ['Number', 'Type', 'Subject', 'Status'], (r.records || []).map(c => `<tr><td>${esc(c.number)}</td><td>${esc(c.type.toUpperCase())}</td><td>${esc(c.subject || '')}</td><td>${esc(c.status.toUpperCase())}</td></tr>`));
    html += sect('BOLOS', ['Type', 'Title', 'Plate', 'Dept'], r.bolos.map(b => `<tr class="c-p1"><td>${esc(b.type)}</td><td>${esc(b.title)}</td><td>${esc(b.plate || '')}</td><td>${esc(b.dept || '')}</td></tr>`));
    el.innerHTML = html || '<div class="empty">Nothing found.</div>';
    $$('#tRes [data-lk]').forEach(tr => tr.onclick = () => { const [t, id] = tr.dataset.lk.split(':'); S.linkType = t; S.linkId = id; show('links'); });
  }

  /* ---- messages ---- */
  async function renderMessages(sc) {
    const units = S.info.units.filter(u => u.id !== S.info.me.id);
    sc.innerHTML = `<div class="panel main"><div class="phead"><h2>Inbox</h2><span class="sub">Last few days · to you, your department and all units</span></div><div class="grid" id="tMsgs"><div class="empty">Loading...</div></div></div>
      <div class="panel side"><div class="phead"><h2>New Message</h2></div><div class="formgrid" style="grid-template-columns:1fr;padding:10px">
        <div><label class="lbl">To</label><select class="fin" id="tTo"><option value="all">ALL UNITS</option>${S.info.depts.map(d => `<option value="dept:${esc(d)}">${esc(d)} (department)</option>`).join('')}${units.map(u => `<option value="member:${u.id}">${esc(u.callsign)} · ${esc(u.name)} (${esc(u.dept)})</option>`).join('')}</select></div>
        <div><label class="lbl">Message</label><textarea class="fin" id="tBody" maxlength="500" style="min-height:120px"></textarea></div>
        <div style="display:flex;justify-content:flex-end"><button class="btn green" id="tSend">Send</button></div></div></div>`;
    $('#tSend').onclick = async () => { if (await call('tools.send', { to: $('#tTo').value, body: $('#tBody').value }, 'Sent')) { $('#tBody').value = ''; loadMessages(); } };
    loadMessages();
  }
  async function loadMessages() {
    const rows = await call('tools.messages'); if (!rows || S.screen !== 'messages') return;
    $('#tMsgs').innerHTML = table(['Time', 'From', 'To', 'Message'], rows.map(m => `<tr class="${m.mine ? 'c-dim' : m.to_kind === 'member' ? 'c-enrt' : ''}"><td>${d24(m.at)}</td><td><b>${esc(m.from_label)}</b> ${esc(m.from_dept || '')}</td><td>${esc(m.to_label || m.to_kind.toUpperCase())}</td><td class="wrap">${esc(m.body)}</td></tr>`), 'No messages');
  }

  /* ---- BOLOs ---- */
  async function renderBolos(sc) {
    sc.innerHTML = `<div class="panel" style="flex:1"><div class="alerthead"><h2>${svg('bolo')}Shared BOLOs</h2><button class="ab" id="tAddBolo">+ Add BOLO</button></div><div class="grid" id="tBolos"><div class="empty">Loading...</div></div></div>`;
    $('#tAddBolo').onclick = () => modal('New BOLO (all departments)', `<div><label class="lbl">Type</label><select class="fin" id="tbT">${S.info.boloTypes.map(t => `<option>${esc(t)}</option>`).join('')}</select></div>
      <div><label class="lbl">Title</label><input class="fin" id="tbTitle" maxlength="120"></div><div><label class="lbl">Plate (optional)</label><input class="fin" id="tbPlate" maxlength="12"></div>
      <div><label class="lbl">Details</label><textarea class="fin" id="tbBody" maxlength="1000"></textarea></div>`,
      [{ label: 'Cancel', cls: 'gray' }, { label: 'Post BOLO', cls: 'red', run: async () => { if (!(await call('tools.addBolo', { type: $('#tbT').value, title: $('#tbTitle').value, plate: $('#tbPlate').value, body: $('#tbBody').value }, 'BOLO posted'))) return false; loadBolos(); } }]);
    loadBolos();
  }
  async function loadBolos() {
    const rows = await call('tools.bolos'); if (!rows || S.screen !== 'bolos') return;
    $('#tBolos').innerHTML = table(['Posted', 'Type', 'Title', 'Plate', 'Details', 'Dept', 'By', ''], rows.map(b => `<tr class="c-p1"><td>${d24(b.at)}</td><td>${esc(b.type)}</td><td><b>${esc(b.title)}</b></td><td>${esc(b.plate || '')}</td><td class="wrap">${esc(b.body || '')}</td><td>${esc(b.dept || '')}</td><td>${esc(b.created_by)}</td><td><span class="lnk r" data-clr="${b.id}">Clear</span></td></tr>`), 'No active BOLOs');
    $$('#tBolos [data-clr]').forEach(x => x.onclick = async () => { if (await call('tools.clearBolo', { id: +x.dataset.clr }, 'Cleared')) loadBolos(); });
  }

  /* ---- incident links ---- */
  const typeSel = (id, sel) => `<select class="fin" id="${id}" style="width:auto">${Object.keys(TYPE_LABEL).map(t => `<option value="${t}" ${t === sel ? 'selected' : ''}>${TYPE_LABEL[t]}</option>`).join('')}</select>`;
  function renderLinks(sc) {
    sc.innerHTML = `<div class="panel" style="flex:1"><div class="phead"><h2>Incident Links</h2><span class="sub">Tie a police call, SAFR incident and DOT work order together</span></div>
      <form class="sform" id="tLinkF">${typeSel('tLt', S.linkType)}<input class="fin" id="tLi" placeholder="Number" value="${esc(S.linkId)}" style="width:140px"><button class="btn">Show Links</button></form>
      <div class="grid" id="tLinks" style="border-top:0"><div class="empty">Pick an incident to see what it is linked to.</div></div></div>`;
    $('#tLinkF').onsubmit = e => { e.preventDefault(); S.linkType = $('#tLt').value; S.linkId = $('#tLi').value.replace(/\D/g, ''); loadLinks(); };
    if (S.linkId) loadLinks();
  }
  async function loadLinks() {
    const rows = await call('tools.links', { type: S.linkType, id: +S.linkId }); if (!rows || S.screen !== 'links') return;
    const me = PREFIX[S.linkType] + S.linkId;
    $('#tLinks').innerHTML = `<div class="sect">${esc(TYPE_LABEL[S.linkType])} ${esc(me)}</div>` + table(['Linked To', 'Type', 'Linked By', ''], rows.map(l => `<tr><td><b>${esc(l.label)}</b></td><td>${esc(TYPE_LABEL[l.type])}</td><td>${esc(l.by)}</td><td><span class="lnk r" data-ul="${l.id}">Unlink</span></td></tr>`), 'Not linked to anything yet') +
      `<div class="actbar"><span class="lbl" style="margin:0 6px 0 0">Link ${esc(me)} to</span>${typeSel('tLt2', S.linkType === 'call' ? 'fire' : 'call')}<input class="fin" id="tLi2" placeholder="Number" style="width:120px"><button class="btn" id="tLinkGo">+ Link</button></div>`;
    $$('#tLinks [data-ul]').forEach(x => x.onclick = async () => { if (await call('tools.unlink', { id: +x.dataset.ul }, 'Unlinked')) loadLinks(); });
    $('#tLinkGo').onclick = async () => { if (await call('tools.link', { a: { type: S.linkType, id: +S.linkId }, b: { type: $('#tLt2').value, id: +$('#tLi2').value.replace(/\D/g, '') } }, 'Linked')) loadLinks(); };
  }

  /* ---- activity ---- */
  async function renderActivity(sc) {
    const sup = S.info.me.supervisor;
    sc.innerHTML = `<div class="panel" style="flex:1"><div class="ftabs"><button class="${S.actScope === 'me' ? 'on' : ''}" data-sc="me">My Activity</button>${sup ? `<button class="${S.actScope === 'dept' ? 'on' : ''}" data-sc="dept">${esc(S.info.me.dept)} Activity</button>` : ''}</div><div class="grid" id="tAct" style="border-top:1px solid var(--line-2)"><div class="empty">Loading...</div></div></div>`;
    $$('#tScreen [data-sc]').forEach(b => b.onclick = () => { S.actScope = b.dataset.sc; renderActivity(sc); });
    const rows = await call('tools.activity', { scope: S.actScope }); if (!rows || S.screen !== 'activity') return;
    $('#tAct').innerHTML = table(['Time', 'Employee', 'Unit', 'Dept', 'Action'], rows.map(a => `<tr><td>${d24(a.at)}</td><td>${esc(a.name)}</td><td>${esc(a.callsign || '')}</td><td>${esc(a.dept || '')}</td><td class="wrap">${esc(a.action)}</td></tr>`), 'No activity yet');
  }

  /* ---- employee profiles ---- */
  async function renderProfiles(sc) {
    sc.innerHTML = `<div class="panel main"><div class="phead"><h2>Employees</h2><div class="tools"><div class="pill">${svg('search')}<input id="tPq" placeholder="Name, callsign, dept..." value="${esc(S.pq)}"></div></div></div><div class="grid" id="tProf"><div class="empty">Loading...</div></div></div>
      <div class="panel side"><div class="phead"><h2>Profile</h2></div><div class="ret" id="tProfile"><span class="w">Pick an employee.</span></div></div>`;
    let t; $('#tPq').oninput = e => { clearTimeout(t); t = setTimeout(() => { S.pq = e.target.value; loadProfiles(); }, 250); };
    loadProfiles();
  }
  async function loadProfiles() {
    const rows = await call('tools.profiles', { q: S.pq }); if (!rows || S.screen !== 'profiles') return;
    $('#tProf').innerHTML = table(['Name', 'Callsign', 'Dept', 'Certifications', 'Status', 'Last Seen'], rows.map(r => `<tr class="click ${r.onDuty ? 'c-avail' : 'c-dim'}" data-p="${r.member_id}"><td><b>${esc(r.name)}</b></td><td>${esc(r.callsign || '')}</td><td>${esc(r.dept || '')}</td><td class="wrap">${esc((r.certs || []).join(', ') || '-')}</td><td>${r.onDuty ? 'ON DUTY' : 'OFF DUTY'}</td><td>${d24(r.seen)}</td></tr>`), 'Nobody yet. Employees are added the first time they open a tablet.');
    $$('#tProf [data-p]').forEach(tr => tr.onclick = async () => {
      const e = await call('tools.profile', { id: +tr.dataset.p }); if (!e) return;
      $('#tProfile').innerHTML = `<div class="sect" style="padding-left:0">${esc(e.name)}</div><dl class="kvtab"><dt>Callsign</dt><dd>${esc(e.callsign || '')}</dd><dt>Department</dt><dd>${esc(e.dept || '')}</dd><dt>Tablet</dt><dd>${esc({ leo: 'Police CAD', fire: 'SAFR CAD', dot: 'DOT Work Orders' }[e.kind] || e.kind || '')}</dd><dt>Last Seen</dt><dd>${d24(e.seen)}</dd></dl>` +
        (e.activity ? `<div class="sect" style="padding-left:0">RECENT ACTIVITY</div>${e.activity.map(a => `<div class="hint">${d24(a.at)} · ${esc(a.action)}</div>`).join('') || '<div class="hint">None</div>'}` : '<div class="hint" style="margin-top:10px">Activity is visible to the employee and their department supervisors.</div>');
    });
  }

  /* ---- lifecycle ---- */
  async function open() {
    const info = await call('tools.open'); if (!info) return;
    S.info = info; S.on = true; $('#tools').classList.add('on'); show(S.screen);
  }
  function close() { S.on = false; $('#tools').classList.remove('on'); $('#tModal').classList.remove('on'); }
  $('#tClose').onclick = close;
  UL.on('toolsPush', m => {
    if (m.kind === 'toolsMessage') { if (S.on && S.screen === 'messages') loadMessages(); else { S.unread++; if (S.onChange) S.onChange(); } }
    if (m.kind === 'toolsBolo' && S.on && S.screen === 'bolos') loadBolos();
  });
  setInterval(() => { if (!S.on) return; const d = new Date(); $('#tClock').textContent = `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`; }, 1000);
  return {
    open, close, isOpen: () => S.on, unread: () => S.unread,
    attach(kind, me, onChange) { S.kind = kind; S.me = me; S.onChange = onChange; S.unread = 0; },
    link(type, id) { S.linkType = type; S.linkId = String(id); S.screen = 'links'; open(); },
  };
})();
