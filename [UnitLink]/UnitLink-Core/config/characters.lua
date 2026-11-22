-- UnitLink Core: character rules (shared so the NUI can show the same limits the server
-- enforces; the server re-validates everything regardless).

Config = Config or {}

Config.Characters = {
    -- Character slots per account. 3 is the default and the maximum for launch.
    MaxSlots = 3,
    HardSlotLimit = 3, -- MaxSlots is clamped to this value

    Names = {
        MinLength = 2,
        MaxLength = 20,
        -- Letters with single inner spaces, hyphens or apostrophes ("Mary-Jane", "O'Neil").
        UniqueFullName = true, -- reject a first+last name that already exists server-wide
    },

    Age = { Min = 18, Max = 90 },

    Height = { Min = 140, Max = 210 }, -- centimetres

    Genders = {
        { value = 'male', label = 'Male' },
        { value = 'female', label = 'Female' },
    },

    Nationalities = {
        'American', 'Bahamian', 'Brazilian', 'British', 'Canadian', 'Chinese', 'Colombian',
        'Cuban', 'Dominican', 'Filipino', 'French', 'German', 'Haitian', 'Indian', 'Irish',
        'Italian', 'Jamaican', 'Japanese', 'Korean', 'Mexican', 'Nigerian', 'Puerto Rican',
        'Russian', 'Spanish', 'Venezuelan', 'Vietnamese',
    },

    -- Switching characters in-game needs unitlink.character.switch on the active character.
    SwitchRequiresPermission = true,

    -- Deleting needs the player to type the character's full name in the confirm box.
    DeleteRequiresNameConfirmation = true,
}

-- Metadata limits (server-side validation).
Config.Metadata = {
    MaxKeyLength = 64,
    MaxEncodedBytes = 65535,
}
