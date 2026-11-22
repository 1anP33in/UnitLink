# Incidents & Patients

## Incident record

Double-click an incident on the board.

**Left side**

* **Header:** the units with their status, the created time, and the source (911 or CAD).
* **Editable fields:** **Call Type**, **Nature** (the list follows the type), **Priority** and **Patient Count**. Every change is logged as a note.
* **Read-only fields:** address, city, caller and callback number.
* **Personnel:** everyone attached, and their apparatus.
* **Buttons:**
  * **Assign Self** when you're not attached.
  * **ENRT / ONSCN / TRANS / ATHSP / Clear Self** when you are.
  * **GPS** sets a waypoint, and **Close** (trash icon) closes the incident.

**Tabs**

| Tab | Shows |
|---|---|
| **Notes** | Live, timestamped notes. Attaches, status changes, edits, patients, reports and MAYDAYs are logged automatically |
| **Patients** | Everyone treated on this incident, with **+ Add Patient** and **Write Patient Care Report** |
| **Info** | Caller, callback, the caller's statement, and how long it's been open |
| **Nearby History** | Closed incidents within 60 m |

**Closing**

* **Who can close it:** units on the incident, or a supervisor.
* **Disposition:** pick one, such as TRANSPORTED, TREATED / RELEASED, REFUSAL SIGNED, FIRE OUT or FALSE ALARM.
* **After closing:** the incident goes to History, its units go back to AVAIL, and reopening it shows it read-only.

## Adding a patient

Click **+ Add Patient** on the Patients tab.

1. **Find the person:** search by name or ID and pick them. Leave it empty for an **unidentified** patient.
2. **Describe the injury or illness.**
3. **Set the details:** severity (Minor, Moderate, Serious, Critical, Deceased), condition (Stable, Improving, Unchanged, Deteriorating, Critical) and treatment.
4. **Pick the destination:** a hospital, REFUSED TRANSPORT or NOT TRANSPORTED.

The patient count updates by itself, and a note is added.

## Patient records

Click **Patients** on the toolbar.

* **Search** any civilian by name or ID. Each result shows how many SAFR visits they've had.
* **Medical history:** pick a person to see every visit (date, incident, injury, severity, treatment, destination, condition). Click a visit to open its incident.
* **Write Patient Care Report** or **Hospital Transport Report** opens the form with the patient already filled in.
* With nobody selected, **Recent Patients** shows the last 25.
