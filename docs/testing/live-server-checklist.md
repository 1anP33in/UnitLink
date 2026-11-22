# Live Server Checklist

UnitLink has been checked offline but **not on a live FXServer yet**. Go through this list on a test server. Tick off each item as you go.

- [ ] 1. Off duty, `/cad` says you must be on duty. A SAFR unit can't open it (by default).
- [ ] 2. On duty as SASP, `/cad` opens, you hold a tablet, and your unit shows **AVAIL**.
- [ ] 3. A civilian does `/911 test`. The call appears on the board within a second, with a "911 CALL RECEIVED" note.
- [ ] 4. Accept with **Y** on the 911 card. The CAD shows you attached and **ENRT**, with a system note.
- [ ] 5. **ARRVD** in the CAD turns the status pink and adds a note. Changing the priority updates both the note and the 911 card.
- [ ] 6. A second officer adds a note, and it appears live on your open call.
- [ ] 7. **New Call** (traffic stop) is created at your location, you're attached, and other units get no popup.
- [ ] 8. Closing the call moves it to History and puts its units back to AVAIL. Reopened, it's read-only.
- [ ] 9. Search a character by name and by ID, and run the return.
- [ ] 10. A citation with a felony is refused. A speeding citation adds points. At 12+ points the license shows **SUSPENDED**.
- [ ] 11. A non-supervisor's warrant is pending and supervisors are notified. A supervisor approves it, the subject shows **WANTED**, then **Mark Served** works.
- [ ] 12. Adding a BOLO notifies every on-duty unit. Removing it works.
- [ ] 13. Signal 100 from a supervisor shows on every tablet. A non-supervisor can't set it.
- [ ] 14. Going off duty with the tablet open closes it.
- [ ] 15. `restart UnitLink-CAD` with the tablet open gives control back and removes the prop.

If something fails, note the item number and any console errors (F8, and the server console).
