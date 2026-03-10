# Obyw.one — Splash Screen Animation Storyboard v1

## Concept

A hooded Sith-like figure emerges from darkness, ignites a lightsaber, performs a quick flourish, then plants it vertically. The company name **Obyw.one** appears as a glow reflection at the tip of the blade. This final frame becomes the logo, which transitions to the website header.

**Reference**: Obi-Wan Kenobi → Obyw.one (dark side twist)
**Style**: Black & white, high contrast, silhouette only, no face visible
**Duration**: 3–5 seconds
**Output**: Video (for See Dance 2.0 / AI video gen) → then coded as web animation

---

## Color Palette

| Element | Color |
|---------|-------|
| Background | Pure black `#000000` |
| Figure | Dark silhouette, barely visible `#0a0a0a` to `#1a1a1a` |
| Lightsaber blade | White glow `#ffffff` with soft bloom |
| Lightsaber glow | Subtle halo `rgba(255,255,255,0.3)` — NO color (not red, blue, green) |
| Text "Obyw.one" | White with lightsaber glow bleeding into letters |

---

## Storyboard Frames

### Frame 1 — The Void (0.0s – 0.3s)

```
┌─────────────────────────────┐
│                             │
│                             │
│         (pure black)        │
│                             │
│                             │
└─────────────────────────────┘
```

- **Visual**: Complete darkness. Nothing visible.
- **Sound design** (optional): Low rumble, distant hum
- **Motion**: None. Hold black for tension.

---

### Frame 2 — The Presence (0.3s – 0.8s)

```
┌─────────────────────────────┐
│                             │
│          ▓▓▓▓▓▓▓            │
│         ▓▓█████▓▓           │
│         ▓▓▓▓▓▓▓▓▓           │
│          ▓▓▓▓▓▓▓            │
│           ▓▓▓▓▓             │
│            ▓▓▓              │
│            ▓▓▓              │
│           ▓▓▓▓▓             │
│          ▓▓▓▓▓▓▓            │
└─────────────────────────────┘
```

- **Visual**: A hooded figure fades in from the darkness. Barely distinguishable — dark gray silhouette on black. Hood up, face completely hidden in shadow. Standing centered, arms down.
- **Framing**: Medium shot, waist up. Figure occupies ~40% of frame height.
- **Motion**: Slow fade-in (opacity 0 → 0.15). The figure is more *felt* than seen.
- **Key detail**: The hood casts deep shadow. NO facial features. Just the shape of a robe.

---

### Frame 3 — The Ignition (0.8s – 1.3s)

```
┌─────────────────────────────┐
│                             │
│          ▓▓▓▓▓▓▓            │
│         ▓▓█████▓▓           │
│         ▓▓▓▓▓▓▓▓▓           │
│        ▓▓▓▓▓▓▓▓▓▓▓          │
│           ▓▓▓▓▓             │
│          ──●──              │
│            │                │
│            │ ← saber hilt   │
│                             │
└─────────────────────────────┘
         ↓ then ↓
┌─────────────────────────────┐
│            ░                │
│          ▓▓║▓▓▓             │
│         ▓▓█║██▓▓            │
│         ▓▓▓║▓▓▓▓            │
│        ▓▓▓▓║▓▓▓▓▓           │
│           ▓║▓▓              │
│          ──●──              │
│            │                │
│            │                │
│                             │
└─────────────────────────────┘
```

- **Visual**: The figure raises a hand to chest level. A lightsaber hilt is visible. In one swift motion, the blade IGNITES — a vertical white beam shoots upward.
- **Motion**: Blade extends from hilt upward in ~0.2s. The white glow illuminates the edges of the hood and robe (rim lighting effect).
- **Light**: The blade is pure white — intentionally ambiguous. Could be any side of the Force.
- **Glow**: Soft bloom around the blade, ~20px radius. The immediate area around the figure gets a faint wash of light.
- **Key detail**: The ignition briefly reveals the texture of the robe fabric, then settles to a softer glow.

---

### Frame 4 — The Flourish (1.3s – 2.5s)

```
  Subframe A (1.3s)        Subframe B (1.8s)        Subframe C (2.2s)
┌───────────────────┐   ┌───────────────────┐   ┌───────────────────┐
│        ░          │   │                   │   │                   │
│      ▓▓║▓▓        │   │      ▓▓▓▓▓▓       │   │         ░        │
│     ▓█████▓       │   │     ▓█████▓       │   │      ▓▓▓║▓▓      │
│     ▓▓▓▓▓▓▓   ╲   │   │     ▓▓▓▓▓▓▓       │   │     ▓▓▓▓║▓▓     │
│      ▓▓▓▓▓  ═══╪  │   │  ═══▓▓╪══════    │   │      ▓▓▓║▓▓     │
│       ▓▓▓       │   │      ▓▓▓▓▓       │   │       ▓▓║▓▓      │
│       ▓▓▓       │   │      ▓▓▓▓▓       │   │        ║        │
│                   │   │                   │   │        ●        │
│                   │   │                   │   │        │        │
└───────────────────┘   └───────────────────┘   └───────────────────┘
  Diagonal slash          Horizontal sweep         Vertical plant
```

- **Visual**: The figure performs a short, controlled lightsaber trick. NOT flashy — deliberate, masterful.
- **Subframe A** (1.3s): Blade held diagonally, slight upward angle
- **Subframe B** (1.8s): Smooth horizontal sweep at chest level — the blade traces a white arc (motion blur trail)
- **Subframe C** (2.2s): The figure brings the blade down and forward, planting it VERTICALLY in front of them, pointing straight up
- **Motion**: Fluid, single continuous movement. Think Dooku's elegant style, not Maul's acrobatics.
- **Light trails**: The blade leaves a faint afterglow trail during the sweep (fades in ~0.15s)
- **Key detail**: The motion is confident and slow enough to feel intentional. Speed: 70% of what feels natural.

---

### Frame 5 — The Reveal (2.5s – 3.5s)

```
┌─────────────────────────────┐
│                             │
│         O b y w . o n e     │  ← text appears as glow
│         ░░░░░░░░░░░░░       │  ← light bleeds from blade tip
│            ░                │
│            ║                │
│          ▓▓║▓▓▓             │
│         ▓▓█║██▓▓            │
│         ▓▓▓║▓▓▓▓            │
│          ▓▓║▓▓▓             │
│           ▓║▓               │
│            ●                │
│            │                │
└─────────────────────────────┘
```

- **Visual**: The blade is vertical, centered. The figure stands behind it, holding the hilt low. At the TIP of the blade, light bleeds outward and the text **Obyw.one** materializes — as if the lightsaber's energy is writing the name.
- **Text animation**: Letters appear left to right with a glow effect, like they're being carved by light. Each letter has a brief flash (0.05s) then settles to solid white.
- **Typography**: Monospace (JetBrains Mono / SF Mono), letter-spacing: 0.15em, weight: 300
- **Glow**: The text has the same bloom as the blade — they share the same light source.
- **Key detail**: The text sits RIGHT ABOVE the blade tip. The connection between blade and text is seamless — the light flows upward into the letters.

---

### Frame 6 — The Logo Lock (3.5s – 4.0s)

```
┌─────────────────────────────┐
│                             │
│                             │
│         O b y w . o n e     │
│            ░                │
│            ║                │
│            ║                │
│          ▓▓▓▓▓              │
│         ▓▓███▓▓             │
│          ▓▓▓▓▓              │
│            ●                │
│                             │
│                             │
└─────────────────────────────┘
```

- **Visual**: The glow settles. The figure becomes a clean, minimal silhouette — the LOGO. The composition locks:
  - **Top**: "Obyw.one" text
  - **Middle**: Vertical blade line (thin)
  - **Bottom**: Hooded figure silhouette (small, iconic)
- **Motion**: Everything stabilizes. Glow reduces to a subtle, constant level.
- **This is the logo.** The final composition = brand mark.
- **Hold**: 0.5s on this frame for the mark to register.

---

### Frame 7 — The Transition (4.0s – 5.0s)

```
  4.0s                          4.5s                         5.0s
┌───────────────────┐     ┌───────────────────┐     ┌───────────────────┐
│                   │     │ Obyw.one     ☾    │     │ Obyw.one     ☾    │
│                   │     │                   │     │                   │
│    Obyw.one       │     │                   │     │  We design and    │
│       ║           │  →  │                   │  →  │  build digital    │
│     ▓▓▓▓▓         │     │                   │     │  products.        │
│    ▓▓███▓▓        │     │                   │     │                   │
│     ▓▓▓▓▓         │     │                   │     │  DESIGN | DIGITAL │
│                   │     │                   │     │     AGENCY        │
│                   │     │                   │     │                   │
└───────────────────┘     └───────────────────┘     └───────────────────┘
  Logo centered            Logo moves to corner       Website content
  Silhouette fades         Text shrinks               fades in
```

- **Visual**: The logo (text + blade + figure) transitions to become the header:
  1. The silhouette and blade fade out (0.3s)
  2. "Obyw.one" text shrinks and slides to the top-left corner (0.4s ease-out)
  3. Website content fades in below (0.3s)
- **Motion**: This matches the current CSS animation — `disappearRight` for the centered version, then header `opacity: 0 → 1`.
- **End state**: The website is fully visible. "Obyw.one" sits in the header with its characteristic glow (`text-shadow: 0 2px 4px var(--glow)`).

---

## Logo Mark (Derived from Frame 6)

```
     O b y w . o n e
          ░
          ║
          ║
        ▓▓▓▓▓
       ▓▓███▓▓
        ▓▓▓▓▓
          ●
```

**Usage**:
- Full mark: text + blade + figure (splash, about page, print)
- Wordmark only: "Obyw.one" with glow (header, small sizes)
- Icon only: hooded figure + blade (favicon, app icon)

---

## Technical Notes

### For AI Video Generation (See Dance 2.0 / Kling / Runway)

**Prompt structure suggestion:**

> A hooded figure in a dark robe stands in complete darkness, face hidden in shadow. Pure black and white, no color. The figure ignites a lightsaber — the blade is pure white light. They perform a single elegant flourish, then plant the blade vertically in front of them. The light from the blade tip forms the text "Obyw.one" above. Cinematic, minimal, high contrast silhouette. 4 seconds.

**Negative prompt:** color, face, detailed features, bright background, multiple characters

**Style references:**
- Rogue One: Vader hallway scene (silhouette + saber glow)
- The Mandalorian: Darksaber ignition scenes
- Apple product reveal aesthetics (dark, minimal, precise)

### For Web Implementation

The current CSS animation (`ignite` + `disappearRight`) handles Frame 7 (transition to website). The video portion (Frames 1–6) would play as:
- `<video>` element in the splash div, autoplay, muted, playsinline
- On `ended` event → trigger the existing splash-to-header transition
- Fallback: current text-only animation for slow connections

### Aspect Ratios

- **Mobile-first**: 9:16 (vertical, matches phone screen)
- **Desktop**: 16:9 (horizontal, letterboxed or cropped)
- **Square**: 1:1 (social media / favicon derivation)

---

## Open Questions

1. **Sound?** A lightsaber hum + ignition sound would elevate it massively. Royalty-free Star Wars sound-alikes exist. Worth adding?
2. **Theme-aware?** Dark theme = white blade on black. Light theme = dark blade on white? Or always dark?
3. **Skip button?** After first visit, show a "skip" option or reduce to 2s version?
4. **Mobile performance**: Video vs Lottie vs CSS-only for the final implementation?
