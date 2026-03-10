# Obyw.one — Session Log 2026-03-10

## What was done

### Website (v1 — shipped)
- Static single-page site: splash animation, hero, services (4 cards), projects (tabbed), footer
- Dark/light theme with system preference detection + toggle + localStorage persistence
- Splash: 2-step animation — `ignite` glow (3s) → `disappearRight` (0.3s) → content fade-in → header logo fade-in
- Umami analytics integrated (self-hosted at `umami.obyw.one`, website-id: `9d76aaa3-a65a-48a3-8ffd-d5f74cd0dbd5`)
- Projects: WabiSabi, Brainy, Shiki, EDL (État des Lieux)
- Footer: Projects (scroll), Contact (mailto:hello@obyw.one), Publications (Medium), Theme toggle
- Responsive: 4-col → 2-col services grid, horizontal project tabs on mobile

### CV ATS Optimization
- HTML + Markdown versions at `CV-2026/`
- Quantified metrics on every bullet (1.7M users, 8M+ MAU, 40% build time reduction, etc.)
- 50+ ATS keywords, no phone/email — LinkedIn centralizes contact
- obyw.one link added

### EDL Project
- Cloned from `github.com/Philthestyle/EDL.git`
- Moved to `projects/edl/`
- Builds and runs on iPhone 16 Pro simulator (iOS 18.2)
- Added to obyw.one website as 4th project tab

### iOS Process Kit
- Exported as `~/Desktop/claude-ios-process-kit.zip` (32 files)
- Includes: slash commands, process skills, Swift addons, review checklists, AGENT.md, settings.json, project-adapter template
- Ready to drop into any iOS project for a coworker

### Infrastructure
- `hello@obyw.one` email redirection set up via OVH

## Pending / Next

### Splash Screen Animation v2
- Storyboard at `docs/storyboard-splashscreen-v1.md`
- Concept: Sith hooded figure, lightsaber ignition, "Obyw.one" appears at blade tip
- 7 frames, 5s duration, black & white only
- AI video gen prompt ready for See Dance 2.0 / Kling / Runway
- Logo derivation: full mark (text + blade + figure), wordmark, icon
- Implementation: `<video>` in splash div → handoff to existing CSS transition on `ended`
- localStorage skip for return visitors

### Publications / Blog
- User exploring options (Ghost self-hosted, Hugo/Astro static, or hosted platforms)
- Decision pending — update footer Publications link when chosen

### Design Polish (future)
- Consider sound design for splash (lightsaber hum)
- Always-dark splash regardless of theme
- Mobile performance: video vs Lottie vs CSS-only
