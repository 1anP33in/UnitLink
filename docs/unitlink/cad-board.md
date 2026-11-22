# CAD Board

The main screen has two grids.

## Active Calls (top)

Columns: Call#, Nature, Location, City, County, Priority, Status, Units, Age.

* **Click** a call to select it. **Assign Self** then attaches you to it.
* **Double-click** a call to open its [call record](call-records.md).
* **+** creates a self-initiated call.
* **Search** filters the list as you type.

| Row color | Meaning |
|---|---|
| Red | Priority 1 |
| Yellow | Pending: nobody is attached yet |
| Green | Units are working it |

## Units (bottom)

Columns: Officer, Unit, Status, Call#, Agency, Location, Description. You can filter by agency or search.

| Color | Status |
|---|---|
| Green | **AVAIL**: Available |
| Yellow | **ENRT**: En Route |
| Pink | **ARRVD**: On Scene |
| Orange | **BUSY**: Busy |
| Red | **UNAV**: Unavailable |
| Cyan | A unit from another department type |

Your own row has a status dropdown. You can also change your status from the status bar.

{% hint style="info" %}
**ENRT** and **ARRVD** only work while you're attached to a call.
{% endhint %}
