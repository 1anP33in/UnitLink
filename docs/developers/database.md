# Database Tables

UnitLink creates these tables through oxmysql on start (`Config.AutoInstallSql`), or you can run `UnitLink-CAD/sql/install.sql` yourself. Every query is parameterized.

| Table | Holds | Key columns |
|---|---|---|
| `ul_call_notes` | Notes on calls | `call_id`, `author_char`, `created_at` |
| `ul_call_history` | Closed calls (History, Address History) | `call_id`, `priority`, `pos_x`, `pos_y`, `created_at`, `closed_at` |
| `ul_records` | Citations, arrests, reports, warrants | `subject_char`, `officer_char`, `call_id`, `data` (JSON: charges, location, narrative…) |
| `ul_alerts` | BOLOs and alerts | `subject_char`, `created_at` |
| `ul_players` | Accounts (by license). Officers are identified by this id in standalone mode | `identifier`, `name`, `last_seen` |
| `ul_civilians` | Civilian profiles made with `/civ` (standalone people) | `owner`, `firstname`, `lastname`, `dateofbirth`, `gender`, `nationality`, `height`, `licenses` (JSON), `deleted` |
| `ul_returns` | State returns that were run (Returns log) | `officer_char`, `subject_char`, `call_id`, `created_at` |
| `ul_fire_*` | SAFR incidents, notes, patients, reports, members, mutual aid, announcements | `ul_fire_incidents.id` starts at 3001 |
| `ul_dot_*` | DOT work orders, notes, reports, members, fleet, checkouts, maintenance, closures, announcements | `ul_dot_orders.id` starts at 5001 |
| `ul_activity` | Every department's activity log | `member_id`, `dept`, `action` |
| `ul_employees` | Everyone who has opened a tablet | `member_id`, `dept`, `kind` |
| `ul_audit` | Admin Dashboard changes | `admin`, `area`, `change_text` |
| `ul_messages` | Shared Tools messages | `to_kind` (all / dept / member), `to_value` |
| `ul_bolos` | Shared BOLOs | `type`, `plate`, `dept`, `active` |
| `ul_links` | Incident links | `a_type`, `a_id`, `b_type`, `b_id` |
| `ul_civ_vehicles` | Registered vehicles | `civ_id`, `plate` (unique), `status` |
| `ul_civ_businesses` | Businesses | `civ_id`, `name`, `status` |
| `ul_civ_applications` | Civilian applications | `type`, `status`, `reason`, `reviewed_by` |
| `ul_civ_calls` | Portal 911 calls and service requests (tracking) | `civ_id`, `service`, `ref_id` |
| `ul_settings` | Admin Dashboard settings and law overrides | `skey`, `svalue` |

In standalone mode, people are referenced by their **civilian profile ID** (`ul_civilians.id`, starting at 1000), and their licenses are stored on the profile. With UnitLink-Core, they're referenced by the **character ID**, and licenses are in its metadata (`licenses`). Fines are stored inside a citation's `data` JSON as `fine` and `fineExpires`.
