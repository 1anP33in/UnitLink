/* UnitLink Core NUI - character creation form.
 * Client-side checks only give fast feedback; the server validates everything again. */
'use strict';

const Creation = {
    slot: null,
    rules: null,
    gender: null,

    show(slot, rules) {
        this.slot = slot;
        this.rules = rules || {};
        const form = $('#creation-form');
        form.reset();
        this.clearErrors();
        $('#selection-list').hidden = true;
        $('#selection-error').hidden = true;
        form.hidden = false;

        const r = this.rules;
        const dob = form.elements.dateofbirth;
        if (r.today) {
            const [y, m, d] = r.today.split('-').map(Number);
            const pad = (n) => String(n).padStart(2, '0');
            dob.max = `${y - (r.ageMin || 18)}-${pad(m)}-${pad(d)}`;
            dob.min = `${y - (r.ageMax || 90)}-${pad(m)}-${pad(d)}`;
            dob.value = `${y - 25}-${pad(m)}-${pad(d)}`;
        }
        const height = form.elements.height;
        height.min = r.heightMin || 140;
        height.max = r.heightMax || 210;
        height.value = Math.round(((r.heightMin || 140) + (r.heightMax || 210)) / 2);

        const nat = clear(form.elements.nationality);
        nat.appendChild(el('option', { value: '' }, 'Select a nationality'));
        (r.nationalities || []).forEach((n) => nat.appendChild(el('option', { value: n }, n)));

        const genders = clear($('#gender-options'));
        this.gender = null;
        (r.genders || []).forEach((g) => {
            genders.appendChild(el('button', {
                type: 'button',
                dataset: { value: g.value },
                onclick: () => this.setGender(g.value),
            }, g.label));
        });
        if ((r.genders || [])[0]) this.setGender(r.genders[0].value);

        setTimeout(() => form.elements.firstname.focus(), 50);
    },

    hide() {
        $('#creation-form').hidden = true;
        $('#selection-list').hidden = false;
    },

    setGender(value) {
        this.gender = value;
        $$('#gender-options button').forEach((b) => b.classList.toggle('active', b.dataset.value === value));
    },

    clearErrors() {
        $$('#creation-form .field-error').forEach((n) => { n.textContent = ''; });
        $$('#creation-form .invalid').forEach((n) => n.classList.remove('invalid'));
        $('#creation-error').hidden = true;
    },

    fieldError(field, message) {
        const slot = $(`#creation-form [data-error-for="${field}"]`);
        if (slot) slot.textContent = message;
        const input = $('#creation-form').elements[field];
        if (input && input.classList) input.classList.add('invalid');
    },

    validName(value) {
        const r = this.rules;
        if (value.length < (r.nameMin || 2) || value.length > (r.nameMax || 20)) return false;
        return /^[A-Za-z]+(?:[ '-][A-Za-z]+)*$/.test(value);
    },

    collect() {
        const f = $('#creation-form').elements;
        return {
            firstname: f.firstname.value.trim().replace(/\s+/g, ' '),
            lastname: f.lastname.value.trim().replace(/\s+/g, ' '),
            dateofbirth: f.dateofbirth.value,
            height: Number(f.height.value),
            gender: this.gender,
            nationality: f.nationality.value,
            slot: this.slot,
        };
    },

    validate(data) {
        const r = this.rules;
        let ok = true;
        const nameMsg = `Use ${r.nameMin || 2}-${r.nameMax || 20} letters. Spaces, hyphens and apostrophes are allowed between letters.`;
        if (!this.validName(data.firstname)) { this.fieldError('firstname', nameMsg); ok = false; }
        if (!this.validName(data.lastname)) { this.fieldError('lastname', nameMsg); ok = false; }
        if (!/^\d{4}-\d{2}-\d{2}$/.test(data.dateofbirth)) {
            this.fieldError('dateofbirth', `Pick a birth date (age ${r.ageMin}-${r.ageMax}).`); ok = false;
        }
        if (!Number.isInteger(data.height) || data.height < r.heightMin || data.height > r.heightMax) {
            this.fieldError('height', `Between ${r.heightMin} and ${r.heightMax} cm.`); ok = false;
        }
        if (!data.gender) { this.fieldError('gender', 'Choose a gender.'); ok = false; }
        if (!data.nationality) { this.fieldError('nationality', 'Choose a nationality.'); ok = false; }
        return ok;
    },

    async submit(button) {
        this.clearErrors();
        const data = this.collect();
        if (!this.validate(data)) return;
        await withBusy(button, async () => {
            const res = await post('selection:create', data);
            if (!res.ok) {
                if (res.field) this.fieldError(res.field, res.error);
                else {
                    const banner = $('#creation-error');
                    banner.textContent = res.error;
                    banner.hidden = false;
                }
                return;
            }
            Toast.show(`Welcome to the city, ${data.firstname}. Time to pick your look.`, 'success');
        });
    },
};

$('#creation-form').addEventListener('submit', (e) => {
    e.preventDefault();
    Creation.submit(e.submitter || $('#creation-form button[type="submit"]'));
});
$('[data-action="cancel-create"]').addEventListener('click', () => {
    Creation.hide();
    Selection.render();
});
