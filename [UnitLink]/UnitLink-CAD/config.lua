Config = {}

---------------------------------------------------------------------
-- General
---------------------------------------------------------------------
Config.Name           = 'UnitLink'
Config.Command        = 'cad'   -- /cad opens the tablet
Config.Key            = 'F5'    -- default key (players can rebind: Settings > Key Bindings > FiveM)
Config.TabletAnimation = true   -- hold a tablet while the CAD is open
Config.AutoInstallSql = true    -- create the ul_ tables on start if they are missing
Config.RateLimitMs    = 250     -- minimum ms between CAD requests per player

-- Who can open the CAD: on-duty UnitLink-Police units whose department type
-- has this flag (config/departments.lua in UnitLink-Police). 'receives911' = LEO.
Config.AccessFlag = 'receives911'

---------------------------------------------------------------------
-- Identity: where people (name, DOB, licenses) come from
--   'auto'       : UnitLink-Core characters if UnitLink-Core is running,
--                  otherwise UnitLink's own civilian profiles
--   'standalone' : always UnitLink civilian profiles (no framework needed)
--   'core'       : always UnitLink-Core characters
-- In standalone mode players make up to `maxProfiles` civilian profiles
-- with /civ and pick which one they are playing. Officers are identified
-- by their account (ACE permissions are account-level too).
---------------------------------------------------------------------
Config.Identity = 'auto'
Config.CoreResource = 'UnitLink-Core'
Config.Civ = {
    command = 'civ',      -- /civ opens the Civilian ID window
    maxProfiles = 5,
    minAge = 16, maxAge = 100,
    nationalities = { 'American', 'Canadian', 'Mexican', 'British', 'Irish', 'German', 'French', 'Italian', 'Spanish', 'Brazilian', 'Colombian', 'Jamaican', 'Nigerian', 'Indian', 'Chinese', 'Japanese', 'Korean', 'Filipino', 'Russian', 'Australian', 'Other' },

    -- Civilian Portal (/civ): 911, records, vehicles, applications, service requests
    maxVehicles = 6,
    maxBusinesses = 3,
    callCooldown = 60,              -- seconds between portal 911 / service requests per player
    -- What needs an admin to approve it in the Admin Dashboard (false = instant)
    approval = { drivers = true, firearm = true, pilot = true, vehicle = false, business = true },
    vehicleColors = { 'BLACK', 'WHITE', 'SILVER', 'GREY', 'RED', 'BLUE', 'GREEN', 'YELLOW', 'ORANGE', 'BROWN', 'PURPLE', 'GOLD' },
    businessTypes = { 'RETAIL', 'RESTAURANT', 'AUTOMOTIVE', 'SECURITY', 'TRANSPORT', 'ENTERTAINMENT', 'CONSTRUCTION', 'OTHER' },
    -- DOT service requests civilians can send (each becomes a DOT work order)
    serviceRequests = {
        { label = 'Pothole / road damage',   category = 'ROAD MAINTENANCE' },
        { label = 'Broken traffic signal',   category = 'TRAFFIC MANAGEMENT' },
        { label = 'Debris on the road',      category = 'DEBRIS REMOVAL' },
        { label = 'Abandoned vehicle',       category = 'VEHICLE RECOVERY' },
        { label = 'Roadside assistance',     category = 'ROADSIDE ASSISTANCE' },
    },
}

---------------------------------------------------------------------
-- Shared tools (every department tablet has a Tools tile):
-- global search, messages, shared BOLOs, incident links, activity
---------------------------------------------------------------------
Config.Tools = {
    enabled = true,
    boloTypes = { 'PERSON', 'VEHICLE', 'PROPERTY', 'HAZARD', 'OTHER' },
    messageDays = 3,                -- inbox shows messages from the last N days
}

---------------------------------------------------------------------
-- Admin Dashboard (/cadadmin). Who can open it is ACE only:
--   add_ace group.admin unitlink.admin allow
---------------------------------------------------------------------
Config.Admin = {
    command = 'cadadmin',
    ace = 'unitlink.admin',
}

---------------------------------------------------------------------
-- Fines: shown on citations and state returns only. NO money is ever
-- taken from anyone; a fine is a record that expires after `expireDays`.
---------------------------------------------------------------------
Config.Fines = {
    enabled = true,
    expireDays = 7,       -- a fine shows as OUTSTANDING until this many days after it was written
    symbol = '$',
}

---------------------------------------------------------------------
-- SAFR: Fire & Rescue CAD
-- On-duty units whose UnitLink-Police department type has `accessFlag`
-- get the SAFR tablet when they press /cad (F5). Supervisors are the
-- ACE permission unitlink.safr.supervisor.
---------------------------------------------------------------------
Config.Fire = {
    enabled = true,
    accessFlag = 'fireCad',
    firstIncident = 3001,           -- incident numbers start here
    -- civilians report fires and medical emergencies with these
    commands = { fire = '911fire', medical = '911ems' },
    callCooldown = 60,              -- seconds between civilian fire / EMS calls per player
    -- unit statuses (SAFR keeps its own; UnitLink-Police statuses are police-only)
    statuses = {
        { code = 'AVAIL', label = 'Available',      color = 'avail' },
        { code = 'ENRT',  label = 'En Route',       color = 'enrt', onCall = true },
        { code = 'ONSCN', label = 'On Scene',       color = 'arrvd', onCall = true },
        { code = 'TRANS', label = 'Transporting',   color = 'trans', onCall = true },
        { code = 'ATHSP', label = 'At Hospital',    color = 'disp', onCall = true },
        { code = 'BUSY',  label = 'Busy',           color = 'busy' },
        { code = 'OOS',   label = 'Out of Service', color = 'offdt' },
    },
    types = {
        MEDICAL = { 'CARDIAC ARREST', 'DIFFICULTY BREATHING', 'CHEST PAIN', 'FALL', 'OVERDOSE', 'UNCONSCIOUS', 'TRAUMA', 'MEDICAL EMERGENCY' },
        FIRE    = { 'STRUCTURE FIRE', 'VEHICLE FIRE', 'BRUSH FIRE', 'ALARM ACTIVATION', 'SMOKE INVESTIGATION', 'REPORTED FIRE' },
        RESCUE  = { 'WATER RESCUE', 'HIGH ANGLE RESCUE', 'ELEVATOR RESCUE', 'CONFINED SPACE' },
        MVC     = { 'MVC W/ INJURIES', 'MVC W/ ENTRAPMENT', 'MVC ROLLOVER', 'MVC VS PEDESTRIAN' },
        HAZMAT  = { 'FUEL SPILL', 'GAS LEAK', 'UNKNOWN SUBSTANCE' },
    },
    typeOrder = { 'MEDICAL', 'FIRE', 'RESCUE', 'MVC', 'HAZMAT' },
    dispositions = { 'TRANSPORTED', 'TREATED / RELEASED', 'REFUSAL SIGNED', 'FIRE OUT', 'NO PATIENT FOUND', 'CANCELLED EN ROUTE', 'HANDED TO LEO', 'FALSE ALARM' },
    hospitals = { 'PILLBOX HILL MEDICAL', 'MOUNT ZONAH MEDICAL', 'SANDY SHORES MEDICAL', 'PALETO BAY MEDICAL' },
    severities = { 'MINOR', 'MODERATE', 'SERIOUS', 'CRITICAL', 'DECEASED' },
    conditions = { 'STABLE', 'IMPROVING', 'UNCHANGED', 'DETERIORATING', 'CRITICAL' },
    stations = {
        { id = 1, name = 'STATION 1', address = 'DAVIS AVE, DAVIS' },
        { id = 7, name = 'STATION 7', address = 'PANORAMA DR, SANDY SHORES' },
        { id = 9, name = 'STATION 9', address = 'PALETO BLVD, PALETO BAY' },
    },
    -- apparatus units can ride on (picked on the board)
    apparatus = {
        { id = 'E-12', type = 'ENGINE', station = 'STATION 1' }, { id = 'M-7', type = 'MEDIC', station = 'STATION 1' },
        { id = 'L-3', type = 'LADDER', station = 'STATION 1' },  { id = 'E-19', type = 'ENGINE', station = 'STATION 7' },
        { id = 'M-4', type = 'MEDIC', station = 'STATION 7' },   { id = 'BR-2', type = 'BRUSH', station = 'STATION 7' },
        { id = 'E-21', type = 'ENGINE', station = 'STATION 9' }, { id = 'R-9', type = 'RESCUE', station = 'STATION 9' },
    },
    mutualAidTo = { 'SASP', 'BCSO', 'LSP', 'DOT' },
    nearbyMeters = 60,              -- Address History radius
    maydayAll = true,               -- MAYDAY alerts every on-duty unit (false = SAFR only)
    minNarrative = 20,
    -- report forms. Field types: text, area, narr (>= minNarrative), number,
    -- person (civilian), incident, unit, or a list of options.
    forms = {
        { key = 'pcr', label = 'Patient Care Report', fields = {
            { 'person', 'Patient', 'person', true }, { 'incident', 'Incident', 'incident' }, { 'complaint', 'Chief Complaint', 'text' },
            { 'severity', 'Injury Severity', 'severities' }, { 'vitals', 'Vitals (BP / HR / RR / SpO2)', 'text' }, { 'condition', 'Patient Condition', 'conditions' },
            { 'treatment', 'Treatment Provided', 'area' }, { 'destination', 'Transport Destination', 'hospitals+' }, { 'narrative', 'Narrative', 'narr' } } },
        { key = 'fireinc', label = 'Fire Incident Report', fields = {
            { 'incident', 'Incident', 'incident' }, { 'ftype', 'Fire Type', { 'STRUCTURE', 'VEHICLE', 'BRUSH / WILDLAND', 'ALARM - NO FIRE', 'OTHER' } },
            { 'property', 'Property Use', 'text' }, { 'origin', 'Area of Origin', 'text' },
            { 'cause', 'Cause', { 'UNDETERMINED', 'ACCIDENTAL', 'INCENDIARY', 'NATURAL', 'UNDER INVESTIGATION' } },
            { 'damage', 'Estimated Damage', { 'NONE', 'MINOR', 'MODERATE', 'MAJOR', 'TOTAL LOSS' } }, { 'apparatus', 'Apparatus on Scene', 'text' }, { 'narrative', 'Narrative', 'narr' } } },
        { key = 'rescue', label = 'Rescue Report', fields = {
            { 'incident', 'Incident', 'incident' }, { 'rtype', 'Rescue Type', { 'WATER', 'HIGH ANGLE', 'CONFINED SPACE', 'ELEVATOR', 'VEHICLE EXTRICATION', 'SEARCH' } },
            { 'victims', 'Victims', 'number' }, { 'equipment', 'Equipment Used', 'text' },
            { 'outcome', 'Outcome', { 'RESCUED - NO INJURY', 'RESCUED - INJURED', 'RECOVERY', 'NOT LOCATED' } }, { 'narrative', 'Narrative', 'narr' } } },
        { key = 'mvc', label = 'Vehicle Collision Report', fields = {
            { 'incident', 'Incident', 'incident' }, { 'vehicles', 'Vehicles Involved', 'number' }, { 'extrication', 'Extrication Required', { 'NO', 'YES' } },
            { 'patients', 'Patients', 'number' }, { 'hazards', 'Hazards', { 'NONE', 'FUEL SPILL', 'FIRE', 'POWER LINES', 'AIRBAG UNDEPLOYED' } },
            { 'person', 'Driver (optional)', 'person' }, { 'narrative', 'Narrative', 'narr' } } },
        { key = 'hazmat', label = 'Hazardous Material Report', fields = {
            { 'incident', 'Incident', 'incident' }, { 'substance', 'Substance', 'text' }, { 'un', 'UN / NA Number', 'text' }, { 'qty', 'Estimated Quantity', 'text' },
            { 'evac', 'Evacuation Radius', { 'NONE', '100 FT', '330 FT', '1000 FT', 'SHELTER IN PLACE' } },
            { 'decon', 'Decon Performed', { 'NO', 'YES - GROSS', 'YES - TECHNICAL' } }, { 'narrative', 'Narrative', 'narr' } } },
        { key = 'transport', label = 'Hospital Transport Report', fields = {
            { 'person', 'Patient', 'person', true }, { 'incident', 'Incident', 'incident' }, { 'from', 'Picked Up From', 'text' },
            { 'destination', 'Destination', 'hospitals' }, { 'tunit', 'Transport Unit', 'unit' },
            { 'tpriority', 'Transport Priority', { 'EMERGENT (LIGHTS & SIREN)', 'NON-EMERGENT' } }, { 'condition', 'Condition on Arrival', 'conditions' }, { 'narrative', 'Narrative', 'narr' } } },
    },
}

---------------------------------------------------------------------
-- Unit statuses: CAD code -> UnitLink-Police status
---------------------------------------------------------------------
Config.Statuses = {
    { code = 'AVAIL', status = 'available',   label = 'Available' },
    { code = 'ENRT',  status = 'responding',  label = 'En Route' },  -- only while on a call
    { code = 'ARRVD', status = 'onscene',     label = 'On Scene' },  -- only while on a call
    { code = 'BUSY',  status = 'busy',        label = 'Busy' },
    { code = 'UNAV',  status = 'unavailable', label = 'Unavailable' },
}

---------------------------------------------------------------------
-- DOT: Work Orders
-- On-duty units whose UnitLink-Police department type has `accessFlag`
-- get the DOT tablet with /cad (F5). Supervisors: ACE unitlink.dot.supervisor.
---------------------------------------------------------------------
Config.Dot = {
    enabled = true,
    accessFlag = 'dotCad',
    firstOrder = 5001,              -- work order numbers start here (shown as WO-5001)
    statuses = {
        { code = 'AVAIL', label = 'Available',   color = 'avail' },
        { code = 'ENRT',  label = 'En Route',    color = 'enrt', onCall = true },
        { code = 'ONSCN', label = 'On Scene',    color = 'arrvd', onCall = true },
        { code = 'WORK',  label = 'Working',     color = 'trans', onCall = true },
        { code = 'BUSY',  label = 'Busy',        color = 'busy' },
        { code = 'UNAV',  label = 'Unavailable', color = 'offdt' },
    },
    categories = { 'ROAD MAINTENANCE', 'ROADSIDE ASSISTANCE', 'VEHICLE RECOVERY', 'ROAD CLOSURES', 'TRAFFIC MANAGEMENT',
        'ROAD INSPECTIONS', 'CONSTRUCTION ZONES', 'DEBRIS REMOVAL', 'DAMAGED ROAD SIGNS', 'HIGHWAY HAZARDS' },
    -- board filter chips: label -> categories
    filters = {
        { label = 'Roadside', categories = { 'ROADSIDE ASSISTANCE' } },
        { label = 'Traffic control', categories = { 'TRAFFIC MANAGEMENT' } },
        { label = 'Recovery', categories = { 'VEHICLE RECOVERY' } },
        { label = 'Maintenance', categories = { 'ROAD MAINTENANCE', 'DEBRIS REMOVAL', 'DAMAGED ROAD SIGNS', 'HIGHWAY HAZARDS', 'ROAD INSPECTIONS' } },
        { label = 'Construction', categories = { 'CONSTRUCTION ZONES', 'ROAD CLOSURES' } },
    },
    orderStatuses = { 'OPEN', 'ASSIGNED', 'IN PROGRESS', 'ON HOLD' },
    dispositions = { 'COMPLETE', 'COMPLETE · ROADWAY CLEAR', 'REFERRED TO CONTRACTOR', 'DUPLICATE', 'CANCELLED BY REQUESTER' },
    -- vehicles employees can be assigned to
    fleet = {
        { id = 'FLATBED TOW 1', type = 'TOW TRUCK' }, { id = 'WRECKER 3', type = 'TOW TRUCK' },
        { id = 'SERVICE TRUCK 4', type = 'SERVICE TRUCK' }, { id = 'ARROW BOARD TRUCK 2', type = 'SERVICE TRUCK' },
        { id = 'ROADSIDE VAN 1', type = 'SERVICE TRUCK' }, { id = 'DUMP TRUCK 6', type = 'ROAD MAINTENANCE' },
        { id = 'PAVER 1', type = 'ROAD MAINTENANCE' },
    },
    -- equipment inventory (total quantity on hand)
    equipment = {
        { id = 'cones', item = 'Traffic cones', qty = 200 }, { id = 'arrow', item = 'Arrow board (trailer)', qty = 4 },
        { id = 'closed', item = 'Road closed sign', qty = 20 }, { id = 'absorb', item = 'Absorbent (bag)', qty = 30 },
        { id = 'light', item = 'Portable light tower', qty = 3 }, { id = 'stop', item = 'Stop sign (R1-1)', qty = 12 },
    },
    closureReasons = { 'CONSTRUCTION', 'COLLISION', 'EVENT', 'HAZARD', 'EMERGENCY' },
    directions = { 'BOTH', 'NORTHBOUND', 'SOUTHBOUND', 'EASTBOUND', 'WESTBOUND' },
    nearbyMeters = 60,
    minNarrative = 20,              -- reports and completion notes
    requestCooldown = 120,          -- seconds between civilian service requests per player
    forms = {
        { key = 'hazard', label = 'Road Hazard Report', fields = {
            { 'location', 'Location', 'text', true }, { 'htype', 'Hazard Type', { 'POTHOLE', 'DEBRIS', 'FLOODING', 'ROCKSLIDE', 'SIGNAL OUT', 'SPILL', 'OTHER' } },
            { 'lanes', 'Lanes Affected', 'text' }, { 'severity', 'Severity', { 'LOW', 'MODERATE', 'HIGH - MAJOR HIGHWAY HAZARD' } }, { 'narrative', 'Narrative', 'narr' } } },
        { key = 'recovery', label = 'Vehicle Recovery Report', fields = {
            { 'incident', 'Work Order', 'incident' }, { 'plate', 'Plate', 'text' }, { 'vehicle', 'Vehicle', 'text' },
            { 'reason', 'Reason', { 'COLLISION', 'DISABLED', 'ABANDONED', 'POLICE REQUEST', 'ILLEGALLY PARKED' } },
            { 'towto', 'Towed To', { 'STATE IMPOUND', 'DOT YARD', "OWNER'S ADDRESS", 'REPAIR SHOP' } }, { 'narrative', 'Narrative', 'narr' } } },
        { key = 'closure', label = 'Road Closure Request', fields = {
            { 'road', 'Road / Segment', 'text', true }, { 'direction', 'Direction', 'directions' }, { 'lanes', 'Lanes', 'text' },
            { 'until', 'Until', 'text' }, { 'reason', 'Reason', 'closureReasons', true }, { 'detour', 'Detour', 'text' }, { 'narrative', 'Narrative', 'narr' } } },
        { key = 'inspection', label = 'Road Inspection Report', fields = {
            { 'road', 'Road / Segment', 'text', true }, { 'rating', 'Condition Rating', { '5 - EXCELLENT', '4 - GOOD', '3 - FAIR', '2 - POOR', '1 - FAILED' } },
            { 'defects', 'Defects Found', 'text' }, { 'action', 'Recommended Action', { 'NONE', 'MONITOR', 'PATCH', 'RESURFACE', 'CLOSE ROAD' } }, { 'narrative', 'Narrative', 'narr' } } },
        { key = 'maintdone', label = 'Maintenance Completion Report', fields = {
            { 'incident', 'Work Order', 'incident' }, { 'work', 'Work Performed', 'text' }, { 'materials', 'Materials Used', 'text' },
            { 'hours', 'Labor Hours', 'number' }, { 'narrative', 'Narrative', 'narr' } } },
        { key = 'damage', label = 'Equipment Damage Report', fields = {
            { 'asset', 'Vehicle / Equipment', 'assets', true }, { 'desc', 'Damage Description', 'text' },
            { 'cause', 'Cause', { 'WEAR', 'COLLISION', 'OPERATOR ERROR', 'VANDALISM', 'UNKNOWN' } },
            { 'serviceable', 'Still Serviceable', { 'YES', 'NO - TAKE OUT OF SERVICE' } }, { 'narrative', 'Narrative', 'narr' } } },
    },
}

---------------------------------------------------------------------
-- Call natures (dropdown on the call record / new call)
---------------------------------------------------------------------
Config.Natures = {
    '911 CALL', '10-10 FIGHT', '10-16 DOMESTIC', '10-31 ROBBERY', '10-32 PERSON W/ GUN',
    '10-38 TRAFFIC STOP', '10-50 MVA', '10-50 MVA W/ INJ', '10-55 DUI', '10-66 SUSP PERSON',
    '10-70 FIRE', '10-80 PURSUIT', '10-90 ALARM', 'WELFARE CHECK', 'NOISE COMPLAINT', 'SELF-INITIATED',
}

---------------------------------------------------------------------
-- Licenses: { drivers = { status = 'valid', points = 0 }, firearm = {...}, pilot = {...} }
-- Stored on the civilian profile (standalone) or in UnitLink-Core character
-- metadata under `metadataKey`. People without any use `defaults`.
-- Citations add driver points; reaching `suspendAt` suspends a valid license.
---------------------------------------------------------------------
Config.Licenses = {
    metadataKey = 'licenses',
    defaults = { drivers = 'valid', firearm = 'none', pilot = 'none' },
    suspendAt = 12,
}

---------------------------------------------------------------------
-- Records
---------------------------------------------------------------------
Config.ReportTypes = { 'GENERAL INCIDENT', 'TRAFFIC COLLISION', 'USE OF FORCE', 'FIELD INTERVIEW', 'PROPERTY / EVIDENCE' }
Config.Bookings    = { 'BOLINGBROKE PENITENTIARY', 'MISSION ROW PD', 'SANDY SHORES SHERIFF', 'PALETO BAY SHERIFF' }
Config.WarrantTypes = { 'ARREST', 'SEARCH', 'BENCH' }
Config.AlertTypes   = { 'BOLO', 'CAUTION', 'ARMED & DANGEROUS', 'OFFICER SAFETY', 'MISSING PERSON', 'STOLEN VEHICLE' }

-- Warrants need approval by a supervisor (unitlink.<dept>.supervisor or
-- unitlink.police.supervisor). false = warrants go active immediately.
Config.WarrantsNeedApproval = true

-- Signal 100 (emergency radio traffic only). Supervisors only?
Config.Signal100SupervisorOnly = true

---------------------------------------------------------------------
-- San Andreas Penal Code. class: F felony, M misdemeanor, I infraction.
-- points = driver license points added by a citation.
-- fine   = amount shown on the citation (record only, never charged; see Config.Fines).
--          Felonies are arrest-only, so they have no fine.
-- aliases help search ("dui" finds Driving Under the Influence).
---------------------------------------------------------------------
Config.Laws = {
    { code = '1-01', offense = 'Assault',                              class = 'M', points = 0, fine = 500 },
    { code = '1-02', offense = 'Aggravated Assault',                   class = 'F', points = 0, fine = 0, note = 'Weapon or serious injury' },
    { code = '1-05', offense = 'Assault on a Peace Officer',           class = 'F', points = 0, fine = 0 },
    { code = '1-08', offense = 'Armed Robbery',                        class = 'F', points = 0, fine = 0 },
    { code = '1-09', offense = 'Robbery',                              class = 'F', points = 0, fine = 0 },
    { code = '1-10', offense = 'Burglary',                             class = 'F', points = 0, fine = 0 },
    { code = '1-11', offense = 'Petty Theft',                          class = 'M', points = 0, fine = 400 },
    { code = '1-12', offense = 'Grand Theft Auto',                     class = 'F', points = 0, fine = 0, aliases = { 'gta', 'stolen vehicle' } },
    { code = '1-14', offense = 'Evading a Peace Officer',              class = 'F', points = 0, fine = 0, note = 'Vehicle pursuit', aliases = { 'pursuit', 'fleeing' } },
    { code = '1-20', offense = 'Resisting Arrest',                     class = 'M', points = 0, fine = 750 },
    { code = '1-22', offense = 'Obstruction of Justice',               class = 'M', points = 0, fine = 750 },
    { code = '1-25', offense = 'Brandishing a Firearm',                class = 'M', points = 0, fine = 1000 },
    { code = '1-26', offense = 'Possession of an Unlicensed Firearm',  class = 'F', points = 0, fine = 0, aliases = { 'ccw', 'gun' } },
    { code = '1-30', offense = 'Possession of a Controlled Substance', class = 'M', points = 0, fine = 1000, aliases = { 'drugs' } },
    { code = '1-31', offense = 'Possession with Intent to Distribute', class = 'F', points = 0, fine = 0, aliases = { 'drugs', 'pwid' } },
    { code = '1-40', offense = 'Murder',                               class = 'F', points = 0, fine = 0 },
    { code = '1-41', offense = 'Attempted Murder',                     class = 'F', points = 0, fine = 0 },
    { code = '1-45', offense = 'Kidnapping',                           class = 'F', points = 0, fine = 0 },
    { code = '2-01', offense = 'Speeding (25+ over)',                  class = 'M', points = 3, fine = 750 },
    { code = '2-02', offense = 'Speeding (1-24 over)',                 class = 'I', points = 2, fine = 250 },
    { code = '2-03', offense = 'Running a Red Light',                  class = 'I', points = 2, fine = 200 },
    { code = '2-04', offense = 'Failure to Stop',                      class = 'I', points = 1, fine = 150, aliases = { 'stop sign' } },
    { code = '2-05', offense = 'Illegal U-Turn',                       class = 'I', points = 1, fine = 100 },
    { code = '2-06', offense = 'No Seatbelt',                          class = 'I', points = 1, fine = 100 },
    { code = '2-07', offense = 'Reckless Driving',                     class = 'M', points = 4, fine = 1000 },
    { code = '2-08', offense = 'Driving Under the Influence',          class = 'M', points = 6, fine = 1500, note = 'Suspends license at 12 points', aliases = { 'dui', 'dwi', 'drunk' } },
    { code = '2-09', offense = 'Driving Without a License',            class = 'M', points = 3, fine = 500, aliases = { 'dwl', 'no license' } },
    { code = '2-10', offense = 'Hit and Run',                          class = 'F', points = 6, fine = 0 },
    { code = '2-11', offense = 'Driving on a Suspended License',       class = 'M', points = 4, fine = 1000, aliases = { 'dws' } },
    { code = '2-12', offense = 'Unroadworthy Vehicle',                 class = 'I', points = 1, fine = 150 },
    { code = '3-01', offense = 'Disturbing the Peace',                 class = 'I', points = 0, fine = 200 },
    { code = '3-02', offense = 'Public Intoxication',                  class = 'I', points = 0, fine = 150 },
    { code = '3-05', offense = 'Trespassing',                          class = 'M', points = 0, fine = 400 },
    { code = '3-08', offense = 'Vandalism',                            class = 'M', points = 0, fine = 500 },
    { code = '4-01', offense = 'Failure to Appear',                    class = 'M', points = 0, fine = 500, aliases = { 'fta' } },
}
