/* UnitLink Core NUI - character selection. */
'use strict';

const Selection = {
    data: null,
    selectedId: null,
    previewTimer: null,

    show(payload) {
        this.data = payload;
        this.selectedId = null;
        Creation.hide();
        $('#selection-list').hidden = false;
        const err = $('#selection-error');
        err.hidden = !payload.error;
        err.textContent = payload.error || '';
        if (payload.serverName) $$('[data-brand-name]').forEach((n) => { n.textContent = payload.serverName; });
        this.render();
        // Preview the first character so the scene is not empty.
        const first = (payload.characters || [])[0];
        if (first) this.select(first.id);
    },

    hide() {
        Creation.hide();
    },

    render() {
        const list = clear($('#selection-list'));
        const data = this.data || {};
        const chars = data.characters || [];
        const max = data.maxSlots || 0;
        const bySlot = {};
        chars.forEach((c) => { bySlot[c.slot] = c; });

        for (let slot = 1; slot <= max; slot++) {
            const c = bySlot[slot];
            list.appendChild(c ? this.card(c) : this.emptyCard(slot));
        }
        // Characters in slots above the current limit (if the limit was lowered).
        chars.filter((c) => c.slot > max).forEach((c) => list.appendChild(this.card(c)));

        const used = chars.length;
        $('[data-slot-summary]').textContent = max ? `${used} of ${max} character slots used` : '';
    },

    card(c) {
        const selected = c.id === this.selectedId;
        const card = el('div', { class: `char-card${selected ? ' selected' : ''}`, dataset: { id: c.id }, onclick: () => this.select(c.id) },
            el('div', { class: 'row' },
                el('div', { class: 'char-name' }, c.fullname || `${c.firstname} ${c.lastname}`),
                c.group ? el('span', { class: 'tag accent' }, c.group) : null,
            ),
            el('div', { class: 'char-id' }, `Character #${c.id}`),
            el('dl', { class: 'char-meta' },
                el('div', {}, el('dt', {}, 'Born'), el('dd', {}, formatDate(c.dateofbirth))),
                el('div', {}, el('dt', {}, 'Nationality'), el('dd', {}, c.nationality || '-')),
                el('div', {}, el('dt', {}, 'Gender'), el('dd', {}, capitalize(c.gender))),
                el('div', {}, el('dt', {}, 'Height'), el('dd', {}, c.height ? `${c.height} cm` : '-')),
            ),
            el('div', { class: 'card-actions' },
                el('button', { class: 'btn btn-primary', onclick: (e) => { e.stopPropagation(); this.play(c, e.currentTarget); } }, 'Play'),
                el('button', { class: 'btn btn-danger', title: 'Delete character', onclick: (e) => { e.stopPropagation(); this.remove(c); } }, 'Delete'),
            ),
        );
        return card;
    },

    emptyCard(slot) {
        return el('div', { class: 'char-card empty', onclick: () => Creation.show(slot, (this.data || {}).rules) },
            el('div', { class: 'plus' }, '+'),
            el('div', {},
                el('div', { style: 'font-weight:700;color:var(--text)' }, 'Create a character'),
                el('div', { style: 'font-size:12px;margin-top:2px' }, `Empty slot ${slot}`),
            ),
        );
    },

    select(id) {
        if (this.selectedId === id) return;
        this.selectedId = id;
        $$('.char-card[data-id]').forEach((n) => n.classList.toggle('selected', Number(n.dataset.id) === id));
        // Debounce previews so clicking through cards does not spam the server.
        clearTimeout(this.previewTimer);
        this.previewTimer = setTimeout(async () => {
            const res = await post('selection:preview', { id });
            if (!res.ok) Toast.show(res.error, 'error');
        }, 180);
    },

    async play(c, button) {
        await withBusy(button, async () => {
            const res = await post('selection:select', { id: c.id });
            if (!res.ok) Toast.show(res.error, 'error');
        });
    },

    async remove(c) {
        const name = `${c.firstname} ${c.lastname}`;
        const rules = (this.data || {}).rules || {};
        const answer = await Modal.open({
            title: `Delete ${name}?`,
            body: rules.confirmDelete
                ? `This permanently deletes the character, their appearance, groups and permissions. Type "${name}" to confirm.`
                : 'This permanently deletes the character, their appearance, groups and permissions.',
            confirmLabel: 'Delete forever',
            requireText: rules.confirmDelete ? name : null,
        });
        if (!answer.ok) return;
        const res = await post('selection:delete', { id: c.id, confirm: answer.value || '' });
        if (!res.ok) { Toast.show(res.error, 'error'); return; }
        Toast.show(`${name} was deleted.`, 'success');
        this.show(res.data);
    },
};

App.register('selection', Selection);
