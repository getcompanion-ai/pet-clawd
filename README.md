# clawd

a pixel art crab that lives on your mac, watches your screen, and chats with you.

## features

- walks around the bottom of your screen
- sees what you're looking at via screen capture
- chats with you through Claude CLI (ctrl+space to open)
- makes random comments about what's on screen
- fully local -- just a native macOS app talking to Claude

## requirements

- macOS 13+
- [Claude CLI](https://docs.anthropic.com/en/docs/claude-cli) installed

## install

Download the DMG from [releases](https://github.com/getcompanion-ai/clawd/releases), or build from source:

```
swift build && .build/debug/Clawd
```

To build a release .app and DMG:

```
./scripts/build-app.sh
```

## privacy

Everything runs locally on your machine. No data is collected or sent anywhere except to the Claude CLI, which handles its own authentication and API communication.

## license

MIT
