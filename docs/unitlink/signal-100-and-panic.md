# Signal 100 & Panic

## Signal 100

**Signal 100** means emergency radio traffic only. When it's set:
* every open tablet shows a flashing **SIGNAL 100** in its status bar
* every on-duty unit gets a notification

The same button clears it.

By default only **supervisors** can set it (`Config.Signal100SupervisorOnly = true`).

## Panic

**Panic** sends the UnitLink-Police panic: an urgent card goes to every on-duty unit, with your location, and a red area appears on their map for 2 minutes. It works the same as `/panic`.
