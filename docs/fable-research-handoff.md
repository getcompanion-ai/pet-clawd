# Clawd Research Handoff For Fable

Last updated: 2026-06-12

## Goal

Research Clawd deeply enough that Fable can take over implementation without
repeating discovery. Optimize for objective truth, exact local evidence, and a
clear confidence score.

## Confidence

Current confidence: 82/100.

Why this moved up:
- Existing Clawd app architecture is verified locally.
- Prior Claude thread stopping point is verified from the JSONL transcript.
- Completed prior-agent reports exist for Clawd, Iris, HeyClicky, macOS window
  APIs, desktop pets, and animation tools.
- Local Claude desktop mascot assets were searched: official Clawd rendered
  reference assets exist, but no editable sprite sheet/Lottie/Rive/rig source
  was found.
- Claude Code MCP, direct Anthropic tool-use docs, local Claude CLI flags, Iris
  voice architecture, and HeyClicky/Cua-style computer-control patterns are now
  verified enough to choose an implementation direction.

Remaining uncertainty:
- Exact first implementation scope depends on whether the next repo stays
  `pet-clawd` or becomes a new mascot-agnostic Clippy-style desktop assistant.
- If the product literally uses Microsoft's Clippy/Clippit name, design, or
  extracted assets, legal/trademark clearance is needed before public release.

## Prior Thread State

The relevant Claude thread is:

`/Users/advaitpaliwal/.claude/projects/-Users-advaitpaliwal-Projects-clawd/77da97ec-e410-403f-b2ad-84faa40febc2.jsonl`

It left off before synthesis. The last real user constraints were:
- Build Clawd as a native Swift/macOS app.
- It only needs to work on Mac.
- Local runtime matters; cloud models are fine.
- No chime/notification sounds, but voice/TTS is allowed as an intentional output.
- Clawd should be Claude's mascot, not a multi-provider generic pet.
- The model should choose text bubbles vs voice, with a user setting that can force either.
- Research the Claude/Claude Code mascot assets locally if possible.

Later user pivot:
- Do not get blocked on a Clawd-specific mascot.
- The stronger product direction is "Clippy-style": a small, persistent,
  morphable desktop assistant whose body becomes gestures/tools/shapes.
- This can still be named Clawd if it stays Claude-branded, but if the user
  wants "a new repo and a new everything", make the codebase mascot-agnostic and
  character-pack driven from day one.

The old run launched several research agents. These completed:
- Clawd architecture review.
- Iris reuse review.
- HeyClicky teardown.
- macOS window geometry/API research.
- Desktop-pet OSS survey.
- Animation-as-tools design.

These failed due to Claude session limit:
- Computer-use/display sandboxing research.
- Local voice/vision research.
- Claude mascot asset extraction.

## Verified Local App Facts

- Repo remote is `https://github.com/getcompanion-ai/pet-clawd.git`.
- Swift package/app name is `Clawd`.
- Existing package targets macOS 13 and only depends on Sparkle.
- The app launches as an accessory app and creates `ClawdController`.
- `ClawdController` owns a `CVDisplayLink` tick loop and currently treats the
  Dock area as the floor.
- `CrabCharacter` owns the pet window, popover chat, preview bubble, emotions,
  drag/fall/walk state, and Claude session.
- The pet window is borderless, transparent, above normal windows, joins all
  spaces, and participates in fullscreen auxiliary spaces.
- `ScreenContext` captures screenshots with CoreGraphics, excludes Clawd's own
  windows, downscales to 1024 max dimension, JPEG-compresses, and sends base64
  to Claude.
- `ClaudeSession` launches the local `claude` binary with streaming JSON input
  and output. It parses assistant text and tool-use events for display, but does
  not execute app-local tools from model calls.
- `CrabSpriteRenderer` renders 14 hardcoded 16x16 pixel frames into `CGImage`s.

## Local Mascot Asset Findings

Official Claude desktop assets do include Clawd rendered reference material:
- `/Applications/Claude.app/Contents/Resources/ion-dist/images/install-hub/clawd-laptop.mov`
  is a 2750x1850 QuickTime/HEVC video, 12 fps, 43 frames, about 3.58 seconds.
- `/Applications/Claude.app/Contents/Resources/ion-dist/images/install-hub/clawd-laptop.webm`
  is the same rendered animation as VP9 WebM.
- `/Applications/Claude.app/Contents/Resources/ion-dist/images/install-hub/clawd-magnifier.gif`
  is an animated GIF, logical 1189x800, 113 frames, about 9.41 seconds.
- `/Applications/Claude.app/Contents/Resources/en-US.json` says Anthropic built
  "a desk pet that lives off permission approvals and interaction with Claude"
  and points users to a `claude-desktop-buddy` repository.

Negative asset evidence:
- No local `.lottie`, `.riv`, `.apng`, sprite sheet, or rigged/editable Clawd
  source was found under the searched Claude desktop, Claude Code, Chrome/Arc
  extension, cache, npm, and `~/.claude` paths.
- `pixel-avatars.png`, `pixel-guidebook-before.png`, and
  `pixel-guidebook-after.png` are useful visual style references, but they are
  static raster artwork, not a reusable animated mascot rig.

Recommendation: do not ship copied Claude desktop media as app assets. Use them
as reference for personality/scale only. The existing Swift renderer should move
toward a character-pack/animation-state system that can support Clawd, a
paperclip-like character, or any future mascot.

## Clippy-Style Direction

The user is now asking why the product cannot simply be Clippy-style instead of
locked to a Clawd-specific mascot.

Answer: the mechanic is right; the literal Microsoft character is the risky
part. Microsoft's own trademark materials list "Clippy" and "Clippy Design" as
Microsoft trademarks, and Microsoft brand guidelines describe names, icons,
designs, trade dress, sounds, emojis, and other brand features as proprietary
brand assets. So a public repo/product should not call itself Clippy, use the
Clippit design, or include Microsoft `.ACS`/image assets unless Microsoft has
licensed it.

The implementable direction is a new morphable mascot with Clippy's interaction
grammar:
- The body is a simple continuous silhouette/line or low-pixel-count creature.
- It has expressive eyes/face as the emotional anchor.
- It can become a checkmark, arrow, question mark, magnifier, shield, cursor
  pointer, progress spinner, paper, keyboard key, terminal prompt, speech tail,
  or warning sign.
- It uses named animation states, not one-off hardcoded effects.
- It gestures toward UI targets and turns into the tool it is using.

Sources to preserve for Fable:
- Microsoft Agent's old character runtime exposed `Show`, `Hide`, `Play`,
  `Speak`, `MoveTo`, `GestureAt`, `Think`, `Wait`, `Stop`, and `StopAll`.
- Microsoft Agent automatically selected movement/gesture/idle state animations
  and allowed multiple animations per state for variety.
- Microsoft Agent documentation says the character window shape changed to match
  animation frames, creating a sprite floating above the desktop.
- Clippit/Clippy's known animation list included states such as `Alert`,
  `CheckingSomething`, `Congratulate`, `Explain`, `GestureLeft`,
  `GestureRight`, `GetAttention`, `Greeting`, `Hearing_1`, `IdleSnooze`,
  `Processing`, `Searching`, `Thinking`, `Wave`, and `Writing`.
- The Animator vs. Animation depiction is useful as creative reference: Clippit
  is described as a paperclip whose body can transform into shapes such as a
  square, tornado, or checkmark, and whose "powers" include shapeshifting and
  ASCII-art item creation. Treat that as fan-wiki/fiction reference, not a
  source of product rights.

Suggested abstraction:
- `CharacterPack`: metadata, base proportions, palette, hit mask, animation
  states, morph targets, speech-bubble anchor, tool anchors.
- `AnimationState`: idle, show, hide, listen, hearing, thinking, searching,
  writing, success, warning, error, gesture, move, speak, returnToNeutral.
- `MorphTarget`: named shapes such as `arrow`, `checkmark`, `magnifier`,
  `questionMark`, `shield`, `cursor`, `keycap`, `document`, `spinner`.
- `MascotRenderer`: owns shape interpolation and frame playback.
- `MascotActionQueue`: async queue equivalent to Microsoft Agent's request
  model; actions complete, interrupt, or return to neutral.

If the user wants a new repo, build the first commit around this abstraction
instead of `CrabCharacter`. The app can still run natively on macOS and reuse
the Clawd research for tool bridge, voice, camera, and computer control.

## Provisional Architecture Direction

Use the current Swift app as the host. Do not rewrite in Electron, Chromium, or
web tech.

If the user chooses the new-repo route, still keep the same technical base:
native Swift/macOS app, transparent always-on-top character window, local
permissions held by the app, and sidecars only where they reduce complexity.

Core shape:
- `ClawdRuntime`: single app coordinator for pet bodies, agent sessions, voice,
  camera, terrain, and permissions.
- `PetActor` or `MascotActor`: one character instance with identity, character
  pack, animation state, morph target, tool queue, terrain target, output
  preferences, and per-character Claude context.
- `TerrainMap`: window/platform graph from CoreGraphics and Accessibility.
- `ComputerController`: AX-first actions for buttons/text fields/windows, with
  CGEvent fallback for pixel actions.
- `ClawdToolServer` or equivalent local tool bridge so Claude can call app tools
  such as `perform`, `morph`, `gesture_at`, `set_vibe`, `observe`, `speak`, and
  `bubble`.
- `VoiceRuntime`: likely reuse Iris sidecar architecture for cloud STT/TTS and
  barge-in rather than building ASR/TTS from scratch.
- `CameraContext`: native Swift AVFoundation capture, sampling frames into
  Claude context on explicit triggers or user-approved proactive moments.

## Tool Bridge Decision

The app needs a reverse channel from Claude to the mascot. Today,
`ClaudeSession` only parses `tool_use` / `tool_result` events and shows them in
the UI; it does not execute app-owned tools. That is why the current app feels
like "chat near a character" instead of "a character with agency."

Recommended product path:
- Implement an app-owned tool loop using direct Anthropic API client tools for
  the long-term runtime. Claude's API tool-use model is exactly: Claude emits
  `tool_use`, the client app executes, then returns `tool_result`.
- Keep Claude CLI as a compatibility/prototype backend while the API session is
  built. The installed local CLI supports `--mcp-config`, and Claude Code can
  load local stdio MCP servers, so CLI + stdio MCP can prototype the bridge.
- Do not rely on the Claude API MCP connector for local stdio tools: current API
  MCP connector docs require publicly exposed HTTP/SSE-style servers and say
  local stdio cannot be connected directly.

Recommended app tools:
- Mascot tools: `mascot.observe`, `mascot.perform`, `mascot.morph`,
  `mascot.gesture_at`, `mascot.speak`, `mascot.bubble`, `mascot.set_vibe`.
- Computer tools: `computer.observe_screen`, `computer.observe_ui_tree`,
  `computer.find_element`, `computer.press_element`, `computer.set_text`,
  `computer.focus_app`, `computer.key_combo`, `computer.type_text`,
  `computer.scroll`, `computer.wait`.
- Every action should return a fresh observation or compact diff. This mirrors
  HeyClicky's snapshot-before/snapshot-after invariant.

## Computer Control Decision

Use Accessibility first, with CGEvent only as fallback.

Evidence:
- The macOS SDK exposes `AXIsProcessTrustedWithOptions` for checking/prompting
  Accessibility trust.
- `AXUIElementCopyAttributeValue`, `AXUIElementSetAttributeValue`, and
  `AXUIElementPerformAction` cover the normal read/write/press path for native
  controls.
- `AXUIElementCopyElementAtPosition` hit-tests top-left relative screen
  coordinates, useful for mapping visual observations to AX elements.
- HeyClicky's bundled Cua driver docs repeatedly enforce
  `launch_app -> get_window_state -> act -> get_window_state -> verify` and a
  "no foreground steal" contract.

Implementation rule:
- App-owned Swift code should execute AX/CGEvent actions because Clawd/the new
  app is the process that should hold macOS Accessibility and Screen Recording
  permissions.
- If an MCP server is used, it should be a thin bridge that forwards tool calls
  to the app over loopback/Unix socket. It should not be the permission-owning
  computer controller.
- Default to background-safe element actions. Avoid `open`, AppleScript
  activation, raw coordinate clicks, and cursor warping unless the user
  explicitly wants visible foreground control.

## Voice And Camera Decision

Reuse Iris's architecture, not the whole Iris brain.

Reusable Iris pieces:
- `MicrophonePermission` and `CameraPermission`: tiny AVFoundation wrappers for
  checking/requesting audio/video access.
- `ProcessSupervisor`: starts `uv run iris-voice` style sidecars with env,
  process IDs, and logs under `~/Library/Logs/Iris`.
- `NativeVoiceRuntime`: Swift-side start/stop/status polling around local audio.
- `iris-voice/server.py`: FastAPI endpoints for `/health`,
  `/local-audio/status`, `/local-audio/start`, `/local-audio/stop`,
  `/local-audio/stop-speaking`, plus `/ws`.
- `turns/wake.py`: wake phrase strategy; replace hardcoded `iris` with Clippy
  style variants such as the new assistant name plus likely STT confusions.
- `turns/barge_in.py`: Silero VAD at 16 kHz for barge-in.
- `tts.py`: provider-backed TTS for xAI, Deepgram, OpenAI, and Gemini.

Do not copy Iris's notification/debug chimes into this product; the user already
said no chime/notification sounds. Voice/TTS is acceptable only as intentional
assistant output.

Recommended MVP:
- Sidecar listens for wake + final transcript.
- Swift app receives `transcript.final` and sends text through the existing
  assistant session path.
- Default output mode is bubbles/text; add setting for `bubblesOnly`,
  `voiceAndBubbles`, `voiceForDirectReplies`, and `mute`.
- Camera should be one-shot still capture on explicit request, using
  AVFoundation in Swift. Do not make camera always-on.

## Verification Status

`swift test` passes locally as of 2026-06-12:
- 40 XCTest tests executed.
- 0 failures.
- Covered surfaces: `ChatMessage`, `ClaudeSession` JSON parsing/streaming/tool
  summaries/pending messages/model override, and `ShellEnvironment`.

Not verified:
- Live app launch/UI behavior.
- Real Claude CLI session with app-owned MCP tools.
- Direct Anthropic API tool loop.
- Voice sidecar inside this app.
- Accessibility/computer-control execution.

## Open Questions To Close

- Whether Claude Code can load a local MCP server from Clawd's workspace cleanly
  enough for app tools, or whether direct Anthropic API tool calls are the right
  first implementation.
- Whether the next build should remain in `pet-clawd` or be a new
  mascot-agnostic repo. Current research supports either.
- Exact Iris files to copy/adapt for mic/camera permission, sidecar supervision,
  local HTTP/WebSocket IPC, VAD, barge-in, and TTS playback.
- Best first milestone if staying in `pet-clawd`: app-tools bridge first.
- Best first milestone if starting a new repo: character-pack renderer and
  morph/action queue first, then tool bridge.

## Implementation Bias So Far

If staying in the current repo, first build the app-tool bridge and expose the
existing body as tools. Without that, Clawd remains a chat bubble attached to a
crab rather than a pet with agency.

If making a new Clippy-style repo, first build the mascot abstraction:
character-pack loading, named animation states, morph targets, and an async
action queue. Then wire it to the same assistant/tool bridge. This avoids
hardcoding "crab" or "paperclip" into the architecture and lets the product be
"the desktop agent that can become the tool it is using."

## Source Pointers

Local files:
- `/Users/advaitpaliwal/Projects/clawd/Clawd/ClaudeSession.swift`
- `/Users/advaitpaliwal/Projects/clawd/Clawd/AgentProvider.swift`
- `/Users/advaitpaliwal/Projects/clawd/Clawd/CrabCharacter.swift`
- `/Users/advaitpaliwal/Projects/clawd/Clawd/ScreenContext.swift`
- `/Users/advaitpaliwal/Companion/Code/iris/apps/iris-mac/Sources/IrisMac/NativeVoiceRuntime.swift`
- `/Users/advaitpaliwal/Companion/Code/iris/apps/iris-mac/Sources/IrisMac/ProcessSupervisor.swift`
- `/Users/advaitpaliwal/Companion/Code/iris/apps/iris-mac/Sources/IrisMac/MicrophonePermission.swift`
- `/Users/advaitpaliwal/Companion/Code/iris/apps/iris-mac/Sources/IrisMac/CameraPermission.swift`
- `/Users/advaitpaliwal/Companion/Code/iris/apps/iris-voice/src/iris_voice/server.py`
- `/Users/advaitpaliwal/Companion/Code/iris/apps/iris-voice/src/iris_voice/turns/wake.py`
- `/Users/advaitpaliwal/Companion/Code/iris/apps/iris-voice/src/iris_voice/turns/barge_in.py`
- `/Users/advaitpaliwal/Companion/Code/iris/apps/iris-voice/src/iris_voice/tts.py`
- `/Applications/HeyClicky.app/Contents/Resources/ClickyBundledSkills/cua-driver/SKILL.md`
- `/Applications/HeyClicky.app/Contents/Resources/ClickyBundledSkills/cua-driver/WEB_APPS.md`

Web docs:
- Microsoft Agent states: `https://learn.microsoft.com/en-us/windows/win32/lwef/agent-states`
- Microsoft Agent character animation: `https://learn.microsoft.com/en-us/windows/win32/lwef/animating-a-character`
- Microsoft Agent character methods: `https://learn.microsoft.com/en-us/windows/win32/lwef/character-object-methods`
- Microsoft Agent `GestureAt`: `https://learn.microsoft.com/sk-sk/windows/win32/lwef/gestureat-method`
- Anthropic tool use: `https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview`
- Anthropic computer use: `https://platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool`
- Claude Code MCP: `https://code.claude.com/docs/en/mcp`
- Anthropic API MCP connector: `https://platform.claude.com/docs/en/agents-and-tools/mcp-connector`
- Microsoft trademark guidelines: `https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks`
- Microsoft trademark list PDF includes `Clippy` and `Clippy Design`:
  `https://cdn-dynmedia-1.microsoft.com/is/content/microsoftcorp/microsoft/mscle/documents/presentations/TrademarksListFY25Q3.pdf`
- Animator vs. Animation Clippit reference:
  `https://animatorvsanimation.fandom.com/wiki/Clippit`
