# Mochi — App Store screenshots

10 marketing screenshots for the App Store, built as faithful mockups of the
real app screens (exact `MochiTheme` colors, the app's SF Rounded font, and the
real Mochi character + habitat artwork) composited onto branded backgrounds.

## Deliverables — `appstore/`
All **1290 × 2796 px** — the unified iPhone 6.5"/6.7"/6.9" display slot in
App Store Connect (that slot also accepts 1260 × 2736 and 1320 × 2868).
Size is one render arg, so any accepted size is a one-liner (see below).

| # | File | Story |
|---|------|-------|
| 01 | `01_meet_mochi.png` | Brand intro — Mochi's home screen |
| 02 | `02_scan.png` | AI food scan (snap → calories + macros) |
| 03 | `03_meals.png` | Day at a glance (calorie ring + macros) |
| 04 | `04_search.png` | Log any way (huge food database) |
| 05 | `05_streaks.png` | Streaks + logging calendar |
| 06 | `06_no_guilt.png` | The differentiator: no guilt, ever |
| 07 | `07_moods.png` | Mochi's moods / personality |
| 08 | `08_weight.png` | Gentle progress + weight trend |
| 09 | `09_world.png` | Living day/night habitat |
| 10 | `10_cta.png` | Closing call-to-action |

`../contact_sheet.png` is an overview grid of all 10.

## Editing / re-rendering — `build/`
Each frame is a standalone HTML file (`01.html`…`10.html`) sharing `shared.css`
(design tokens + iPhone mockup). Headlines, copy, and numbers are plain text in
the HTML — edit and re-render:

The export size is driven entirely by the render args (width height) — the
design canvas is fixed and scaled to the target, so no layout reflows:

```bash
cd build
./render.sh 01.html ../appstore/01_meet_mochi.png  1290 2796     # default slot (6.5/6.7/6.9")
./render.sh 01.html out_1320x2868.png              1320 2868     # 6.9" max res
./render.sh 01.html out_1284x2778.png              1284 2778     # 6.5"-only field
```

`build/img/` holds copies of the Mochi/habitat art and `build/SFRounded.ttf` is
the system SF Rounded used so text matches the app exactly. Rendering uses
headless Google Chrome — no extra install needed.
