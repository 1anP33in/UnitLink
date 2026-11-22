-- UnitLink CAD tables. Safe to run more than once.
-- (With Config.AutoInstallSql = true UnitLink runs this itself on start.)

CREATE TABLE IF NOT EXISTS `ul_call_notes` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `call_id` INT UNSIGNED NOT NULL,
    `author` VARCHAR(64) NOT NULL,
    `author_char` BIGINT UNSIGNED NULL,
    `body` VARCHAR(500) NOT NULL,
    `is_system` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_ul_call_notes_call` (`call_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ul_call_history` (
    `call_id` INT UNSIGNED NOT NULL,
    `nature` VARCHAR(40) NOT NULL,
    `priority` TINYINT UNSIGNED NOT NULL,
    `address` VARCHAR(120) NOT NULL,
    `caller` VARCHAR(64) NOT NULL,
    `units` VARCHAR(255) NOT NULL DEFAULT '',
    `pos_x` FLOAT NOT NULL DEFAULT 0,
    `pos_y` FLOAT NOT NULL DEFAULT 0,
    `close_reason` VARCHAR(24) NOT NULL,
    `closed_by` VARCHAR(16) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `closed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`call_id`),
    KEY `idx_ul_call_history_pos` (`pos_x`, `pos_y`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- citations, arrests, reports and warrants. Numbers are shown as C-/A-/R-/W- + id.
CREATE TABLE IF NOT EXISTS `ul_records` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `type` VARCHAR(12) NOT NULL,              -- citation | arrest | report | warrant
    `status` VARCHAR(16) NOT NULL,            -- filed | pending | active | served | denied
    `subject_char` BIGINT UNSIGNED NULL,
    `subject_name` VARCHAR(64) NULL,
    `officer_char` BIGINT UNSIGNED NOT NULL,
    `officer_label` VARCHAR(64) NOT NULL,
    `call_id` INT UNSIGNED NULL,
    `data` LONGTEXT NOT NULL,                 -- JSON: charges, location, narrative, ...
    `reviewed_by` VARCHAR(64) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_ul_records_subject` (`subject_char`, `type`),
    KEY `idx_ul_records_officer` (`officer_char`, `created_at`),
    KEY `idx_ul_records_type_status` (`type`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- BOLOs and other alerts (warrants are shown from ul_records)
CREATE TABLE IF NOT EXISTS `ul_alerts` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `type` VARCHAR(24) NOT NULL,
    `title` VARCHAR(120) NOT NULL,
    `body` VARCHAR(1000) NOT NULL,
    `subject_char` BIGINT UNSIGNED NULL,
    `subject_name` VARCHAR(64) NULL,
    `plate` VARCHAR(12) NULL,
    `created_by` VARCHAR(64) NOT NULL,
    `active` TINYINT(1) NOT NULL DEFAULT 1,
    `removed_by` VARCHAR(64) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_ul_alerts_active` (`active`, `created_at`),
    KEY `idx_ul_alerts_subject` (`subject_char`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- every name an officer ran (State Returns)
CREATE TABLE IF NOT EXISTS `ul_returns` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `officer_char` BIGINT UNSIGNED NOT NULL,
    `subject_char` BIGINT UNSIGNED NOT NULL,
    `subject_name` VARCHAR(64) NOT NULL,
    `call_id` INT UNSIGNED NULL,
    `hit` TINYINT(1) NOT NULL DEFAULT 0,
    `result` VARCHAR(64) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_ul_returns_officer` (`officer_char`, `created_at`),
    KEY `idx_ul_returns_call` (`call_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Standalone identity -------------------------------------------------------
-- Accounts (by license). Officers are identified by this id in standalone mode.
CREATE TABLE IF NOT EXISTS `ul_players` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(64) NOT NULL,
    `name` VARCHAR(64) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `last_seen` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_ul_players_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Civilian profiles made with /civ. The CAD searches these in standalone mode.
CREATE TABLE IF NOT EXISTS `ul_civilians` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `owner` VARCHAR(64) NOT NULL,             -- account identifier (license)
    `firstname` VARCHAR(32) NOT NULL,
    `lastname` VARCHAR(32) NOT NULL,
    `dateofbirth` VARCHAR(10) NOT NULL,       -- YYYY-MM-DD
    `gender` VARCHAR(16) NOT NULL,
    `nationality` VARCHAR(32) NOT NULL,
    `height` SMALLINT UNSIGNED NOT NULL,      -- cm
    `licenses` LONGTEXT NULL,                 -- JSON, same shape as Config.Licenses
    `deleted` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `last_used` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_ul_civilians_owner` (`owner`, `deleted`),
    KEY `idx_ul_civilians_name` (`lastname`, `firstname`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=1000;

-- SAFR: Fire & Rescue --------------------------------------------------------
CREATE TABLE IF NOT EXISTS `ul_fire_incidents` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `type` VARCHAR(16) NOT NULL,              -- MEDICAL | FIRE | RESCUE | MVC | HAZMAT
    `nature` VARCHAR(48) NOT NULL,
    `priority` TINYINT UNSIGNED NOT NULL DEFAULT 2,
    `street` VARCHAR(120) NULL,
    `pos_x` FLOAT NOT NULL DEFAULT 0,
    `pos_y` FLOAT NOT NULL DEFAULT 0,
    `pos_z` FLOAT NOT NULL DEFAULT 0,
    `caller` VARCHAR(64) NULL,
    `callback` VARCHAR(32) NULL,
    `message` VARCHAR(500) NULL,
    `patients` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `origin` VARCHAR(12) NOT NULL DEFAULT '911', -- 911 | cad
    `status` VARCHAR(12) NOT NULL DEFAULT 'active', -- active | closed
    `disposition` VARCHAR(48) NULL,
    `units` VARCHAR(255) NULL,               -- callsigns, saved when closed
    `closed_by` VARCHAR(64) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `closed_at` TIMESTAMP NULL,
    PRIMARY KEY (`id`),
    KEY `idx_ul_fire_status` (`status`, `id`),
    KEY `idx_ul_fire_pos` (`pos_x`, `pos_y`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=3001;

CREATE TABLE IF NOT EXISTS `ul_fire_notes` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `incident_id` INT UNSIGNED NOT NULL,
    `author` VARCHAR(64) NOT NULL,
    `body` VARCHAR(500) NOT NULL,
    `is_system` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_ul_fire_notes_inc` (`incident_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ul_fire_patients` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `incident_id` INT UNSIGNED NOT NULL,
    `subject_char` BIGINT UNSIGNED NULL,      -- civilian profile / character, NULL = unidentified
    `name` VARCHAR(64) NOT NULL,
    `injury` VARCHAR(200) NOT NULL,
    `severity` VARCHAR(16) NOT NULL,
    `treatment` VARCHAR(500) NULL,
    `destination` VARCHAR(48) NULL,
    `pt_condition` VARCHAR(16) NULL,
    `created_by` VARCHAR(64) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_ul_fire_pt_inc` (`incident_id`),
    KEY `idx_ul_fire_pt_subject` (`subject_char`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ul_fire_reports` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `form` VARCHAR(16) NOT NULL,
    `incident_id` INT UNSIGNED NULL,
    `subject_char` BIGINT UNSIGNED NULL,
    `subject_name` VARCHAR(64) NULL,
    `author_char` BIGINT UNSIGNED NOT NULL,
    `author_label` VARCHAR(64) NOT NULL,
    `data` LONGTEXT NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_ul_fire_rep_author` (`author_char`, `id`),
    KEY `idx_ul_fire_rep_subject` (`subject_char`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- everyone who has gone on duty with SAFR (roster + certifications)
CREATE TABLE IF NOT EXISTS `ul_fire_members` (
    `member_id` BIGINT UNSIGNED NOT NULL,     -- officer id (account in standalone mode)
    `name` VARCHAR(64) NOT NULL,
    `callsign` VARCHAR(12) NULL,
    `certs` VARCHAR(255) NULL,                -- JSON list
    `last_seen` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ul_fire_mutual_aid` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `from_station` VARCHAR(32) NOT NULL,
    `to_dept` VARCHAR(16) NOT NULL,
    `need` VARCHAR(300) NOT NULL,
    `status` VARCHAR(12) NOT NULL DEFAULT 'OPEN',
    `created_by` VARCHAR(64) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ul_fire_announcements` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `title` VARCHAR(80) NOT NULL,
    `body` VARCHAR(600) NULL,
    `created_by` VARCHAR(64) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Shared: activity log, employees (profiles), admin audit ---------------------
CREATE TABLE IF NOT EXISTS `ul_activity` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `member_id` BIGINT UNSIGNED NOT NULL,
    `name` VARCHAR(64) NOT NULL,
    `callsign` VARCHAR(12) NULL,
    `dept` VARCHAR(12) NULL,
    `action` VARCHAR(255) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_ul_activity_member` (`member_id`, `id`),
    KEY `idx_ul_activity_dept` (`dept`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ul_employees` (
    `member_id` BIGINT UNSIGNED NOT NULL,
    `name` VARCHAR(64) NOT NULL,
    `callsign` VARCHAR(12) NULL,
    `dept` VARCHAR(12) NULL,
    `kind` VARCHAR(8) NULL,                   -- leo | fire | dot
    `last_seen` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ul_audit` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `admin` VARCHAR(64) NOT NULL,
    `area` VARCHAR(32) NOT NULL,
    `change_text` VARCHAR(255) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- DOT: Work Orders ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `ul_dot_orders` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `category` VARCHAR(32) NOT NULL,
    `description` VARCHAR(500) NOT NULL,
    `priority` TINYINT UNSIGNED NOT NULL DEFAULT 3,
    `status` VARCHAR(16) NOT NULL DEFAULT 'OPEN',   -- OPEN | ASSIGNED | IN PROGRESS | ON HOLD | CLOSED
    `street` VARCHAR(120) NULL,
    `pos_x` FLOAT NOT NULL DEFAULT 0,
    `pos_y` FLOAT NOT NULL DEFAULT 0,
    `pos_z` FLOAT NOT NULL DEFAULT 0,
    `requester` VARCHAR(64) NULL,
    `requester_char` BIGINT UNSIGNED NULL,          -- civilian who asked (service requests)
    `origin` VARCHAR(12) NOT NULL DEFAULT 'cad',    -- cad | 311 | agency
    `equipment` VARCHAR(500) NULL,                  -- JSON list of required equipment
    `completion` TEXT NULL,
    `disposition` VARCHAR(48) NULL,
    `units` VARCHAR(255) NULL,
    `closed_by` VARCHAR(64) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `closed_at` TIMESTAMP NULL,
    PRIMARY KEY (`id`),
    KEY `idx_ul_dot_status` (`status`, `id`),
    KEY `idx_ul_dot_pos` (`pos_x`, `pos_y`),
    KEY `idx_ul_dot_requester` (`requester_char`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AUTO_INCREMENT=5001;

CREATE TABLE IF NOT EXISTS `ul_dot_notes` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `order_id` INT UNSIGNED NOT NULL,
    `author` VARCHAR(64) NOT NULL,
    `body` VARCHAR(500) NOT NULL,
    `is_system` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_ul_dot_notes_order` (`order_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ul_dot_reports` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `form` VARCHAR(16) NOT NULL,
    `order_id` INT UNSIGNED NULL,
    `author_char` BIGINT UNSIGNED NOT NULL,
    `author_label` VARCHAR(64) NOT NULL,
    `data` LONGTEXT NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_ul_dot_rep_author` (`author_char`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ul_dot_members` (
    `member_id` BIGINT UNSIGNED NOT NULL,
    `name` VARCHAR(64) NOT NULL,
    `callsign` VARCHAR(12) NULL,
    `certs` VARCHAR(255) NULL,
    `last_seen` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- vehicle state (the list of vehicles is Config.Dot.fleet)
CREATE TABLE IF NOT EXISTS `ul_dot_fleet` (
    `vehicle` VARCHAR(32) NOT NULL,
    `assigned` VARCHAR(64) NULL,
    `status` VARCHAR(16) NOT NULL DEFAULT 'AVAILABLE',  -- AVAILABLE | IN USE | OUT OF SERVICE
    `last_service` TIMESTAMP NULL,
    PRIMARY KEY (`vehicle`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ul_dot_checkouts` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `item` VARCHAR(16) NOT NULL,
    `qty` SMALLINT UNSIGNED NOT NULL,
    `who` VARCHAR(64) NOT NULL,
    `returned` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_ul_dot_co_item` (`item`, `returned`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ul_dot_maintenance` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `asset` VARCHAR(48) NOT NULL,
    `work` VARCHAR(255) NOT NULL,
    `status` VARCHAR(8) NOT NULL DEFAULT 'OPEN',     -- OPEN | DONE
    `logged_by` VARCHAR(64) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ul_dot_closures` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `road` VARCHAR(120) NOT NULL,
    `direction` VARCHAR(16) NULL,
    `reason` VARCHAR(16) NOT NULL,
    `until_text` VARCHAR(48) NULL,
    `detour` VARCHAR(120) NULL,
    `status` VARCHAR(12) NOT NULL DEFAULT 'REQUESTED', -- REQUESTED | ACTIVE | REOPENED
    `created_by` VARCHAR(64) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_ul_dot_closure_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ul_dot_announcements` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `title` VARCHAR(80) NOT NULL,
    `body` VARCHAR(600) NULL,
    `created_by` VARCHAR(64) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =================================================================
-- Shared tools: messages, BOLOs, incident links
-- =================================================================
CREATE TABLE IF NOT EXISTS `ul_messages` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `from_id` BIGINT UNSIGNED NOT NULL,
    `from_label` VARCHAR(64) NOT NULL,
    `from_dept` VARCHAR(12) NULL,
    `to_kind` VARCHAR(8) NOT NULL,            -- all | dept | member
    `to_value` VARCHAR(32) NULL,              -- dept short name or member id
    `to_label` VARCHAR(64) NULL,
    `body` VARCHAR(500) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_ul_messages_to` (`to_kind`, `to_value`, `id`),
    KEY `idx_ul_messages_from` (`from_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ul_bolos` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `type` VARCHAR(16) NOT NULL,
    `title` VARCHAR(120) NOT NULL,
    `body` VARCHAR(1000) NULL,
    `plate` VARCHAR(12) NULL,
    `dept` VARCHAR(12) NULL,
    `created_by` VARCHAR(64) NOT NULL,
    `active` TINYINT(1) NOT NULL DEFAULT 1,
    `cleared_by` VARCHAR(64) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_ul_bolos_active` (`active`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ul_links` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `a_type` VARCHAR(8) NOT NULL,             -- call | fire | dot
    `a_id` INT UNSIGNED NOT NULL,
    `b_type` VARCHAR(8) NOT NULL,
    `b_id` INT UNSIGNED NOT NULL,
    `created_by` VARCHAR(64) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_ul_links` (`a_type`, `a_id`, `b_type`, `b_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =================================================================
-- Civilian Portal: vehicles, businesses, applications, 911 tracking
-- =================================================================
CREATE TABLE IF NOT EXISTS `ul_civ_vehicles` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `civ_id` BIGINT UNSIGNED NOT NULL,
    `plate` VARCHAR(8) NOT NULL,
    `model` VARCHAR(40) NOT NULL,
    `color` VARCHAR(24) NOT NULL,
    `status` VARCHAR(12) NOT NULL DEFAULT 'VALID',  -- VALID | STOLEN | IMPOUNDED
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_ul_civ_vehicles_plate` (`plate`),
    KEY `idx_ul_civ_vehicles_civ` (`civ_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ul_civ_businesses` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `civ_id` BIGINT UNSIGNED NOT NULL,
    `name` VARCHAR(64) NOT NULL,
    `type` VARCHAR(32) NOT NULL,
    `status` VARCHAR(12) NOT NULL DEFAULT 'ACTIVE',  -- ACTIVE | CLOSED
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_ul_civ_businesses_civ` (`civ_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ul_civ_applications` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `civ_id` BIGINT UNSIGNED NOT NULL,
    `civ_name` VARCHAR(64) NOT NULL,
    `type` VARCHAR(16) NOT NULL,              -- drivers | firearm | pilot | vehicle | business
    `data` LONGTEXT NULL,
    `status` VARCHAR(10) NOT NULL DEFAULT 'PENDING', -- PENDING | APPROVED | DENIED
    `reason` VARCHAR(255) NULL,
    `reviewed_by` VARCHAR(64) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `reviewed_at` TIMESTAMP NULL,
    PRIMARY KEY (`id`),
    KEY `idx_ul_civ_apps_status` (`status`, `id`),
    KEY `idx_ul_civ_apps_civ` (`civ_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ul_civ_calls` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `civ_id` BIGINT UNSIGNED NOT NULL,
    `service` VARCHAR(8) NOT NULL,            -- POLICE | FIRE | EMS | DOT
    `ref_id` INT UNSIGNED NULL,               -- call / incident / work order number
    `message` VARCHAR(500) NOT NULL,
    `street` VARCHAR(120) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_ul_civ_calls_civ` (`civ_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =================================================================
-- Admin Dashboard: settings and law overrides (applied at start + live)
-- =================================================================
CREATE TABLE IF NOT EXISTS `ul_settings` (
    `skey` VARCHAR(48) NOT NULL,
    `svalue` LONGTEXT NULL,
    `updated_by` VARCHAR(64) NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`skey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
