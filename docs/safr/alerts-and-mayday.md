# Alerts & MAYDAY

The **Alerts** screen has these sections:

| Section | Shows |
|---|---|
| **Active Medical Calls** | Every MEDICAL incident |
| **Active Fire & Hazmat Calls** | FIRE and HAZMAT incidents |
| **Rescue Requests & MVCs** | RESCUE and MVC incidents |
| **Mutual Aid Requests** | Help asked from another department. **+ Request mutual aid** picks the station, the department (SASP, BCSO, LSP, DOT) and what you need, and every on-duty unit in that department is notified. **Mark filled** closes it |
| **Station Announcements** | Supervisors post with **Announce** (toolbar) or **+ Post**. Every on-duty SAFR unit gets it |

## MAYDAY

**Mayday** (red, on the toolbar) is for a firefighter who is down, lost, trapped or out of air.

1. Describe the situation (LUNAR: Location, Unit, Name, Assignment, Resources).
2. **Every on-duty unit**, police included, is alerted with your location. Set `Config.Fire.maydayAll = false` to alert SAFR only.
3. A flashing **MAYDAY** banner shows on every SAFR board and status bar, and a note is added to your incidents.
4. Only **one** MAYDAY can be active at a time.
5. Click **Clear · PAR** once the firefighter is accounted for. Only the unit that called it, or a supervisor, can clear it.
