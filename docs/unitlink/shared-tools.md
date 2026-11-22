# Shared Tools

Every department tablet (police, SAFR and DOT) has a **Tools** button. It opens one window, in the same CAD style, with tools every department shares.

| Tool | What it does |
|---|---|
| **Global Search** | People, registered vehicles (by plate, model or owner), police calls, SAFR incidents, DOT work orders and BOLOs. **Records** (citations, arrests, warrants) only show for police |
| **Messages** | Send to **all units**, a **department**, or **one unit**. They get a notification and a badge on the Tools button. The inbox keeps the last 3 days (`Config.Tools.messageDays`) |
| **BOLOs** | Shared BOLOs every department sees. Types are in `Config.Tools.boloTypes`. Civilians who report their car stolen add one automatically |
| **Incident Links** | Tie a police call (`#`), a SAFR incident (`F-`) and a DOT work order (`WO-`) together. Click a result in Global Search to jump here |
| **Activity** | Your own actions. Supervisors also see their whole department |
| **Employees** | Everyone who has opened a tablet: department, callsign, certifications, on or off duty. Activity is shown to the person and their department's supervisors |

{% hint style="info" %}
Police alerts (Alerts screen in the police CAD) stay police-only. Shared BOLOs are the cross-department board.
{% endhint %}
