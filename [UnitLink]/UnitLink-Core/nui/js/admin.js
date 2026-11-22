/* UnitLink Core NUI - administration dashboard.
 * Buttons are hidden based on the capabilities the server reports, but every request
 * is authorised again on the server. Hiding is for convenience, not security. */
'use strict';

const AUDIT_ACTIONS = [
    'character.create', 'character.delete', 'character.load', 'character.switch', 'character.edit',
    'character.metadata', 'appearance.save', 'group.assign', 'group.remove', 'group.create',
    'group.update', 'group.delete', 'permission.allow', 'permission.deny', 'permission.clear',
    'admin.open', 'admin.denied',
];

const Admin = {
    caps: {},
    info: null,
    section: 'overview',
    groupsCache: null,
    nodesCache: null,
    charState: { query: '', results: [], selectedId: null },
    groupState: { selected: null, creating: false },
    auditState: { page: 1, action: '', characterId: '' },

    async api(action, payload) {
        const res = await post('admin:request', { action, payload: payload || {} });
        if (!res.ok) Toast.show(res.error || 'Request failed.', 'error');
        return res;
    },

    async show(payload) {
        const content = clear($('#admin-content'));
        content.appendChild(el('div', { class: 'spinner' }));
        const res = await this.api('init');
        if (!res.ok) { post('admin:close').then(() => App.close()); return; }
        this.info = res.data;
        this.caps = res.data.capabilities || {};
        this.groupsCache = null;
        this.nodesCache = null;
        $('#admin-version').textContent = `v${res.data.version}`;
        const role = $('#admin-role');
        role.textContent = this.caps.bootstrap ? 'Bootstrap admin' : 'Staff';
        role.className = `tag ${this.caps.bootstrap ? 'warm' : 'accent'}`;
        this.renderNav();
        let section = payload.section || 'overview';
        if (section === 'character') section = 'characters';
        if (payload.arg && section === 'characters') this.charState.selectedId = payload.arg;
        if (payload.arg && section === 'permissions') { section = 'characters'; this.charState.selectedId = payload.arg; }
        this.go(this.allowed(section) ? section : 'overview');
    },

    hide() {},

    sections() {
        return [
            { id: 'overview', label: 'Overview', cap: 'access' },
            { id: 'players', label: 'Players', cap: 'players' },
            { id: 'characters', label: 'Characters', cap: ['characters', 'permissions'] },
            { id: 'groups', label: 'Groups', cap: 'access' },
            { id: 'permissions', label: 'Permissions', cap: 'access' },
            { id: 'audit', label: 'Audit log', cap: 'audit' },
        ];
    },

    allowed(id) {
        const s = this.sections().find((x) => x.id === id);
        if (!s) return false;
        const caps = Array.isArray(s.cap) ? s.cap : [s.cap];
        return caps.some((c) => this.caps[c]);
    },

    renderNav() {
        const nav = clear($('#admin-nav-items'));
        this.sections().filter((s) => this.allowed(s.id)).forEach((s) => {
            nav.appendChild(el('button', { class: `nav-item${s.id === this.section ? ' active' : ''}`, dataset: { id: s.id }, onclick: () => this.go(s.id) },
                el('span', { class: 'dot' }), s.label));
        });
    },

    go(section) {
        this.section = section;
        $$('.nav-item').forEach((n) => n.classList.toggle('active', n.dataset.id === section));
        const s = this.sections().find((x) => x.id === section);
        $('#admin-title').textContent = s ? s.label : '';
        clear($('#admin-head-actions'));
        const content = clear($('#admin-content'));
        content.appendChild(el('div', { class: 'spinner' }));
        const fn = this[`render_${section}`];
        if (fn) fn.call(this, content);
    },

    async loadGroups(force) {
        if (this.groupsCache && !force) return this.groupsCache;
        const res = await this.api('groups');
        if (res.ok) this.groupsCache = res.data;
        return this.groupsCache;
    },

    async loadNodes(force) {
        if (this.nodesCache && !force) return this.nodesCache;
        const res = await this.api('nodes');
        if (res.ok) this.nodesCache = res.data;
        return this.nodesCache || [];
    },

    nodeDatalist(id) {
        const list = el('datalist', { id });
        (this.nodesCache || []).forEach((n) => list.appendChild(el('option', { value: n.node }, n.description)));
        return list;
    },

    /* ---------------- Overview ---------------- */
    async render_overview(content) {
        const res = await this.api('overview');
        clear(content);
        if (!res.ok) return;
        const d = res.data;
        const stat = (label, value, hint) => el('div', { class: 'stat' },
            el('div', { class: 'label' }, label), el('div', { class: 'value' }, value), hint ? el('div', { class: 'hint' }, hint) : null);
        content.appendChild(el('div', { class: 'grid grid-stats' },
            stat('Connected players', d.connected, `of ${d.maxClients} slots`),
            stat('Loaded characters', d.loaded, 'Characters selected right now'),
            stat('Active sessions', d.active, 'Spawned in the world'),
            stat('Registered characters', d.totalCharacters, `${d.totalAccounts} accounts`),
            stat('Available character slots', d.availableSlots, `${d.slotsPerAccount} per account`),
            stat('Permission groups', d.groups),
        ));
        content.appendChild(el('div', { class: 'card', style: 'margin-top:18px' },
            el('h3', {}, 'Your access'),
            el('div', { class: 'chips' }, Object.entries(this.caps).filter(([, v]) => v).map(([k]) => el('span', { class: 'tag accent' }, k))),
        ));
    },

    /* ---------------- Players ---------------- */
    async render_players(content) {
        const res = await this.api('players');
        clear(content);
        if (!res.ok) return;
        const showIds = this.caps.identifiers;
        const refresh = el('button', { class: 'btn btn-ghost btn-sm', onclick: () => this.go('players') }, 'Refresh');
        $('#admin-head-actions').appendChild(refresh);
        if (!res.data.length) { content.appendChild(el('div', { class: 'empty-state' }, 'No players connected.')); return; }
        const table = el('table', { class: 'table' },
            el('thead', {}, el('tr', {},
                el('th', {}, 'ID'), el('th', {}, 'Player'), showIds ? el('th', {}, 'Identifier') : null,
                el('th', {}, 'State'), el('th', {}, 'Character'), el('th', {}, 'Groups'), el('th', {}, 'Ping'))),
            el('tbody', {}, res.data.map((p) => el('tr', {
                class: p.characterId ? 'clickable' : '',
                onclick: () => { if (p.characterId && this.allowed('characters')) { this.charState.selectedId = p.characterId; this.go('characters'); } },
            },
                el('td', { class: 'mono' }, p.source),
                el('td', {}, p.name, p.bootstrap ? el('span', { class: 'tag warm', style: 'margin-left:6px' }, 'bootstrap') : null),
                showIds ? el('td', { class: 'mono muted' }, p.identifier || '-') : null,
                el('td', {}, el('span', { class: `tag ${p.state === 'active' ? 'ok' : ''}` }, p.state)),
                el('td', {}, p.characterId ? `${p.characterName} (#${p.characterId})` : el('span', { class: 'muted' }, 'none')),
                el('td', {}, el('div', { class: 'chips' }, (p.groups || []).map((g) => el('span', { class: 'tag' }, g)))),
                el('td', { class: 'mono muted' }, p.ping),
            ))),
        );
        content.appendChild(table);
    },

    /* ---------------- Characters ---------------- */
    async render_characters(content) {
        await Promise.all([this.loadGroups(), this.loadNodes()]);
        clear(content);
        const left = el('div', {});
        const right = el('div', { id: 'char-detail' });
        content.appendChild(el('div', { class: 'split' }, left, right));

        const search = el('input', { placeholder: 'Name, character id or license', value: this.charState.query });
        const results = el('div', { class: 'list', style: 'margin-top:10px' });
        const doSearch = async () => {
            this.charState.query = search.value;
            const res = await this.api('searchCharacters', { query: search.value });
            clear(results);
            if (!res.ok) return;
            this.charState.results = res.data;
            if (!res.data.length) results.appendChild(el('div', { class: 'empty-state' }, 'No characters found.'));
            res.data.forEach((c) => results.appendChild(el('div', {
                class: `list-item${c.id === this.charState.selectedId ? ' active' : ''}`,
                dataset: { id: c.id },
                onclick: () => this.openCharacter(c.id),
            },
                el('div', {}, el('div', { class: 'title' }, c.fullname), el('div', { class: 'meta' }, `#${c.id} - slot ${c.slot}${c.identifier ? ` - ${c.identifier}` : ''}`)),
                c.online ? el('span', { class: 'tag ok' }, `online #${c.source}`) : null,
            )));
        };
        let timer = null;
        search.addEventListener('input', () => { clearTimeout(timer); timer = setTimeout(doSearch, 300); });
        left.appendChild(search);
        left.appendChild(results);
        await doSearch();

        if (this.charState.selectedId) this.openCharacter(this.charState.selectedId);
        else right.appendChild(el('div', { class: 'card empty-state' }, 'Select a character to inspect it.'));
    },

    async openCharacter(id) {
        this.charState.selectedId = id;
        $$('#admin-content .list-item').forEach((n) => n.classList.toggle('active', Number(n.dataset.id) === id));
        const pane = $('#char-detail');
        if (!pane) return;
        clear(pane).appendChild(el('div', { class: 'spinner' }));
        const res = await this.api('getCharacter', { id });
        if (this.charState.selectedId !== id || !$('#char-detail')) return;
        clear(pane);
        if (!res.ok) return;
        this.renderCharacter(pane, res.data);
    },

    renderCharacter(pane, d) {
        const c = d.character;
        const canEdit = d.canManage && this.caps.characters;
        const canPerms = d.canManage && this.caps.permissions;
        const reload = () => this.openCharacter(c.id);

        // Identity
        const rules = this.info.rules || {};
        const fields = {
            firstname: el('input', { value: c.firstname, disabled: !canEdit }),
            lastname: el('input', { value: c.lastname, disabled: !canEdit }),
            dateofbirth: el('input', { type: 'date', value: c.dateofbirth, disabled: !canEdit }),
            gender: el('select', { disabled: !canEdit }, (rules.genders || []).map((g) => el('option', { value: g.value, selected: g.value === c.gender }, g.label))),
            nationality: el('select', { disabled: !canEdit }, (rules.nationalities || []).map((n) => el('option', { value: n, selected: n === c.nationality }, n))),
            height: el('input', { type: 'number', value: c.height, min: rules.heightMin, max: rules.heightMax, disabled: !canEdit }),
        };
        const saveBtn = canEdit ? el('button', { class: 'btn btn-primary btn-sm', onclick: async (e) => {
            await withBusy(e.currentTarget, async () => {
                const payload = {};
                Object.entries(fields).forEach(([k, input]) => { payload[k] = k === 'height' ? Number(input.value) : input.value; });
                const res = await this.api('updateCharacter', { id: c.id, fields: payload });
                if (res.ok) { Toast.show('Character updated.', 'success'); reload(); }
            });
        } }, 'Save changes') : null;
        const f = (label, input) => el('label', { class: 'field' }, el('span', {}, label), input);
        pane.appendChild(el('div', { class: 'card' },
            el('h3', {}, el('span', {}, `${c.firstname} ${c.lastname}`, el('span', { class: 'muted', style: 'font-weight:500;margin-left:8px' }, `#${c.id}`)),
                el('span', { class: 'chips' },
                    d.online ? el('span', { class: 'tag ok' }, `Online (#${d.source})`) : el('span', { class: 'tag' }, 'Offline'),
                    !d.canManage ? el('span', { class: 'tag warm', title: 'At or above your rank, or your own character' }, 'Read only') : null)),
            c.identifier ? el('div', { class: 'sub mono' }, `${c.identifier} - slot ${c.slot}`) : el('div', { class: 'sub' }, `Slot ${c.slot}`),
            el('div', { class: 'field-row' }, f('First name', fields.firstname), f('Last name', fields.lastname)),
            el('div', { class: 'field-row', style: 'margin-top:10px' }, f('Date of birth', fields.dateofbirth), f('Height (cm)', fields.height)),
            el('div', { class: 'field-row', style: 'margin-top:10px' }, f('Gender', fields.gender), f('Nationality', fields.nationality)),
            saveBtn ? el('div', { class: 'actions', style: 'margin-top:12px' }, saveBtn) : null,
        ));

        // Groups
        const groups = (this.groupsCache && this.groupsCache.groups) || [];
        const actorPriority = (this.groupsCache && this.groupsCache.actorPriority) || 0;
        const assignable = groups.filter((g) => !d.groups.some((x) => x.name === g.name) && (this.caps.bootstrap || g.priority < actorPriority));
        const groupSelect = el('select', {}, assignable.map((g) => el('option', { value: g.name }, `${g.label} (${g.name})`)));
        pane.appendChild(el('div', { class: 'card' },
            el('h3', {}, 'Groups'),
            el('div', { class: 'sub' }, 'Directly assigned groups. Permissions from inherited groups are included automatically.'),
            el('div', { class: 'chips' }, d.groups.length ? d.groups.map((g) => el('span', { class: `tag ${g.missing ? 'danger' : 'accent'}` }, g.label,
                canPerms ? el('button', { title: 'Remove group', onclick: async () => {
                    const ok = await Modal.open({ title: `Remove ${g.label}?`, body: `${c.firstname} ${c.lastname} will lose this group and everything it grants.`, confirmLabel: 'Remove' });
                    if (!ok.ok) return;
                    const res = await this.api('removeGroup', { id: c.id, group: g.name });
                    if (res.ok) { Toast.show('Group removed.', 'success'); reload(); }
                } }, '×') : null)) : el('span', { class: 'muted' }, 'No groups.')),
            el('div', { class: 'sub', style: 'margin:12px 0 6px' }, 'Effective groups'),
            el('div', { class: 'chips' }, d.effectiveGroups.map((g) => el('span', { class: 'tag', title: g.inherited ? `inherited via ${g.via}` : 'assigned directly' }, g.inherited ? `${g.label} ← ${g.via}` : g.label))),
            canPerms && assignable.length ? el('div', { class: 'inline-form', style: 'margin-top:12px' }, groupSelect,
                el('button', { class: 'btn btn-ghost btn-sm', onclick: async (e) => {
                    await withBusy(e.currentTarget, async () => {
                        const res = await this.api('addGroup', { id: c.id, group: groupSelect.value });
                        if (res.ok) { Toast.show('Group assigned.', 'success'); reload(); }
                    });
                } }, 'Assign group')) : null,
        ));

        // Overrides
        const nodeInput = el('input', { placeholder: 'permission.node', list: 'admin-node-list', spellcheck: 'false' });
        const modeSelect = el('select', { style: 'max-width:130px' }, el('option', { value: 'allow' }, 'Allow'), el('option', { value: 'deny' }, 'Deny'));
        pane.appendChild(el('div', { class: 'card' },
            el('h3', {}, 'Permission overrides'),
            el('div', { class: 'sub' }, 'Overrides beat every group. An explicit deny can never be bypassed by a group grant.'),
            d.overrides.length ? el('table', { class: 'table' }, el('tbody', {}, d.overrides.map((o) => el('tr', {},
                el('td', { class: 'mono' }, o.node),
                el('td', {}, el('span', { class: `tag ${o.allow ? 'ok' : 'danger'}` }, o.allow ? 'Explicit allow' : 'Explicit deny')),
                el('td', { style: 'text-align:right' }, canPerms ? el('button', { class: 'btn btn-ghost btn-sm', onclick: async () => {
                    const res = await this.api('clearOverride', { id: c.id, node: o.node });
                    if (res.ok) { Toast.show('Override removed.', 'success'); reload(); }
                } }, 'Remove') : null),
            )))) : el('div', { class: 'muted' }, 'No overrides.'),
            canPerms ? el('div', { class: 'inline-form', style: 'margin-top:12px' }, nodeInput, modeSelect,
                el('button', { class: 'btn btn-ghost btn-sm', onclick: async (e) => {
                    const node = nodeInput.value.trim();
                    if (!node) return;
                    await withBusy(e.currentTarget, async () => {
                        const res = await this.api('setOverride', { id: c.id, node, allow: modeSelect.value === 'allow' });
                        if (res.ok) { Toast.show('Override saved.', 'success'); reload(); }
                    });
                } }, 'Save override'), this.nodeDatalist('admin-node-list')) : null,
        ));

        // Effective permissions + explain
        const filter = el('input', { placeholder: 'Filter permissions' });
        const tbody = el('tbody', {});
        const renderRows = () => {
            clear(tbody);
            const q = filter.value.trim().toLowerCase();
            d.permissions.filter((p) => !q || p.node.includes(q)).forEach((p) => tbody.appendChild(el('tr', {},
                el('td', { class: 'mono' }, p.node),
                el('td', {}, el('span', { class: `tag ${p.allowed ? 'ok' : 'danger'}` }, p.allowed ? 'Allowed' : 'Denied')),
                el('td', { class: 'muted' }, p.explanation),
            )));
            if (!tbody.firstChild) tbody.appendChild(el('tr', {}, el('td', { colspan: 3, class: 'muted' }, 'Nothing to show.')));
        };
        filter.addEventListener('input', renderRows);
        renderRows();
        pane.appendChild(el('div', { class: 'card' },
            el('h3', {}, 'Effective permissions'),
            el('div', { class: 'sub' }, 'Every node this character holds through groups or overrides, and why.'),
            this.explainTool(c.id),
            el('div', { class: 'toolbar', style: 'margin-top:14px' }, filter),
            el('table', { class: 'table' }, el('thead', {}, el('tr', {}, el('th', {}, 'Node'), el('th', {}, 'Result'), el('th', {}, 'Source'))), tbody),
        ));

        // Metadata
        const keyInput = el('input', { placeholder: 'key (e.g. licenses)', spellcheck: 'false' });
        const valueInput = el('textarea', { placeholder: 'JSON value, e.g. {"driver": true}. Leave empty to remove the key.' });
        const keys = Object.keys(d.metadata || {}).sort();
        pane.appendChild(el('div', { class: 'card' },
            el('h3', {}, 'Metadata'),
            keys.length ? el('table', { class: 'table' }, el('tbody', {}, keys.map((k) => el('tr', { class: canEdit ? 'clickable' : '', onclick: () => {
                if (!canEdit) return;
                keyInput.value = k;
                valueInput.value = JSON.stringify(d.metadata[k], null, 2);
            } },
                el('td', { class: 'mono', style: 'width:180px' }, k),
                el('td', { class: 'mono muted' }, JSON.stringify(d.metadata[k])),
            )))) : el('div', { class: 'muted' }, 'No metadata.'),
            canEdit ? el('div', { style: 'margin-top:12px;display:flex;flex-direction:column;gap:8px' }, keyInput, valueInput,
                el('div', { class: 'actions' }, el('button', { class: 'btn btn-ghost btn-sm', onclick: async (e) => {
                    const key = keyInput.value.trim();
                    if (!key) return;
                    if (valueInput.value.trim()) {
                        try { JSON.parse(valueInput.value); } catch (err) { Toast.show('That value is not valid JSON.', 'error'); return; }
                    }
                    await withBusy(e.currentTarget, async () => {
                        const res = await this.api('setMetadata', { id: c.id, key, value: valueInput.value.trim() });
                        if (res.ok) { Toast.show('Metadata saved.', 'success'); reload(); }
                    });
                } }, 'Save metadata'))) : null,
        ));
    },

    explainTool(characterId, withIdInput) {
        const idInput = withIdInput ? el('input', { placeholder: 'Character id', style: 'max-width:140px', inputmode: 'numeric' }) : null;
        const nodeInput = el('input', { placeholder: 'Check a node, e.g. unitlink.police.duty', list: 'admin-explain-list', spellcheck: 'false' });
        const out = el('div', {});
        const run = async () => {
            const id = withIdInput ? Number(idInput.value) : characterId;
            const node = nodeInput.value.trim();
            if (!id || !node) return;
            const res = await this.api('explain', { id, node });
            clear(out);
            if (!res.ok) return;
            out.appendChild(el('div', { class: `explain ${res.data.allowed ? 'allowed' : 'denied'}` },
                el('strong', {}, res.data.allowed ? 'Allowed. ' : 'Denied. '), res.data.explanation,
                res.data.candidates ? el('div', { class: 'muted mono', style: 'margin-top:6px;font-size:11.5px' }, `Checked in order: ${res.data.candidates.join(' → ')}`) : null));
        };
        nodeInput.addEventListener('keydown', (e) => { if (e.key === 'Enter') run(); });
        return el('div', {},
            el('div', { class: 'inline-form' }, idInput, nodeInput, el('button', { class: 'btn btn-ghost btn-sm', onclick: run }, 'Explain')),
            this.nodeDatalist('admin-explain-list'),
            out);
    },

    /* ---------------- Groups ---------------- */
    async render_groups(content) {
        const data = await this.loadGroups(true);
        await this.loadNodes();
        clear(content);
        clear($('#admin-head-actions'));
        if (!data) return;
        const canWrite = this.caps.groups;
        if (canWrite) {
            $('#admin-head-actions').appendChild(el('button', { class: 'btn btn-primary btn-sm', onclick: () => {
                this.groupState = { selected: null, creating: true };
                this.render_groups(clear($('#admin-content')));
            } }, 'New group'));
        }
        const left = el('div', { class: 'list' });
        const right = el('div', {});
        content.appendChild(el('div', { class: 'split' }, left, right));
        data.groups.forEach((g) => left.appendChild(el('div', {
            class: `list-item${this.groupState.selected === g.name ? ' active' : ''}`,
            onclick: () => { this.groupState = { selected: g.name, creating: false }; this.render_groups(clear($('#admin-content'))); },
        },
            el('div', {}, el('div', { class: 'title' }, g.label), el('div', { class: 'meta mono' }, `${g.name} - priority ${g.priority}`)),
            el('span', { class: 'tag' }, `${g.assigned} char${g.assigned === 1 ? '' : 's'}`),
        )));

        const group = this.groupState.creating ? null : data.groups.find((g) => g.name === this.groupState.selected);
        if (!group && !this.groupState.creating) {
            right.appendChild(el('div', { class: 'card empty-state' }, 'Select a group to view or edit it.'));
            return;
        }
        this.renderGroupEditor(right, group, data);
    },

    renderGroupEditor(pane, group, data) {
        const isNew = !group;
        const editable = this.caps.groups && (this.caps.bootstrap || isNew || group.priority < data.actorPriority);
        const g = group || { name: '', label: '', description: '', priority: 0, inherits: [], permissions: [], system: false, assigned: 0 };
        const name = el('input', { value: g.name, disabled: !isNew, placeholder: 'lowercase_name', spellcheck: 'false' });
        const label = el('input', { value: g.label, disabled: !editable, placeholder: 'Display name' });
        const description = el('input', { value: g.description, disabled: !editable, placeholder: 'What this group is for' });
        const priority = el('input', { type: 'number', value: g.priority, min: 0, max: 1000, disabled: !editable });
        const inherits = el('div', { class: 'checks' }, data.groups.filter((o) => o.name !== g.name).map((o) => {
            const box = el('input', { type: 'checkbox', value: o.name, checked: g.inherits.includes(o.name), disabled: !editable });
            return el('label', { class: `check${editable ? '' : ' disabled'}` }, box, `${o.label}`);
        }));
        const perms = el('textarea', { disabled: !editable, spellcheck: 'false', rows: 8 });
        perms.value = g.permissions.join('\n');
        const addNode = el('input', { placeholder: 'Add a node from the registry', list: 'admin-group-node-list', disabled: !editable });
        addNode.addEventListener('change', () => {
            const v = addNode.value.trim();
            if (v && !perms.value.split('\n').map((s) => s.trim()).includes(v)) perms.value = `${perms.value.trim()}\n${v}`.trim();
            addNode.value = '';
        });
        const f = (l, i) => el('label', { class: 'field' }, el('span', {}, l), i);

        const save = async (e) => {
            const payload = {
                name: name.value.trim(),
                label: label.value.trim(),
                description: description.value.trim(),
                priority: Number(priority.value),
                inherits: $$('input[type="checkbox"]', inherits).filter((b) => b.checked).map((b) => b.value),
                permissions: perms.value.split('\n').map((s) => s.trim()).filter(Boolean),
            };
            await withBusy(e.currentTarget, async () => {
                const res = await this.api(isNew ? 'createGroup' : 'updateGroup', payload);
                if (res.ok) {
                    Toast.show(isNew ? 'Group created.' : 'Group saved.', 'success');
                    this.groupState = { selected: payload.name, creating: false };
                    this.render_groups(clear($('#admin-content')));
                }
            });
        };

        const del = async () => {
            let reassignTo = '';
            if (g.assigned > 0) {
                const options = data.groups.filter((o) => o.name !== g.name).map((o) => ({ value: o.name, label: `Move them to ${o.label}` }));
                const ans = await Modal.open({ title: `Delete ${g.label}?`, body: `${g.assigned} character(s) have this group. Choose where to move them.`, confirmLabel: 'Delete group', input: { options } });
                if (!ans.ok) return;
                reassignTo = ans.value;
            } else {
                const ans = await Modal.open({ title: `Delete ${g.label}?`, body: 'This cannot be undone.', confirmLabel: 'Delete group' });
                if (!ans.ok) return;
            }
            const res = await this.api('deleteGroup', { name: g.name, reassignTo });
            if (res.ok) {
                Toast.show('Group deleted.', 'success');
                this.groupState = { selected: null, creating: false };
                this.render_groups(clear($('#admin-content')));
            }
        };

        pane.appendChild(el('div', { class: 'card' },
            el('h3', {}, isNew ? 'New group' : g.label, el('span', { class: 'chips' },
                g.system ? el('span', { class: 'tag warm' }, 'Built-in') : null,
                !editable && !isNew ? el('span', { class: 'tag' }, 'Read only') : null)),
            el('div', { class: 'field-row' }, f('Internal name', name), f('Display name', label)),
            el('div', { class: 'field-row', style: 'margin-top:10px' }, f('Description', description), el('div', { style: 'max-width:140px' }, f('Priority', priority))),
            el('div', { class: 'sub', style: 'margin:16px 0 8px' }, 'Inherits (this group also gets all permissions of the checked groups)'),
            inherits,
            !isNew && g.effectiveGroups ? el('div', { class: 'muted', style: 'margin-top:8px;font-size:12px' }, `Resolves to: ${g.effectiveGroups.join(' → ')}`) : null,
            el('div', { class: 'sub', style: 'margin:16px 0 8px' }, 'Permission nodes (one per line, wildcards like unitlink.police.* allowed)'),
            perms,
            editable ? el('div', { style: 'margin-top:8px' }, addNode, this.nodeDatalist('admin-group-node-list')) : null,
            el('div', { class: 'actions', style: 'margin-top:14px' },
                !isNew && editable && !g.system ? el('button', { class: 'btn btn-danger btn-sm', onclick: del }, 'Delete') : null,
                editable ? el('button', { class: 'btn btn-primary btn-sm', onclick: save }, isNew ? 'Create group' : 'Save group') : null,
            ),
        ));
    },

    /* ---------------- Permissions ---------------- */
    async render_permissions(content) {
        const nodes = await this.loadNodes(true);
        clear(content);
        const search = el('input', { placeholder: 'Search permission nodes' });
        const tbody = el('tbody', {});
        const render = () => {
            clear(tbody);
            const q = search.value.trim().toLowerCase();
            nodes.filter((n) => !q || n.node.includes(q) || (n.description || '').toLowerCase().includes(q)).forEach((n) => tbody.appendChild(el('tr', {},
                el('td', { class: 'mono' }, n.node), el('td', {}, n.description || el('span', { class: 'muted' }, '-')), el('td', { class: 'muted mono' }, n.resource))));
        };
        search.addEventListener('input', render);
        render();
        const canExplain = this.caps.characters || this.caps.permissions;
        if (canExplain) {
            content.appendChild(el('div', { class: 'card' },
                el('h3', {}, 'Why does a character have (or not have) a permission?'),
                el('div', { class: 'sub' }, 'Order: character overrides (most specific node first), then group grants, then denied.'),
                this.explainTool(null, true)));
        }
        content.appendChild(el('div', { class: 'card' },
            el('h3', {}, 'Registered permission nodes'),
            el('div', { class: 'toolbar' }, search),
            el('table', { class: 'table' }, el('thead', {}, el('tr', {}, el('th', {}, 'Node'), el('th', {}, 'Description'), el('th', {}, 'Source'))), tbody)));
    },

    /* ---------------- Audit ---------------- */
    async render_audit(content) {
        const st = this.auditState;
        const res = await this.api('audit', { page: st.page, action: st.action, characterId: st.characterId ? Number(st.characterId) : null });
        clear(content);
        if (!res.ok) return;
        const actionSel = el('select', { onchange: (e) => { st.action = e.target.value; st.page = 1; this.go('audit'); } },
            el('option', { value: '' }, 'All actions'), AUDIT_ACTIONS.map((a) => el('option', { value: a, selected: a === st.action }, a)));
        const charInput = el('input', { placeholder: 'Character id', value: st.characterId, inputmode: 'numeric', style: 'max-width:150px' });
        charInput.addEventListener('keydown', (e) => { if (e.key === 'Enter') { st.characterId = charInput.value.trim(); st.page = 1; this.go('audit'); } });
        const prev = el('button', { class: 'btn btn-ghost btn-sm', disabled: st.page <= 1, onclick: () => { st.page -= 1; this.go('audit'); } }, 'Newer');
        const next = el('button', { class: 'btn btn-ghost btn-sm', disabled: res.data.entries.length < 50, onclick: () => { st.page += 1; this.go('audit'); } }, 'Older');
        content.appendChild(el('div', { class: 'toolbar' }, actionSel, charInput, el('span', { class: 'muted' }, `Page ${st.page}`), prev, next));
        if (!res.data.entries.length) { content.appendChild(el('div', { class: 'empty-state' }, 'No audit entries.')); return; }
        content.appendChild(el('table', { class: 'table' },
            el('thead', {}, el('tr', {}, el('th', {}, 'Time'), el('th', {}, 'Action'), el('th', {}, 'Actor'), el('th', {}, 'Target'), el('th', {}, 'Details'))),
            el('tbody', {}, res.data.entries.map((e) => el('tr', {},
                el('td', { class: 'muted', style: 'white-space:nowrap' }, new Date(e.timestamp * 1000).toLocaleString()),
                el('td', {}, el('span', { class: 'tag accent' }, e.action)),
                el('td', { class: 'mono' }, e.actor || '-', e.actorCharacterId ? el('div', { class: 'muted' }, `char #${e.actorCharacterId}`) : null),
                el('td', { class: 'mono' }, e.targetCharacterId ? `#${e.targetCharacterId}` : '-'),
                el('td', { class: 'mono muted', style: 'max-width:420px;word-break:break-word' }, e.details ? JSON.stringify(e.details) : ''),
            )))));
    },
};

App.register('admin', Admin);
$('[data-action="admin-close"]').addEventListener('click', () => post('admin:close').then(() => App.close()));
