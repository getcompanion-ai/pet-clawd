# Official Clawd mascot assets (Claude Code desktop app)

Extracted 2026-06-12. These are the GIFs the Claude Code desktop app actually
displays (the creature seen walking along the bottom of the session UI).
Served from `https://claude.ai/images/clawd/`; referenced in
`/Applications/Claude.app/Contents/Resources/ion-dist/assets/v1/*.js`.

Anthropic's official art — internal/reference use for recreating the mascot.

## Core set (`/images/clawd/core/`)

All GIFs run at **80 ms/frame (12.5 fps)** unless noted. Canvas 2750×1850
(core) with the crab small and centered — use the trimmed frames.

| File | Frames | Used in app as |
|---|---|---|
| `Clawd-CrabWalking.gif` | 20 | session working/loading indicator (the screenshot creature) |
| `Clawd-Waving.gif` | 17 | welcome/onboarding greeting |
| `Clawd-Lurking.gif` | 67 | peeking out of promo/upsell cards |
| `Clawd-Still.png` | 1 | static fallback when `shouldAnimate` is false (reduced motion) |

## Persona set (`/images/clawd/persona/`, 1189×800)

| File | Frames | Scene |
|---|---|---|
| `Clawd-RacingCar.gif` | 48 | driving a racing car (checkered-flag theme) |
| `Clawd-Magnifier.gif` | 113 | inspecting with a magnifying glass |
| `7bbe5052.gif` | 11 @ 160 ms | sailing a boat |
| `ac0fa108.gif` | 68 | (other persona scene) |

## frames-walk-trimmed/

`Clawd-CrabWalking.gif` exploded to 20 PNGs and cropped to the union bounding
box (1200×849) so the walk bob (~50 px vertical) is preserved and frames align.
Ready for an SKTextureAtlas. Source pixels are chunky (~50 px per art-pixel) —
render with nearest-neighbor (`texture.filteringMode = .nearest`).

## Relation to `../clawd-frames/` (ClawdDash sheets)

Same character, two renditions: ClawdDash sheets are the mini-game variant
(94×71/frame: walk 20f @85 ms, jump 21f @30 ms, annoyed 49f @85 ms — the only
official JUMP animation we have). This core set is the higher-res app rendition
(walk/wave/lurk + persona scenes). Use core for look/proportions, ClawdDash
jump for jump reference.

## Recreation plan (rig, not filmstrip)

Rebuild as a layered SpriteKit rig matching these proportions/palette
(body ~#DE886D / #D7774A range, eyes #000): legs, torso, claws, eyes as
separate SKNodes; walk/wave cycles as per-part SKActions; eyes as a
runtime-positioned layer (cursor tracking). Use these frames as the
frame-by-frame reference for poses and timing.
