/* UnitLink Civilian ID (/civ): create and pick the civilian profile you play.
   Same look as the CAD. Talks to the server through UL.req ('civ.*'). */
(() => {
  'use strict';
  const $ = s => document.querySelector(s), $$ = s => [...document.querySelectorAll(s)];
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[c]));
  const age = dob => { const d = new Date(dob); if (isNaN(d)) return ''; const n = new Date(); let a = n.getFullYear() - d.getFullYear(); if (n < new Date(n.getFullYear(), d.getMonth(), d.getDate())) a--; return a; };
  const ICO = {
    id: '<rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="9" cy="12" r="2.5"/><path d="M14 10h4M14 14h4"/>',
    plus: '<circle cx="12" cy="12" r="9"/><path d="M12 8v8M8 12h8"/>',
  };
  const svg = (n, c) => `<svg viewBox="0 0 24 24" style="--ic:${c}">${ICO[n]}</svg>`;

  const C = { data: null, screen: 'list', sel: null };
  let toastTimer;
  const toast = (msg, err) => { const t = $('#civToast'); t.textContent = msg; t.className = 'toast on' + (err ? ' err' : ''); clearTimeout(toastTimer); toastTimer = setTimeout(() => t.className = 'toast', 2600); };
  async function call(action, payload, ok) {
    const r = await UL.req(action, payload);
    if (!r || !r.ok) { toast((r && r.data) || 'Request failed.', true); return null; }
    if (ok) toast(ok);
    return r.data === undefined ? true : r.data;
  }
  async function reload() { const d = await call('civ.list'); if (d) { C.data = d; render(); } }

  function render() {
    const d = C.data;
    const active = d.profiles.find(p => p.id === d.active);
    $('#civTiles').innerHTML = [['list', 'My Profiles', 'id', '#ffd257'], ['new', 'New Profile', 'plus', '#3ee06a']]
      .map(t => `<div class="tile ${C.screen === t[0] ? 'on' : ''} ${t[0] === 'new' && d.profiles.length >= d.max ? 'off' : ''}" data-s="${t[0]}">${svg(t[2], t[3])}${t[1]}</div>`).join('');
    $$('#civTiles .tile').forEach(el => el.onclick = () => { if (el.classList.contains('off')) return toast(`You can have up to ${d.max} profiles.`, true); C.screen = el.dataset.s; render(); });
    $('#civActive').textContent = active ? `${active.firstname} ${active.lastname}`.toUpperCase() : 'NO PROFILE';
    $('#civCount').textContent = `Profiles: ${d.profiles.length} / ${d.max}`;
    $('#civTitle').textContent = C.screen === 'new' ? 'Civilian ID · New Profile' : 'Civilian ID';
    (C.screen === 'new' ? renderNew : renderList)($('#civBody'));
  }

  function idCard(p, d) {
    const L = p.licenses, lic = l => l.status === 'VALID' ? l.status : `<span class="r">${esc(l.status)}</span>`;
    return `<span class="hd">*** SAN ANDREAS IDENTIFICATION ***</span>

NAME .......... <span class="w">${esc(p.lastname.toUpperCase())}, ${esc(p.firstname.toUpperCase())}</span>
ID ............ ${p.id}
DOB ........... ${esc(p.dateofbirth)}   AGE ${age(p.dateofbirth)}
SEX ........... ${esc(p.gender.toUpperCase())}   HGT ${p.height}CM
NATIONALITY ... ${esc(p.nationality.toUpperCase())}

<span class="hd">--- LICENSES ---</span>
DRIVERS ....... ${lic(L.drivers)}   POINTS ${L.drivers.points}/${d.suspendAt}
FIREARMS ...... ${lic(L.firearm)}
PILOT ......... ${lic(L.pilot)}

<span class="w">${p.id === d.active ? '*** YOU ARE PLAYING AS THIS PERSON ***' : 'Not active. Press "Play as" to use this profile.'}</span>`;
  }

  function renderList(el) {
    const d = C.data;
    if (!C.sel || !d.profiles.some(p => p.id === C.sel)) C.sel = d.active || (d.profiles[0] && d.profiles[0].id) || null;
    const sel = d.profiles.find(p => p.id === C.sel);
    el.innerHTML = `<div class="panel" style="flex:0 0 52%"><div class="phead"><h2>My Profiles</h2><span class="sub">Who you are playing. Officers see this person when they run your name.</span></div>
      <div class="grid"><table><thead><tr><th>ID</th><th>Name</th><th>DOB</th><th>Sex</th><th>Driver's License</th></tr></thead><tbody>${d.profiles.map(p =>
        `<tr class="click ${p.id === d.active ? 'c-avail' : ''} ${p.id === C.sel ? 'sel' : ''}" data-id="${p.id}"><td>${p.id}</td><td>${esc(p.lastname)}, ${esc(p.firstname)}${p.id === d.active ? ' ★' : ''}</td><td>${esc(p.dateofbirth)}</td><td>${esc(p.gender[0])}</td><td>${esc(p.licenses.drivers.status)} · ${p.licenses.drivers.points} PTS</td></tr>`).join('')
        || '<tr><td colspan="5" class="empty">No profiles yet. Press <b>New Profile</b> to make one.</td></tr>'}</tbody></table></div></div>
      <div class="panel" style="flex:1"><div class="phead"><h2>ID Card</h2></div>
        <div class="ret">${sel ? idCard(sel, d) : '<span class="w">Pick a profile on the left.</span>'}</div>
        ${sel ? `<div class="actbar">${sel.id === d.active ? '<button class="btn" disabled>Playing as this person</button>' : '<button class="btn green" id="civPlay">Play as</button>'}<button class="btn red" id="civDel" style="margin-left:auto">Delete Profile</button></div>` : ''}</div>`;
    $$('#civBody tr[data-id]').forEach(r => r.onclick = () => { C.sel = +r.dataset.id; renderList(el); });
    const play = $('#civPlay');
    if (play) play.onclick = async () => { const r = await call('civ.select', { id: sel.id }, `Now playing as ${sel.firstname} ${sel.lastname}`); if (r) reload(); };
    const del = $('#civDel');
    if (del) del.onclick = () => {
      if (del.dataset.confirm !== '1') { del.dataset.confirm = '1'; del.textContent = 'Click again to delete'; return; }
      call('civ.delete', { id: sel.id }, 'Profile deleted').then(ok => ok && reload());
    };
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
    $('#cvCancel').onclick = () => { C.screen = 'list'; render(); };
    $('#cvCreate').onclick = async () => {
      const r = await call('civ.create', { firstname: $('#cvFirst').value, lastname: $('#cvLast').value, dateofbirth: $('#cvDob').value,
        gender: $('#cvSex').value, nationality: $('#cvNat').value, height: +$('#cvHeight').value }, 'Profile created. You are now playing as them.');
      if (r) { C.screen = 'list'; C.sel = r.id; reload(); }
    };
    $('#cvFirst').focus();
  }

  UL.on('openCiv', m => { C.data = m.data; C.screen = m.data.profiles.length ? 'list' : 'new'; C.sel = null; $('#civ').classList.add('on'); render(); });
  UL.on('closeCiv', () => $('#civ').classList.remove('on'));
  $('#civClose').onclick = () => UL.req('close');
  document.addEventListener('keydown', e => { if (e.key === 'Escape' && $('#civ').classList.contains('on')) UL.req('close'); });
  setInterval(() => { const d = new Date(), p = n => String(n).padStart(2, '0'); $('#civClock').textContent = `${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`; }, 1000);
})();
