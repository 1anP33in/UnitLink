# tsrp-ui

Standalone UI kit for FiveM (no framework needed). It includes notifications, a progress bar, alert and input dialogs, context, list and radial menus, text UI, and three mini games, all in one matching style.

## Install

1. Drop `tsrp-ui` into your resources folder.
2. Add `ensure tsrp-ui` to `server.cfg`, before any script that uses it.
3. In game, run `/uitest <component>` to see each one: `notify`, `progress`, `alert`, `input`, `context`, `list`, `radial`, `text`, `skill`, `breach`, `pattern`.

Every setting is in `config.lua`: accent color, scale, positions, notification types, police/SAFR styles, flashing, priorities, and mini game difficulty.

Functions that wait for the player (progress, alert, input, mini games) block until they finish. Call them from a thread or a command handler. Examples below use `local UI = exports['tsrp-ui']`.

Icons are given by name: `check x warning info announce sms badge fire medical bell pin wrench box edit tag lock unlock eye plus minus card calendar garage car fuel key ban spray wheel bolt sun turbo smile shirt phone walk dots door engine window light target signal grid drop user users home map gear trash search clock star heart hand paw tree fish`. Add more in `html/js/core.js`.

Text in messages and descriptions supports `**bold**` and `\n`.

---

## Notifications

```lua
UI:Notify('Vehicle stored.', 'success', 5000)
UI:Notify({ type = 'info', title = 'Garage', message = 'Press **E** to open.', duration = 5000, icon = 'garage', id = 'garage_hint' })
-- types: success | error | warning | info | announce | sms
-- same id updates the card already on screen; duration 0 = stays until removed

UI:Dispatch({ dept = 'police', code = '10-31', title = 'Robbery in Progress', message = '...', priority = 1, location = 'Main St' })
-- dept: police | safr, priority 1 (highest) to 3, flash = true/false overrides config

UI:RemoveNotify(id)
UI:ClearNotify()
```

Server side:

```lua
exports['tsrp-ui']:Notify(source, 'Welcome!', 'info')        -- -1 = everyone
exports['tsrp-ui']:Dispatch({ 3, 7 }, { dept = 'safr', title = 'Working Fire', priority = 1 })
```

## Progress bar

```lua
local finished = UI:ProgressBar({
    duration = 5000, label = 'Repairing Engine', description = 'Keep still', icon = 'wrench', color = '#3ba7ff',
    steps = { 'Cutting', 'Shaping', 'Assembling' },  -- optional segmented bar
    canCancel = true,                                -- X to cancel
    disable = { move = true, sprint = true, car = true, combat = true, mouse = false },
    anim = { dict = 'mini@repair', clip = 'fixing_a_player', flag = 49 },  -- or { scenario = 'WORLD_HUMAN_WELDING' }
    prop = { model = 'prop_tool_wrench', bone = 57005, pos = vec3(0.1, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) },  -- or a list
    allowDead = false, allowRagdoll = false, allowCuffed = false, allowFalling = false, allowSwimming = false,
})
UI:CancelProgress()
UI:IsProgressActive()
```

## Alert dialog

```lua
local result = UI:AlertDialog({
    header = 'Scrap vehicle?', subheader = "This can't be undone",
    content = 'You are about to scrap your **Bison**.',
    type = 'danger',  -- info | success | warning | danger | error
    icon = 'warning',
    callout = { type = 'warning', label = 'Heads up', text = 'The trunk will be emptied.' },  -- or a list
    labels = { confirm = 'Scrap', cancel = 'Keep It' },
    cancel = true,    -- false hides the cancel button
})
-- result: 'confirm' | 'cancel'  (Esc = cancel)
UI:CloseAlert()
```

## Input dialog

```lua
local values = UI:InputDialog('Register Vehicle', {
    { type = 'input', label = 'Plate', icon = 'tag', placeholder = 'TSRP 001', required = true, min = 2, max = 8 },
    { type = 'input', label = 'PIN', password = true },
    { type = 'textarea', label = 'Notes', max = 200 },
    { type = 'number', label = 'Keys', min = 0, max = 5, step = 1, default = 1 },
    { type = 'select', label = 'Garage', options = { { value = 'a', label = 'Lot A' }, 'Barn' } },
    { type = 'multi-select', label = 'Extras', options = { 'Tracker', 'Roadside' }, default = { 'Tracker' } },
    { type = 'slider', label = 'Tint', min = 0, max = 100, step = 5, default = 35 },
    { type = 'toggle', label = 'Auto-renew', description = '...' },
    { type = 'checkbox', label = 'I agree', required = true },
    { type = 'color', label = 'Color', default = '#3ba7ff', colors = { '#ef4b5a', '#3ba7ff' } },
    { type = 'date', label = 'Date' },               -- 'YYYY-MM-DD'
    { type = 'date-range', label = 'Coverage' },     -- { from, to }
}, { icon = 'edit', description = 'Fill out the form', submitLabel = 'Save', cancelLabel = 'Back' })
-- values[1], values[2], ... in row order (empty fields are nil). nil if cancelled.
-- every row also takes: description, disabled, default
UI:CloseInput()
```

## Context menu

```lua
UI:RegisterContext({
    id = 'garage', title = 'Garage', description = 'Lot B', icon = 'garage',
    onExit = function() end,
    options = {
        { title = 'Vehicles', description = '3 stored', icon = 'car', menu = 'garage_vehicles' },
        { title = 'Fuel', icon = 'fuel', progress = 65, progressColor = '#22c38a' },
        { title = 'Info', icon = 'info', metadata = { { label = 'Plate', value = 'TSRP 001' }, { label = 'Engine', value = '92%', progress = 92 } }, image = 'https://...' },
        { title = 'Give Keys', icon = 'key', keybind = 'K', onSelect = function(args) end, args = { plate = 'TSRP 001' } },
        { title = 'Impound', icon = 'ban', disabled = true },
        { title = 'Lot B · 12 spaces free', icon = 'pin', readOnly = true },
        { title = 'Open', event = 'my:clientEvent', serverEvent = 'my:serverEvent', args = {}, close = false },
    },
})
UI:RegisterContext({ id = 'garage_vehicles', title = 'Vehicles', menu = 'garage', options = { ... } })  -- menu = back button target
UI:ShowContext('garage')
UI:HideContext(runOnExit)
UI:GetOpenContext()
```

`metadata` can also be a list of strings or `{ Plate = 'TSRP 001' }`. Options also take `iconColor`, `arrow` and `onBack` (on the menu).

## List menu

This menu is keyboard only, so the player can keep moving: ↑ ↓ moves, ← → changes a value, Enter selects, Backspace or Esc closes.

```lua
UI:RegisterList({
    id = 'customs', title = "Benny's", subtitle = 'Bison', icon = 'spray',
    position = 'top-left', canClose = true, disableInput = false,
    options = {
        { label = 'Respray', icon = 'spray', values = { 'Red', { label = 'Blue', description = 'Deep blue' } }, defaultIndex = 1 },
        { label = 'Neon', icon = 'light', checkbox = true, checked = false },
        { label = 'Engine', icon = 'engine', description = 'Level 2', progress = 50 },
        { label = 'Turbo', icon = 'turbo', disabled = true },
        { label = 'Apply', icon = 'check', args = {}, close = true },
    },
    onSelected   = function(selected, scrollIndex, args) end,
    onSideScroll = function(selected, scrollIndex, args) end,
    onCheck      = function(selected, checked, args) end,
    onClose      = function(keyPressed) end,
}, function(selected, scrollIndex, args, checked)
    -- Enter pressed on a row
end)
UI:ShowList('customs', startIndex)
UI:HideList(runOnClose)
UI:SetListOptions('customs', newOptions, index)
UI:GetOpenList()
```

The menu remembers its selected row, values and checkboxes between opens.

## Radial menu

Open it with **Z** (players can rebind it). Right-click or the center button goes back.

```lua
UI:AddRadialItem({ id = 'vehicle', label = 'Vehicle', icon = 'car', description = 'Doors, engine…', menu = 'vehicle_menu' })
UI:AddRadialItem({ id = 'phone', label = 'Phone', icon = 'phone', badge = 3, onSelect = function(item) end })
UI:AddRadialItem({ id = 'fuel', label = 'Fuel', icon = 'fuel', progress = 65, readOnly = true })
-- also: event / serverEvent + args, keepOpen = true, or a list of items
UI:RegisterRadial({ id = 'vehicle_menu', title = 'Vehicle', items = { ... } })
UI:RemoveRadialItem('phone')
UI:ClearRadialItems()
UI:DisableRadial(true)
UI:HideRadial()
UI:IsRadialOpen()
```

Adding an item with an id that already exists replaces it, so you can use that to update a badge or progress ring. A page with more than 6 items gets a "More" wedge.

## Text UI

```lua
UI:ShowTextUI('Talk')
UI:ShowTextUI({ key = 'E', title = 'Open Garage', description = 'Lot B', icon = 'garage', color = '#22c38a', position = 'right-center' })
UI:ShowTextUI({ title = 'Gas Station', options = { { key = 'E', label = 'Refuel', icon = 'fuel' }, { key = 'H', label = 'Car Wash' } } })
UI:HideTextUI()
UI:IsTextUIOpen()
-- positions: right-center | left-center | top-center | bottom-center
-- safe to call every frame (unchanged calls are skipped)
```

## Mini games

Each one returns `true` (passed) or `false`. Esc counts as a fail.

```lua
UI:SkillCheck('medium')                               -- easy | medium | hard
UI:SkillCheck({ 'easy', 'medium', 'hard' }, { 'E', 'Q' })  -- 3 rounds, random key each round
UI:SkillCheck({ zone = 30, speed = 1.5 })             -- custom zone (degrees) and speed

UI:SignalBreach('hard')
UI:SignalBreach({ nodes = 6, window = 15, speed = 80 }, { speedUp = 1.2, shrink = 0.8, failOnWrongKey = false, keys = { 'W', 'S' }, onNode = function(i) end })

UI:PatternLock('easy')
UI:PatternLock({ grid = 4, length = 7, showSpeed = 300, timeout = 5000, rounds = 2 })

UI:CancelMinigame()
UI:IsMinigameActive()
```

## Preview

Open `preview.html` in any browser to try every component without FiveM. It runs the real `html/` files with a fake Lua side. After changing anything in `html/`, rebuild it with:

```bash
bash tools/build-preview.sh
```
