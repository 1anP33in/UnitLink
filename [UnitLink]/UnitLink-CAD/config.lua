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
