---------------------------------------------------------------------
-- Chat commands + rebindable keys (Settings > Key Bindings > FiveM)
---------------------------------------------------------------------
local C = Config.Commands
local K = Police.KeyCommands

local function thread(fn)
    return function(...)
        local args = table.pack(...)
        CreateThread(function() fn(table.unpack(args, 1, args.n)) end)
    end
end

---------------------------------------------------------------------
-- Chat commands
---------------------------------------------------------------------
RegisterCommand(C.duty, function(_, args) DutyMenu.command(args) end, false)
RegisterCommand(C.roster, thread(function() RosterMenu.open() end), false)
RegisterCommand(C.calls, thread(function() CallsMenu.open() end), false)
RegisterCommand(C.panic, function() PanicClient.trigger() end, false)
RegisterCommand(C.call, function(_, args)
    -- the server validates length, cooldown and location
    TriggerServerEvent('tsrp-police:server:submitCall', table.concat(args, ' '), Police.myStreet())
end, false)

---------------------------------------------------------------------
-- Keys
---------------------------------------------------------------------
local keys = {
    { name = K.duty,     key = Config.Keybinds.duty,     label = 'Police: duty menu',                fn = thread(function() DutyMenu.open() end) },
    { name = K.calls,    key = Config.Keybinds.calls,    label = 'Police: active 911 calls',         fn = thread(function() CallsMenu.open() end) },
    { name = K.panic,    key = Config.Keybinds.panic,    label = 'Police: panic button',             fn = function() PanicClient.trigger() end },
    { name = K.accept,   key = Config.Keybinds.accept,   label = 'Police: accept newest 911 call',   fn = function() CallsMenu.keyAccept() end },
    { name = K.deny,     key = Config.Keybinds.deny,     label = 'Police: deny newest 911 call',     fn = function() CallsMenu.keyDeny() end },
    { name = K.waypoint, key = Config.Keybinds.waypoint, label = 'Police: waypoint to panic / call', fn = function() CallsMenu.keyWaypoint() end },
}

for _, k in ipairs(keys) do
    RegisterCommand(k.name, k.fn, false)
    RegisterKeyMapping(k.name, k.label, 'keyboard', k.key or '')
end

---------------------------------------------------------------------
-- Chat suggestions (and hide the key-only commands)
---------------------------------------------------------------------
CreateThread(function()
    Wait(1000)
    TriggerEvent('chat:addSuggestion', '/' .. C.duty, 'Open the duty menu', {
        { name = 'on | off', help = 'optional: /' .. C.duty .. ' on <department> <callsign>' },
    })
    TriggerEvent('chat:addSuggestion', '/' .. C.roster, 'On-duty law enforcement roster')
    TriggerEvent('chat:addSuggestion', '/' .. C.calls, 'Active 911 calls')
    TriggerEvent('chat:addSuggestion', '/' .. C.panic, 'Officer panic button')
    TriggerEvent('chat:addSuggestion', '/' .. C.call, 'Call emergency services', {
        { name = 'message', help = 'What is happening' },
    })
    for _, k in ipairs(keys) do TriggerEvent('chat:removeSuggestion', '/' .. k.name) end
end)
