/* UnitLink Core NUI - spawn selection. Only ids are sent back; the server owns coordinates. */
'use strict';

const Spawn = {
    selected: null,

    show(payload) {
        const c = payload.character;
        $('#spawn-character-name').textContent = c ? (c.fullname || `${c.firstname} ${c.lastname}`) : 'Welcome';
        $('#spawn-error').hidden = true;
        const list = clear($('#spawn-list'));
        const spawns = payload.spawns || [];
        this.selected = null;
        if (!spawns.length) {
            list.appendChild(el('div', { class: 'empty-state' }, 'No spawn locations are available.'));
        }
        spawns.forEach((s) => {
            list.appendChild(el('div', { class: 'spawn-item', dataset: { id: s.id }, onclick: () => this.select(s.id), ondblclick: () => this.go() },
                el('div', { class: 'title' },
                    el('span', {}, s.label),
                    s.last ? el('span', { class: 'tag warm' }, 'Last') : (s.default ? el('span', { class: 'tag accent' }, 'Default') : null),
                ),
                s.description ? el('div', { class: 'desc' }, s.description) : null,
            ));
        });
        const preferred = spawns.find((s) => s.last) || spawns.find((s) => s.default) || spawns[0];
        if (preferred) this.select(preferred.id);
        else $('[data-action="spawn-go"]').disabled = true;
    },

    hide() {},

    select(id) {
        this.selected = id;
        $$('.spawn-item').forEach((n) => n.classList.toggle('selected', n.dataset.id === id));
        $('[data-action="spawn-go"]').disabled = !id;
    },

    async go() {
        if (!this.selected) return;
        const button = $('[data-action="spawn-go"]');
        await withBusy(button, async () => {
            const res = await post('spawn:select', { id: this.selected });
            if (!res.ok) {
                const banner = $('#spawn-error');
                banner.textContent = res.error;
                banner.hidden = false;
            }
        });
    },
};

App.register('spawn', Spawn);
$('[data-action="spawn-go"]').addEventListener('click', () => Spawn.go());
$('[data-action="spawn-back"]').addEventListener('click', () => post('spawn:back'));
