# Editing the Laws

The San Andreas Penal Code is `Config.Laws` in `UnitLink-CAD/config.lua`. Each line is one offense:

```lua
{ code = '2-08', offense = 'Driving Under the Influence', class = 'M', points = 6,
  note = 'Suspends license at 12 points', aliases = { 'dui', 'dwi', 'drunk' } },
```

| Field | Required | Meaning |
|---|---|---|
| `code` | yes | Section number shown as `§2-08` |
| `offense` | yes | Name |
| `class` | yes | `F` felony, `M` misdemeanor, `I` infraction |
| `points` | yes | License points a citation adds (`0` for none) |
| `note` | no | Shown in the Laws list |
| `aliases` | no | Extra search words, such as `dui` or `gta` |

## Tips

* **Felonies** (`F`) can never be put on a citation.
* Use **aliases** for the short forms officers actually type.
* Keep codes unique. Forms find charges by their code.
* Reload with `ensure UnitLink-CAD`.
