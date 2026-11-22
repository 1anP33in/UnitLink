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
-- Licenses live in UnitLink-Core character metadata under this key:
--   licenses = { drivers = { status = 'valid', points = 0 }, firearm = {...}, pilot = {...} }
-- Characters without the key use `defaults`. Citations add driver points;
-- reaching `suspendAt` points suspends a valid driver's license.
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
-- aliases help search ("dui" finds Driving Under the Influence).
---------------------------------------------------------------------
Config.Laws = {
    { code = '1-01', offense = 'Assault',                              class = 'M', points = 0 },
    { code = '1-02', offense = 'Aggravated Assault',                   class = 'F', points = 0, note = 'Weapon or serious injury' },
    { code = '1-05', offense = 'Assault on a Peace Officer',           class = 'F', points = 0 },
    { code = '1-08', offense = 'Armed Robbery',                        class = 'F', points = 0 },
    { code = '1-09', offense = 'Robbery',                              class = 'F', points = 0 },
    { code = '1-10', offense = 'Burglary',                             class = 'F', points = 0 },
    { code = '1-11', offense = 'Petty Theft',                          class = 'M', points = 0 },
    { code = '1-12', offense = 'Grand Theft Auto',                     class = 'F', points = 0, aliases = { 'gta', 'stolen vehicle' } },
    { code = '1-14', offense = 'Evading a Peace Officer',              class = 'F', points = 0, note = 'Vehicle pursuit', aliases = { 'pursuit', 'fleeing' } },
    { code = '1-20', offense = 'Resisting Arrest',                     class = 'M', points = 0 },
    { code = '1-22', offense = 'Obstruction of Justice',               class = 'M', points = 0 },
    { code = '1-25', offense = 'Brandishing a Firearm',                class = 'M', points = 0 },
    { code = '1-26', offense = 'Possession of an Unlicensed Firearm',  class = 'F', points = 0, aliases = { 'ccw', 'gun' } },
    { code = '1-30', offense = 'Possession of a Controlled Substance', class = 'M', points = 0, aliases = { 'drugs' } },
    { code = '1-31', offense = 'Possession with Intent to Distribute', class = 'F', points = 0, aliases = { 'drugs', 'pwid' } },
    { code = '1-40', offense = 'Murder',                               class = 'F', points = 0 },
    { code = '1-41', offense = 'Attempted Murder',                     class = 'F', points = 0 },
    { code = '1-45', offense = 'Kidnapping',                           class = 'F', points = 0 },
    { code = '2-01', offense = 'Speeding (25+ over)',                  class = 'M', points = 3 },
    { code = '2-02', offense = 'Speeding (1-24 over)',                 class = 'I', points = 2 },
    { code = '2-03', offense = 'Running a Red Light',                  class = 'I', points = 2 },
    { code = '2-04', offense = 'Failure to Stop',                      class = 'I', points = 1, aliases = { 'stop sign' } },
    { code = '2-05', offense = 'Illegal U-Turn',                       class = 'I', points = 1 },
    { code = '2-06', offense = 'No Seatbelt',                          class = 'I', points = 1 },
    { code = '2-07', offense = 'Reckless Driving',                     class = 'M', points = 4 },
    { code = '2-08', offense = 'Driving Under the Influence',          class = 'M', points = 6, note = 'Suspends license at 12 points', aliases = { 'dui', 'dwi', 'drunk' } },
    { code = '2-09', offense = 'Driving Without a License',            class = 'M', points = 3, aliases = { 'dwl', 'no license' } },
    { code = '2-10', offense = 'Hit and Run',                          class = 'F', points = 6 },
    { code = '2-11', offense = 'Driving on a Suspended License',       class = 'M', points = 4, aliases = { 'dws' } },
    { code = '2-12', offense = 'Unroadworthy Vehicle',                 class = 'I', points = 1 },
    { code = '3-01', offense = 'Disturbing the Peace',                 class = 'I', points = 0 },
    { code = '3-02', offense = 'Public Intoxication',                  class = 'I', points = 0 },
    { code = '3-05', offense = 'Trespassing',                          class = 'M', points = 0 },
    { code = '3-08', offense = 'Vandalism',                            class = 'M', points = 0 },
    { code = '4-01', offense = 'Failure to Appear',                    class = 'M', points = 0, aliases = { 'fta' } },
}
