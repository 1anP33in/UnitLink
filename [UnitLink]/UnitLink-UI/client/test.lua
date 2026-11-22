-- /uitest <component> : shows each component with example data
if not Config.TestCommand then return end

local tests = {}

tests.notify = function()
    local list = {
        function() Notify('Vehicle stored in **Legion Square Garage**.', 'success') end,
        function() Notify("You can't do that right now.", 'error') end,
        function() Notify('Your fuel is running low.', 'warning') end,
        function() Notify('Press **E** to open the menu.', 'info') end,
        function() Notify({ type = 'announce', title = 'Restart in 15 minutes', message = 'Please find a safe spot and log off.' }) end,
        function() Notify({ type = 'sms', title = 'Jake Miller', message = 'You still coming to the creek tonight?' }) end,
        function() Dispatch({ dept = 'police', code = '10-31', title = 'Robbery in Progress', message = 'Silent alarm at the general store.', priority = 1, location = 'Main St' }) end,
        function() Dispatch({ dept = 'safr', code = 'Structure Fire', title = 'Working Fire', message = 'Smoke showing from a barn.', priority = 2, location = 'Grapeseed Ave' }) end,
    }
    for i, fn in ipairs(list) do SetTimeout((i - 1) * 300, fn) end
end

tests.progress = function()
    local done = ProgressBar({
        duration = 5000, label = 'Repairing Engine', description = 'Keep still while you work', icon = 'wrench',
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'mini@repair', clip = 'fixing_a_player' },
    })
    Notify(done and 'Engine repaired.' or 'Repair cancelled.', done and 'success' or 'error')
    if not done then return end
    ProgressBar({ duration = 6000, label = 'Crafting Lockpick', icon = 'box', color = '#a77bf3', steps = { 'Cutting metal', 'Shaping pins', 'Filing edges', 'Assembling' } })
end

tests.alert = function()
    local result = AlertDialog({
        header = 'Scrap vehicle?', subheader = "This can't be undone",
        content = 'You are about to scrap your **Bison 4x4**.', type = 'danger', icon = 'warning',
        callout = { type = 'warning', label = 'Heads up', text = 'Anything left in the trunk will be lost.' },
        labels = { confirm = 'Scrap Vehicle', cancel = 'Keep It' },
    })
    Notify('Alert result: **' .. result .. '**', 'info')
end

tests.input = function()
    local values = InputDialog('Register Vehicle', {
        { type = 'input', label = 'Plate', placeholder = 'e.g. UnitLink 001', icon = 'tag', required = true, max = 8, description = 'Up to 8 characters' },
        { type = 'input', label = 'PIN', icon = 'lock', password = true },
        { type = 'number', label = 'Spare keys', min = 0, max = 5, default = 1 },
        { type = 'select', label = 'Garage', icon = 'garage', options = { { value = 'lotA', label = 'Lot A' }, { value = 'lotB', label = 'Lot B' }, { value = 'barn', label = 'Barn' } }, default = 'lotB' },
        { type = 'multi-select', label = 'Extras', options = { 'Tracker', 'Roadside', 'Tint permit' }, default = { 'Tracker' } },
        { type = 'slider', label = 'Window tint', min = 0, max = 100, step = 5, default = 35 },
        { type = 'color', label = 'Primary color', default = '#3ba7ff' },
        { type = 'date', label = 'Registration date' },
        { type = 'textarea', label = 'Notes', placeholder = 'Anything the DMV should know?' },
        { type = 'toggle', label = 'Auto-renew', description = 'Renew when it expires', default = true },
        { type = 'checkbox', label = 'I agree to the DMV terms', required = true },
    }, { icon = 'edit', description = 'Fill out the DMV form' })
    if not values then return Notify('Form cancelled.', 'warning') end
    Notify('Registered plate **' .. tostring(values[1]) .. '**.', 'success')
    print('[UnitLink-UI] input values: ' .. json.encode(values))
end

tests.context = function()
    RegisterContext({
        {
            id = 'uitest_garage', title = 'Legion Square Garage', description = 'Lot B', icon = 'garage',
            options = {
                { title = 'Retrieve Vehicle', description = '3 vehicles stored', icon = 'car', menu = 'uitest_vehicles' },
                { title = 'Fuel Level', description = 'Bison 4x4', icon = 'fuel', iconColor = '#22c38a', progress = 65, progressColor = '#22c38a' },
                { title = 'Vehicle Info', description = 'Hover for details', icon = 'info', metadata = { { label = 'Plate', value = 'UnitLink 001' }, { label = 'Engine', value = '92%', progress = 92 }, { label = 'Body', value = '78%', progress = 78 } } },
                { title = 'Give Keys', description = 'Share with a nearby player', icon = 'key', keybind = 'K', onSelect = function() Notify('Keys given.', 'success') end },
                { title = 'Impound Lot', description = 'Requires police access', icon = 'ban', disabled = true },
                { title = 'Lot B · 12 spaces free', icon = 'pin', readOnly = true },
            },
        },
        {
            id = 'uitest_vehicles', title = 'Retrieve Vehicle', description = '3 stored', icon = 'car', menu = 'uitest_garage',
            options = {
                { title = 'Bison 4x4', description = 'UnitLink 001', icon = 'car', metadata = { Fuel = '65%', Mileage = '12,480 mi' }, onSelect = function() Notify('Bison 4x4 is out front.', 'success') end },
                { title = 'Sandking XL', description = 'CREEK 22', icon = 'car', metadata = { Fuel = '30%', Mileage = '48,102 mi' }, onSelect = function() Notify('Sandking XL is out front.', 'success') end },
                { title = 'Rebla GTS', description = 'Needs repairs', icon = 'car', iconColor = '#f5a524', metadata = { { label = 'Engine', value = '41%', progress = 41 } }, disabled = true },
            },
        },
    })
    ShowContext('uitest_garage')
end

tests.list = function()
    RegisterList({
        id = 'uitest_list', title = "Benny's Customs", subtitle = 'Bison 4x4', icon = 'spray',
        options = {
            { label = 'Respray', icon = 'spray', description = 'Primary color', values = { 'Red', 'Forest Green', 'Midnight Blue', 'Matte Black', 'White' } },
            { label = 'Wheels', icon = 'wheel', values = { { label = 'Stock', description = 'Factory wheels' }, { label = 'Rugged', description = 'Off-road rims' }, { label = 'Beadlock', description = 'For rock crawling' } } },
            { label = 'Engine', icon = 'engine', description = 'Level 2 of 4', progress = 50 },
            { label = 'Neon Kit', icon = 'light', description = 'Underglow lights', checkbox = true },
            { label = 'Window Tint', icon = 'sun', values = { 'None', 'Light', 'Dark', 'Limo' }, defaultIndex = 3 },
            { label = 'Turbo', icon = 'turbo', description = 'Requires engine level 3', disabled = true },
            { label = 'Apply Changes', icon = 'check', description = 'Save and close' },
        },
        onSideScroll = function(sel, scroll) print(('[UnitLink-UI] row %d -> value %d'):format(sel, scroll)) end,
        onCheck = function(sel, checked) Notify(checked and 'Neon on.' or 'Neon off.', 'info') end,
        onClose = function(key) Notify('List closed (' .. tostring(key) .. ').', 'info') end,
    }, function(selected)
        Notify('Selected row **' .. selected .. '**.', 'success')
    end)
    ShowList('uitest_list')
end

tests.radial = function()
    RegisterRadial({
        id = 'uitest_vehicle', title = 'Vehicle',
        items = {
            { label = 'Engine', icon = 'engine', description = 'Toggle engine', onSelect = function() Notify('Engine toggled.', 'info') end },
            { label = 'Doors', icon = 'door', description = 'Open / close' },
            { label = 'Windows', icon = 'window', description = 'Roll up / down' },
            { label = 'Interior', icon = 'light', description = 'Dome light', keepOpen = true },
            { label = 'Lock', icon = 'lock', description = 'Lock vehicle', onSelect = function() Notify('Vehicle locked.', 'success') end },
        },
    })
    AddRadialItem({
        { id = 'uitest_vehicle', label = 'Vehicle', icon = 'car', description = 'Doors, engine…', menu = 'uitest_vehicle' },
        { id = 'uitest_emotes', label = 'Emotes', icon = 'smile', description = 'Play an emote' },
        { id = 'uitest_clothing', label = 'Clothing', icon = 'shirt', description = 'Toggle items' },
        { id = 'uitest_phone', label = 'Phone', icon = 'phone', description = '3 unread', badge = 3 },
        { id = 'uitest_fuel', label = 'Fuel', icon = 'fuel', description = '65% left', progress = 65, readOnly = true },
        { id = 'uitest_walk', label = 'Walk Style', icon = 'walk', description = 'Change how you walk' },
        { id = 'uitest_map', label = 'Map', icon = 'map', description = 'Set a waypoint' },
    })
    Notify(('Radial items added. Press **%s** to open it.'):format(Config.Radial.key), 'info')
end

tests.text = function()
    local samples = {
        { key = 'E', title = 'Open Garage', description = 'Legion Square · Lot B' },
        { key = 'E', title = 'Refuel Vehicle', description = 'Pump 3', icon = 'fuel', color = '#22c38a' },
        { title = 'Gas Station', description = 'Route 68', options = { { key = 'E', label = 'Refuel', icon = 'fuel' }, { key = 'G', label = 'Jerry Can', icon = 'box' }, { key = 'H', label = 'Car Wash', icon = 'drop' } } },
        { key = 'E', title = 'Talk' },
    }
    for i, s in ipairs(samples) do
        SetTimeout((i - 1) * 2500, function() ShowTextUI(s) end)
    end
    SetTimeout(#samples * 2500, HideTextUI)
end

tests.skill = function()
    local ok = SkillCheck({ 'easy', 'medium', 'hard' }, { 'E', 'Q' })
    Notify(ok and 'Skill check passed.' or 'Skill check failed.', ok and 'success' or 'error')
end

tests.breach = function()
    local ok = SignalBreach('medium', { onNode = function(i) print('[UnitLink-UI] node ' .. i) end })
    Notify(ok and 'Breach complete.' or 'Signal lost.', ok and 'success' or 'error')
end

tests.pattern = function()
    local ok = PatternLock('medium')
    Notify(ok and 'Unlocked.' or 'Wrong pattern.', ok and 'success' or 'error')
end

local names = {}
for k in pairs(tests) do names[#names + 1] = k end
table.sort(names)

RegisterCommand('uitest', function(_, args)
    local fn = tests[(args[1] or ''):lower()]
    if not fn then
        return Notify('Use /uitest ' .. table.concat(names, ' | '), 'info')
    end
    CreateThread(fn)
end, false)

TriggerEvent('chat:addSuggestion', '/uitest', 'Show an UnitLink-UI component', {
    { name = 'component', help = table.concat(names, ', ') },
})
