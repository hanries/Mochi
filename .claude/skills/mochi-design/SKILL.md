---
name: mochi-design
description: Design language, character rules, and motion guidelines for the EasyFit/Mochi app. Use whenever building or modifying UI, animations, Mochi's states or dialogue, notifications, or onboarding in this project.
---

# Mochi Design Language

This app's identity: "Keep Mochi happy by taking care of yourself." Mochi is a
warm painterly hamster; the entire UI is his home. Every visual and copy
decision derives from him.

## The golden rule (never break)

Mochi's emotional states react ONLY to engagement (logging, streaks, opening
the app) — NEVER to calorie outcomes, food choices, weight, or goal overshoot.
No state, dialogue line, notification, or visual may judge what the user ate.
Sad states read as "Mochi misses you," never disappointment. No guilt
mechanics anywhere.

## Styling

- ALL styling goes through MochiTheme tokens. Never inline colors, fonts, or
  radii. If a needed token doesn't exist, add it to MochiTheme and use it.
- Palette is derived from Mochi's artwork: background #FAF5EC, surface
  #F3E9DA, surfaceAlt #FFFFFF, primary #F29D45, accent #F2697D, textPrimary
  #4A2A12 (never pure black), textSecondary #9A7B5F, success #7FA86F,
  warning #E8A21F. No teal, no mint, no cold grays, no pure black
  backgrounds. Dark mode (when built) uses warm charcoal #241B14, never
  blue-black.
- Typography: SF Rounded everywhere via .system(design: .rounded).
- Radii: cards 22, primary buttons 28. Spacing scale 4/8/12/16/24/32.
- Aesthetic register: calm, cozy, premium pet-care (Finch, Duolingo) — not
  clinical fitness dashboard, not childish game. Whitespace is a feature.

## Character & assets

- Asset names: mochi_happy, mochi_happy_blink, mochi_content, mochi_eating,
  mochi_sleepy, mochi_ecstatic, mochi_missing, mochi_missing_blink;
  habitat_day, habitat_night. All image references go through
  MochiAssetProvider — views never hardcode image names.
- State → trigger map: happy = logged today; content = calm resting
  mid-streak; sleepy = evening with no log yet; missingYou = 24h+ without a
  log; eating = fires on every successful food log (~2.5s, then back);
  ecstatic = reserved for streaks and milestones only. Never cheapen
  ecstatic by using it for routine logs.
- The habitat image is bottom-anchored so the rug is always visible; Mochi
  sits ON the rug (~62% screen width) with his breathing-synced ground
  shadow. The habitat never sits behind body text.

## Motion

- All timing constants live in MochiMotion. Tune there, never inline.
- Breathing is the dominant idle motion (squash-stretch, bottom-anchored,
  ~3.2s; slower when sleepy). Sway is the quietest (≤1°, phase-offset from
  breathing). Blinks are randomized 3-7s with occasional double-blinks.
  Micro-behaviors (hop, ear-wiggle) fire rarely at random 20-45s intervals.
  Nothing repeats on a visible fixed period.
- Amplitude principle: motion should be invisible at a glance, obvious after
  three seconds of staring. When in doubt, halve it.
- Ambient overlays per state: missingYou = drifting soft pink heart;
  sleepy = staggered drifting z's; ecstatic = brief sparkle pops.
- Always respect Reduce Motion: transforms become gentle opacity changes.

## Voice (dialogue, notifications, onboarding copy)

- Mochi speaks in short, warm, first-person-ish lines: "Mochi missed you!",
  "Yum!! Thank you!", "You're taking such good care of us."
- Never: calorie numbers, food judgments ("maybe skip dessert"), guilt
  ("Mochi is disappointed"), streak threats, or medical/diet advice.
- Notifications: max 1/day, in Mochi's voice, gentle, never referencing
  amounts eaten.

## Process

- When adding screens, match the Home tab's patterns before inventing new
  ones. When a design decision isn't covered here, ask rather than introduce
  a new visual idea.
