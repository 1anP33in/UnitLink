# Fleet & Road Alerts

## Fleet & Equipment

**Vehicles:** every vehicle in `Config.Dot.fleet` with its type, assigned employee, availability (AVAILABLE, IN USE, OUT OF SERVICE) and last service date.

* Picking a vehicle in the status bar marks it **IN USE** by you.
* **Out of service** vehicles can't be picked. **Return to service** brings them back.

**Equipment Inventory:** cones, arrow boards, signs and the rest from `Config.Dot.equipment`, with how many are available and who has them checked out. You can't check out more than are left.

**Maintenance Records:** log work on a vehicle or item as OPEN or DONE. Marking an open record done puts the vehicle back in service.

## Road Alerts

| Section | Shows |
|---|---|
| **Road Closures** | Requested and active closures. Supervisors **Approve** requests and **Reopen** active roads. Every on-duty unit is told when a road closes or reopens |
| **Major Highway Hazards** | Open hazard and debris jobs, and priority 1 recoveries |
| **Traffic Control Requests** | Open traffic management jobs |
| **Emergency Roadside Requests** | Priority 1 and 2 roadside and recovery jobs |
| **Active Construction Zones** | Open construction jobs |
| **Department Announcements** | The last 10. Supervisors post them |
