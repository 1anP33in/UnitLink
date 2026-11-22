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

In standalone mode, people are referenced by their **civilian profile ID** (`ul_civilians.id`, starting at 1000), and their licenses are stored on the profile. With UnitLink-Core, they're referenced by the **character ID**, and licenses are in its metadata (`licenses`). Fines are stored inside a citation's `data` JSON as `fine` and `fineExpires`.
