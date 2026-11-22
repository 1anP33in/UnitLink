# SAFR Reports

| Report | Required | Main fields |
|---|---|---|
| **Patient Care Report** | Patient, narrative | Incident, chief complaint, severity, vitals, condition, treatment, destination |
| **Fire Incident Report** | Narrative | Fire type, property use, area of origin, cause, estimated damage, apparatus on scene |
| **Rescue Report** | Narrative | Rescue type, victims, equipment used, outcome |
| **Vehicle Collision Report** | Narrative | Vehicles involved, extrication, patients, hazards, driver |
| **Hazardous Material Report** | Narrative | Substance, UN / NA number, quantity, evacuation radius, decon |
| **Hospital Transport Report** | Patient, narrative | Picked up from, destination, transport unit, priority, condition on arrival |

* **Narratives** need at least **20 characters** (`Config.Fire.minNarrative`).
* **Dropdowns** are checked on the server.
* **Linking an incident** adds a note to that incident.
* **Patients from reports:** a Patient Care or Transport Report with a patient and an incident also adds that patient to the incident, if they aren't already on it.
* **My Reports** lists everything you've filed. Click one to read it back.
* **Changing the forms:** the forms and their fields are set in `config.lua` (`Config.Fire.forms`), so you can add or change fields.
