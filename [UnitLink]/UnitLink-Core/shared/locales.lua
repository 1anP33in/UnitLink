-- UnitLink Core: locale strings. Error codes from UnitLink.Errors map to readable text here.

UnitLink = UnitLink or {}

local Locales = {
    en = {
        not_ready = 'The server is still starting. Please try again in a moment.',
        rate_limited = 'You are doing that too quickly. Please wait a moment.',
        invalid_input = 'Some of the information you entered is not valid.',
        invalid_state = 'That action is not available right now.',
        not_found = 'That record could not be found.',
        not_owner = 'That character does not belong to you.',
        no_slots = 'All of your character slots are in use.',
        slot_taken = 'That character slot is already in use.',
        name_taken = 'A character with that name already exists.',
        already_active = 'That character is already in use.',
        no_character = 'You do not have an active character.',
        unauthorized = 'You do not have permission to do that.',
        hierarchy = 'You cannot manage someone at or above your own rank.',
        database_error = 'A database error occurred. Please try again.',
        internal_error = 'Something went wrong. Please try again.',
        inheritance_cycle = 'That inheritance would create a loop between groups.',
        unknown_group = 'That group does not exist.',
        group_exists = 'A group with that name already exists.',
        group_in_use = 'That group is still assigned to characters. Choose a group to move them to.',
        group_inherited = 'Other groups inherit from that group. Remove that inheritance first.',
        system_group = 'Built-in groups cannot be deleted.',
        duplicate = 'That is already set.',
        confirm_mismatch = 'The confirmation text does not match.',
        spawn_unavailable = 'That spawn location is not available to this character.',
        timeout = 'The server did not respond in time.',
        discord_managed = 'That group comes from a Discord role. Give or remove the role on Discord instead.',
        discord_role_required = 'This player does not have the Discord role that unlocks that group.',

        -- Field-level validation
        field_firstname = 'First name must be %d-%d letters (spaces, hyphens and apostrophes allowed between letters).',
        field_lastname = 'Last name must be %d-%d letters (spaces, hyphens and apostrophes allowed between letters).',
        field_dateofbirth = 'Date of birth must be a real date and your character must be %d-%d years old.',
        field_gender = 'Choose a gender.',
        field_nationality = 'Choose a nationality from the list.',
        field_height = 'Height must be between %d and %d cm.',

        -- Misc
        switch_started = 'Returning to character selection...',
        appearance_saved = 'Appearance saved.',
        appearance_unavailable = 'The appearance editor is not available.',
        no_permission_command = 'You do not have permission to use this command.',
    },
}

function UnitLink.T(key, ...)
    local lang = (Config and Config.Locale) or 'en'
    local tbl = Locales[lang] or Locales.en
    local str = tbl[key] or Locales.en[key] or key
    if select('#', ...) > 0 then
        local ok, formatted = pcall(string.format, str, ...)
        if ok then return formatted end
    end
    return str
end

function UnitLink.FieldMessage(field)
    local c = Config.Characters
    if field == 'firstname' or field == 'lastname' then
        return UnitLink.T('field_' .. field, c.Names.MinLength, c.Names.MaxLength)
    elseif field == 'dateofbirth' then
        return UnitLink.T('field_dateofbirth', c.Age.Min, c.Age.Max)
    elseif field == 'height' then
        return UnitLink.T('field_height', c.Height.Min, c.Height.Max)
    end
    return UnitLink.T('field_' .. tostring(field))
end
