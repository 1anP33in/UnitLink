# Database Tables

UnitLink creates these tables through oxmysql on start (`Config.AutoInstallSql`), or you can run `unitlink/sql/install.sql` yourself. Every query is parameterized.

| Table | Holds | Key columns |
|---|---|---|
| `ul_call_notes` | Notes on calls | `call_id`, `author_char`, `created_at` |
| `ul_call_history` | Closed calls (History, Address History) | `call_id`, `priority`, `pos_x`, `pos_y`, `created_at`, `closed_at` |
| `ul_records` | Citations, arrests, reports, warrants | `subject_char`, `officer_char`, `call_id`, `data` (JSON: charges, location, narrative…) |
| `ul_alerts` | BOLOs and alerts | `subject_char`, `created_at` |
| `ul_returns` | State returns that were run (Returns log) | `officer_char`, `subject_char`, `call_id`, `created_at` |

Characters are referenced by their **tsrp-core character ID**. Licenses aren't in these tables; they're in tsrp-core character metadata (`licenses`).
