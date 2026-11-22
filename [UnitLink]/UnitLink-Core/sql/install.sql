-- UnitLink Core 1.0.0 database schema (MySQL 5.7+ / MariaDB 10.3+, InnoDB, utf8mb4)
-- Every statement is idempotent (CREATE TABLE IF NOT EXISTS), so it is safe to run
-- again. UnitLink Core runs this file automatically when Config.Database.AutoInstall = true.
-- Do not put semicolons inside comments or string literals in this file: the
-- auto-installer splits statements on them.

CREATE TABLE IF NOT EXISTS `unitlink_players` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(64) NOT NULL,
    `name` VARCHAR(64) NULL DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `last_seen` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_unitlink_players_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `unitlink_characters` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(64) NOT NULL,
    `slot` TINYINT UNSIGNED NOT NULL,
    `firstname` VARCHAR(32) NOT NULL,
    `lastname` VARCHAR(32) NOT NULL,
    `dateofbirth` DATE NOT NULL,
    `gender` VARCHAR(16) NOT NULL,
    `nationality` VARCHAR(48) NOT NULL,
    `height` SMALLINT UNSIGNED NOT NULL,
    `metadata` LONGTEXT NOT NULL,
    `last_position` VARCHAR(255) NULL DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_unitlink_characters_slot` (`identifier`, `slot`),
    KEY `idx_unitlink_characters_name` (`firstname`, `lastname`),
    CONSTRAINT `fk_unitlink_characters_player` FOREIGN KEY (`identifier`)
        REFERENCES `unitlink_players` (`identifier`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1000 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `unitlink_character_appearance` (
    `character_id` BIGINT UNSIGNED NOT NULL,
    `model` VARCHAR(64) NOT NULL,
    `appearance` LONGTEXT NOT NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`character_id`),
    CONSTRAINT `fk_unitlink_appearance_character` FOREIGN KEY (`character_id`)
        REFERENCES `unitlink_characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `unitlink_groups` (
    `name` VARCHAR(50) NOT NULL,
    `label` VARCHAR(64) NOT NULL,
    `description` VARCHAR(255) NOT NULL DEFAULT '',
    `priority` SMALLINT NOT NULL DEFAULT 0,
    `metadata` LONGTEXT NULL DEFAULT NULL,
    `is_system` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `unitlink_group_inheritance` (
    `group_name` VARCHAR(50) NOT NULL,
    `inherits_name` VARCHAR(50) NOT NULL,
    PRIMARY KEY (`group_name`, `inherits_name`),
    KEY `idx_unitlink_inheritance_parent` (`inherits_name`),
    CONSTRAINT `fk_unitlink_inheritance_group` FOREIGN KEY (`group_name`)
        REFERENCES `unitlink_groups` (`name`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_unitlink_inheritance_parent` FOREIGN KEY (`inherits_name`)
        REFERENCES `unitlink_groups` (`name`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `unitlink_group_permissions` (
    `group_name` VARCHAR(50) NOT NULL,
    `permission` VARCHAR(128) NOT NULL,
    PRIMARY KEY (`group_name`, `permission`),
    CONSTRAINT `fk_unitlink_group_permissions_group` FOREIGN KEY (`group_name`)
        REFERENCES `unitlink_groups` (`name`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `unitlink_character_groups` (
    `character_id` BIGINT UNSIGNED NOT NULL,
    `group_name` VARCHAR(50) NOT NULL,
    `assigned_by` VARCHAR(64) NULL DEFAULT NULL,
    `assigned_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`character_id`, `group_name`),
    KEY `idx_unitlink_character_groups_group` (`group_name`),
    CONSTRAINT `fk_unitlink_character_groups_character` FOREIGN KEY (`character_id`)
        REFERENCES `unitlink_characters` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_unitlink_character_groups_group` FOREIGN KEY (`group_name`)
        REFERENCES `unitlink_groups` (`name`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `unitlink_character_permission_overrides` (
    `character_id` BIGINT UNSIGNED NOT NULL,
    `permission` VARCHAR(128) NOT NULL,
    `allow` TINYINT(1) NOT NULL,
    `set_by` VARCHAR(64) NULL DEFAULT NULL,
    `set_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`character_id`, `permission`),
    CONSTRAINT `fk_unitlink_overrides_character` FOREIGN KEY (`character_id`)
        REFERENCES `unitlink_characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `unitlink_audit_log` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `actor_identifier` VARCHAR(80) NULL DEFAULT NULL,
    `actor_character_id` BIGINT UNSIGNED NULL DEFAULT NULL,
    `target_character_id` BIGINT UNSIGNED NULL DEFAULT NULL,
    `action` VARCHAR(64) NOT NULL,
    `details` LONGTEXT NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_unitlink_audit_created` (`created_at`),
    KEY `idx_unitlink_audit_target` (`target_character_id`),
    KEY `idx_unitlink_audit_action` (`action`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
