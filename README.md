# clawd

![clawd](hero.png)

a pixel art crab that lives on your mac, watches your screen, and chats with you.

## features

- pixel art crab walks along your dock icons
- tap to pet -- emotions escalate the more you tap (happy, love, surprised, scared, angry, dead)
- click to chat via Claude CLI
- `Cmd+Shift+Space` to open chat from anywhere
- proactive screen comments with emoji emotions (configurable interval)
- tamagotchi-style animations: bounce, shake, tremble, squash, pixel art effects
- works in fullscreen spaces
- auto-updates via Sparkle

## requirements

- macOS 13+
- [Claude CLI](https://docs.anthropic.com/en/docs/claude-cli) installed and authenticated
- Clawd defaults to Claude `sonnet`; override with `CLAWD_CLAUDE_MODEL=opus` or another Claude model alias/name if needed

## install

Download the DMG from [releases](https://github.com/getcompanion-ai/pet-clawd/releases), or build from source:

```
git clone https://github.com/getcompanion-ai/pet-clawd.git
cd pet-clawd
swift build
.build/debug/Clawd
```

To build a release .app and DMG:

```
./scripts/build-app.sh
```

## permissions

- **Accessibility** -- required for the `Cmd+Shift+Space` hotkey
- **Screen Recording** -- optional, enables proactive screen comments. granted on first launch or via menu bar toggle.

## privacy

Everything runs locally. No data is collected or sent anywhere. Screen captures are compressed, sent to Claude CLI for context, and immediately deleted. The Claude CLI handles its own API communication.

## license

MIT
