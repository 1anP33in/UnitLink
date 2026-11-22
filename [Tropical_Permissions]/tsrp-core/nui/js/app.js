/* TSRP Core NUI - view switching, toasts, modal, keyboard. */
'use strict';

const App = {
    view: null,
    views: {},          // name -> { show(payload), hide() }
    register(name, impl) { this.views[name] = impl; },

    open(view, payload) {
        if (this.view && this.view !== view) this.hideCurrent();
        this.view = view;
        const node = document.getElementById(`view-${view}`);
        if (node) node.hidden = false;
        const impl = this.views[view];
        if (impl && impl.show) impl.show(payload || {});
    },

    hideCurrent() {
        if (!this.view) return;
        const node = document.getElementById(`view-${this.view}`);
        if (node) node.hidden = true;
        const impl = this.views[this.view];
        if (impl && impl.hide) impl.hide();
        this.view = null;
    },

    close() {
        Modal.close(false);
        this.hideCurrent();
    },
};

on('open', (data) => App.open(data.view, data.payload));
on('close', () => App.close());
on('toast', (data) => Toast.show(data.message, data.kind));

/* Toasts */
const Toast = {
    show(message, kind) {
        if (!message) return;
        const node = el('div', { class: `toast ${kind || 'info'}` }, message);
        $('#toasts').appendChild(node);
        setTimeout(() => {
            node.classList.add('out');
            setTimeout(() => node.remove(), 260);
        }, kind === 'error' ? 5200 : 3600);
    },
};

/* Confirm modal. Optional `requireText`: the user must type it exactly (case-insensitive). */
const Modal = {
    resolver: null,
    open({ title, body, confirmLabel, danger, requireText, input }) {
        $('#modal-title').textContent = title || 'Are you sure?';
        $('#modal-body').textContent = body || '';
        const extra = clear($('#modal-extra'));
        const confirmBtn = $('#modal-confirm');
        confirmBtn.textContent = confirmLabel || 'Confirm';
        confirmBtn.className = `btn ${danger === false ? 'btn-primary' : 'btn-danger'}`;
        let field = null;
        if (requireText || input) {
            field = el('input', { placeholder: requireText || (input && input.placeholder) || '', autocomplete: 'off', spellcheck: 'false' });
            if (input && input.options) {
                field = el('select', {}, input.options.map((o) => el('option', { value: o.value }, o.label)));
            }
            extra.appendChild(field);
            if (requireText) {
                confirmBtn.disabled = true;
                field.addEventListener('input', () => {
                    confirmBtn.disabled = field.value.trim().replace(/\s+/g, ' ').toLowerCase() !== requireText.toLowerCase();
                });
            } else {
                confirmBtn.disabled = false;
            }
            setTimeout(() => field.focus(), 30);
        } else {
            confirmBtn.disabled = false;
        }
        $('#modal').hidden = false;
        return new Promise((resolve) => {
            this.resolver = (ok) => resolve(ok ? { ok: true, value: field ? field.value : null } : { ok: false });
        });
    },
    close(ok) {
        if ($('#modal').hidden) return;
        $('#modal').hidden = true;
        const r = this.resolver;
        this.resolver = null;
        if (r) r(ok);
    },
};

$('#modal-cancel').addEventListener('click', () => Modal.close(false));
$('#modal-confirm').addEventListener('click', () => Modal.close(true));

document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    if (!$('#modal').hidden) { Modal.close(false); return; }
    if (App.view === 'admin') post('admin:close').then(() => App.close());
});

/** Button busy helper. */
async function withBusy(button, fn) {
    if (!button) return fn();
    button.classList.add('loading');
    button.disabled = true;
    try { return await fn(); } finally {
        button.classList.remove('loading');
        button.disabled = false;
    }
}

function formatDate(iso) {
    if (!iso) return '-';
    const [y, m, d] = String(iso).split('-').map(Number);
    if (!y) return iso;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return `${months[m - 1]} ${d}, ${y}`;
}

function capitalize(s) { return s ? s.charAt(0).toUpperCase() + s.slice(1) : ''; }

window.addEventListener('load', async () => {
    const res = await post('ready');
    if (res && res.branding && res.branding.name) {
        $$('[data-brand-name]').forEach((n) => { n.textContent = res.branding.name; });
    }
    if (!IN_GAME) DevMock.boot();
});
