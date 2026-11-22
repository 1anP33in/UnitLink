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
