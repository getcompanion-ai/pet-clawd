# Official Clawd sprite sheets (from ClawdDash)

Extracted 2026-06-12 from the Claude desktop app's "ClawdDash" mini-game
(Easter egg in Claude Code sessions). Sheets are served from
`https://claude.ai/clawd-frames/`; the game logic lives in the app bundle at
`/Applications/Claude.app/Contents/Resources/ion-dist/assets/v1/c1a1184fb-r29IPFuJ.js`
(component `ClawdDashOverlay`).

These are Anthropic's official Clawd pixel art — frame-perfect reference for
recreating the mascot. Internal/reference use.

## Sheets

All frames are **94 px wide × 71 px tall**, laid out horizontally
(`backgroundPosition = -frame * 94`). Render with `image-rendering: pixelated`
(nearest-neighbor) — the art is chunky pixel art at native ~16px grid upscaled.

| File | Frames | Animation | Frame duration |
|---|---|---|---|
| `all-sprite.png` (1880×71) | 20 | walk cycle (leg shuffle, eye blinks) | 85 ms (~11.8 fps) |
| `jumping-sprite.png` (1974×71) | 21 | jump: anticipation squash → airborne (faces camera, legs tuck) → land + recover | 30 ms (~33 fps) |
| `annoyed-sprite.png` (4606×71) | 49 | annoyed/game-over reaction (party-hat accessory, stomping tantrum); game holds last frame | 85 ms (~11.8 fps) |
| `sky.svg` | — | parallax background, tiles horizontally at 440 px period | scrolls 22 px/s |

## Game physics constants (for matching feel)

From the minified source (units: px and seconds, y-up, ground at y=0):

- jump impulse: `vy = 720`
- gravity: `vy -= 2400 * dt`
- fast-drop (down arrow): `vy = min(vy, -1400)`
- frame stepping: accumulate ms, advance while `frameTime >= duration` (catch-up loop)
- dt clamped to 50 ms max per tick
- other constants: `ir=94` (frame width), `lr=52, cr=60, dr=14, ur=14` (hitbox/obstacle sizing)

## Notes for Clawd-the-app

- Current `CrabSpriteRenderer.swift` uses hand-coded 16×16 int arrays; these
  sheets replace that with the official art. Slice into per-frame textures or
  keep as an atlas and offset by 94 px.
- The jump sheet's 30 ms cadence is what makes the leap feel snappy — keep
  per-sheet frame durations, don't use one global rate.
- No idle sheet exists in the game; idle = walk frame 0 (game shows
  `backgroundPosition: 0px` before start). Blinks are baked into the walk cycle.
