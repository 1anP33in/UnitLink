/* TSRP Core NUI - transport, DOM helpers and message routing.
 * All text from the server is inserted with textContent (never innerHTML), so names
 * or metadata typed by players cannot inject markup into the admin dashboard. */
'use strict';

const IN_GAME = typeof window.GetParentResourceName === 'function';
const RESOURCE = IN_GAME ? window.GetParentResourceName() : 'tsrp-core';

/** POST to a client NUI callback. Always resolves to { ok, data?, error?, field? }. */
async function post(name, body) {
    if (!IN_GAME) return DevMock.handle(name, body || {});
    try {
        const res = await fetch(`https://${RESOURCE}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(body || {}),
        });
        const json = await res.json();
        return json || { ok: false, error: 'No response' };
    } catch (e) {
        return { ok: false, error: 'The game client did not respond.' };
    }
}

/** Element builder: el('div', { class: 'x', onclick: fn }, 'text', childNode, [more]) */
function el(tag, attrs, ...children) {
    const node = document.createElement(tag);
    if (attrs) {
        for (const [key, value] of Object.entries(attrs)) {
            if (value === undefined || value === null || value === false) continue;
            if (key === 'class') node.className = value;
            else if (key === 'dataset') Object.assign(node.dataset, value);
            else if (key.startsWith('on') && typeof value === 'function') node.addEventListener(key.slice(2), value);
            else if (key === 'value') node.value = value;
            else if (value === true) node.setAttribute(key, '');
            else node.setAttribute(key, String(value));
        }
    }
    appendChildren(node, children);
    return node;
}

function appendChildren(node, children) {
    for (const child of children) {
        if (child === undefined || child === null || child === false) continue;
        if (Array.isArray(child)) appendChildren(node, child);
        else if (child instanceof Node) node.appendChild(child);
        else node.appendChild(document.createTextNode(String(child)));
    }
}

function clear(node) {
    while (node.firstChild) node.removeChild(node.firstChild);
    return node;
}

const $ = (sel, root) => (root || document).querySelector(sel);
const $$ = (sel, root) => Array.from((root || document).querySelectorAll(sel));

/** Message routing from the Lua side: { action, data } */
const Handlers = {};
function on(action, fn) { Handlers[action] = fn; }

window.addEventListener('message', (event) => {
    const msg = event.data;
    if (!msg || typeof msg.action !== 'string') return;
    const fn = Handlers[msg.action];
    if (fn) fn(msg.data || {});
});

/* ------------------------------------------------------------------ *
 * Browser preview mock. Only used when the page is opened outside the
 * game (GetParentResourceName is missing). It lets designers check the
 * screens: open index.html#selection, #spawn or #admin.
 * ------------------------------------------------------------------ */
const DevMock = (() => {
    const rules = {
        nameMin: 2, nameMax: 20, ageMin: 18, ageMax: 90, heightMin: 140, heightMax: 210,
        genders: [{ value: 'male', label: 'Male' }, { value: 'female', label: 'Female' }],
        nationalities: ['American', 'Bahamian', 'Canadian', 'Cuban', 'Jamaican'],
        confirmDelete: true, today: new Date().toISOString().slice(0, 10),
    };
    let chars = [
        { id: 1000, slot: 1, firstname: 'John', lastname: 'Doe', fullname: 'John Doe', dateofbirth: '1990-04-12', gender: 'male', nationality: 'American', height: 182, group: 'Law Enforcement' },
        { id: 1001, slot: 2, firstname: 'Mike', lastname: 'Smith', fullname: 'Mike Smith', dateofbirth: '1987-09-30', gender: 'male', nationality: 'Canadian', height: 176, group: 'SAFR' },
    ];
    const groups = [
        { name: 'owner', label: 'Owner', description: 'Server owner.', priority: 100, inherits: ['management'], permissions: ['*'], system: true, assigned: 1, effectiveGroups: ['owner', 'management', 'admin', 'moderator'] },
        { name: 'leo', label: 'Law Enforcement', description: 'Officers.', priority: 30, inherits: [], permissions: ['tsrp.police.dispatch', 'tsrp.police.duty'], system: false, assigned: 4, effectiveGroups: ['leo'] },
        { name: 'civilian', label: 'Civilian', description: 'Default.', priority: 0, inherits: [], permissions: ['tsrp.character.switch'], system: true, assigned: 12, effectiveGroups: ['civilian'] },
    ];
    const selection = () => ({ serverName: 'Tropical State RP', characters: chars, maxSlots: 3, rules });
    const responses = {
        'selection:preview': () => ({ ok: true }),
        'selection:select': () => ({ ok: true }),
        'selection:create': (b) => {
            if (!b.firstname) return { ok: false, error: 'First name must be 2-20 letters.', field: 'firstname' };
            const c = { id: 1002, slot: 3, firstname: b.firstname, lastname: b.lastname, fullname: `${b.firstname} ${b.lastname}`, dateofbirth: b.dateofbirth, gender: b.gender, nationality: b.nationality, height: b.height };
            chars.push(c);
            return { ok: true, data: { character: c } };
        },
        'selection:delete': (b) => { chars = chars.filter((c) => c.id !== b.id); return { ok: true, data: selection() }; },
        'selection:refresh': () => ({ ok: true, data: selection() }),
        'spawn:select': () => ({ ok: true }),
        'spawn:back': () => ({ ok: true }),
        'admin:close': () => ({ ok: true }),
        'ready': () => ({ ok: true }),
        'close': () => ({ ok: true }),
        'admin:request': (b) => {
            const a = b.action;
            const data = {
                init: { capabilities: { access: true, players: true, identifiers: true, characters: true, permissions: true, groups: true, audit: true, bootstrap: true }, serverName: 'Tropical State RP', version: '1.0.0', rules },
                overview: { connected: 12, loaded: 10, active: 9, totalCharacters: 214, totalAccounts: 96, slotsPerAccount: 3, availableSlots: 74, groups: 11, maxClients: 64 },
                players: [{ source: 1, name: 'player_one', identifier: 'license:abc123', state: 'active', characterId: 1000, characterName: 'John Doe', groups: ['Law Enforcement'], ping: 42 }],
                searchCharacters: chars.map((c) => ({ ...c, online: c.id === 1000, source: c.id === 1000 ? 1 : null })),
                getCharacter: {
                    character: { ...chars[0], identifier: 'license:abc123', createdAt: 1700000000 }, online: true, source: 1, canManage: true,
                    groups: [{ name: 'leo', label: 'Law Enforcement', priority: 30 }],
                    effectiveGroups: [{ name: 'leo', label: 'Law Enforcement', via: 'leo', inherited: false }],
                    overrides: [{ node: 'tsrp.admin.access', allow: false }, { node: 'tsrp.police.supervisor', allow: true }],
                    permissions: [
                        { node: 'tsrp.police.duty', allowed: true, source: 'group', group: 'leo', explanation: 'tsrp.police.duty is ALLOWED by group leo (grants tsrp.police.duty)' },
                        { node: 'tsrp.admin.access', allowed: false, source: 'override_deny', explanation: 'tsrp.admin.access is DENIED by an explicit character override on tsrp.admin.access' },
                    ],
                    metadata: { licenses: { driver: true } },
                },
                explain: { node: b.payload && b.payload.node, allowed: true, explanation: `${b.payload && b.payload.node} is ALLOWED by group leo (grants tsrp.police.*)` },
                groups: { groups, actorPriority: 100000 },
                nodes: [{ node: 'tsrp.admin.access', description: 'Open the admin dashboard', resource: 'tsrp-core' }, { node: 'tsrp.police.duty', description: 'Go on duty', resource: 'tsrp-core' }],
                audit: { page: 1, entries: [{ id: 1, timestamp: Date.now() / 1000, actor: 'acct-1a2b3c4d', actorCharacterId: 1000, targetCharacterId: 1001, action: 'group.assign', details: { group: 'safr' } }] },
            }[a];
            return data !== undefined ? { ok: true, data } : { ok: true, data: {} };
        },
    };
    function handle(name, body) {
        const fn = responses[name];
        return Promise.resolve(fn ? fn(body) : { ok: true });
    }
    function boot() {
        document.body.style.background = 'linear-gradient(135deg, #1f3b44, #3a2f3f 60%, #533d2d)';
        const view = (location.hash || '#selection').slice(1);
        setTimeout(() => {
            if (view === 'spawn') {
                Handlers.open({ view: 'spawn', payload: { character: chars[0], spawns: [
                    { id: 'last', label: 'Last Location', description: 'Where you were when you last left the city.', last: true },
                    { id: 'legion', label: 'Legion Square', description: 'Downtown Los Santos.', default: true },
                    { id: 'mrpd', label: 'Mission Row PD', description: 'Report for duty at Mission Row.' },
                ] } });
            } else if (view === 'admin') {
                Handlers.open({ view: 'admin', payload: { section: 'overview' } });
            } else {
                Handlers.open({ view: 'selection', payload: selection() });
            }
        }, 50);
    }
    return { handle, boot };
})();
