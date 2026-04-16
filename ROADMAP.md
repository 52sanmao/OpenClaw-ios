# OpenClaw iOS Roadmap

## v0.1 (Current) -- Scaffold
- [x] WebSocket gateway client (protocol v3)
- [x] Chat with streaming + markdown + code blocks
- [x] Sessions list with titles/previews
- [x] Cron job list with toggle/trigger
- [x] Nodes (connected devices via presence)
- [x] Connect screen (host/port/token)
- [x] Keychain token storage
- [x] Dark mode, haptics

## v0.2 -- Core Completeness
- [ ] **Bonjour Gateway Discovery** -- Auto-discover `_openclaw-gw._tcp` on LAN (NWBrowser)
- [ ] **Chat History** -- Load previous messages via `chat.history` when opening a session
- [ ] **Session Detail View** -- Tap session to view transcript, patch settings, reset/delete
- [ ] **Session Usage** -- Show token counts + cost via `sessions.usage`
- [ ] **Agent Selection** -- Pick which agent to talk to (main, iris, etc.) via `agent.identity`
- [ ] **Exec Approvals** -- Listen for `exec.approval.requested` events and surface them safely on mobile once IronClaw exposes a supported resolve path
- [ ] **Health Dashboard** -- Call `health` + `status` and show gateway health card
- [ ] **Channels Status** -- Show Telegram/WhatsApp/Discord connection status via `channels.status`
- [ ] **Image/File Attachments** -- Send photos from camera roll via the agent message
- [ ] **Cron Job Editor** -- Create new cron jobs with schedule picker + payload builder

## v0.3 -- Node Mode (Phone as a Node)
- [ ] **Dual Role** -- Connect as both `operator` AND `node` simultaneously
- [ ] **Camera Node** -- Expose phone camera via `camera.snap` / `camera.clip` commands
- [ ] **Location Node** -- Expose phone GPS via `location.get` with permission controls
- [ ] **Canvas/A2UI** -- Render WKWebView canvas for agent-driven UI
- [ ] **Talk Mode** -- Voice conversation loop (listen -> transcribe -> agent -> TTS playback)
- [ ] **Voice Wake** -- "Hey OpenClaw" wake word detection
- [ ] **Node Pairing** -- Full `node.pair.request` flow with approval handling

## v0.4 -- Polish & Power Features
- [ ] **Push Notifications** -- APNs for agent messages, reminders, exec approvals
- [ ] **QR Code Pairing** -- Scan QR from gateway CLI/web to auto-fill connection config
- [ ] **Tailscale Integration** -- Auto-detect tailnet gateway via MagicDNS hints
- [ ] **Config Editor** -- View/edit gateway config via `config.get`/`config.patch`
- [ ] **Widgets** -- iOS home screen widgets (last message, health status, quick chat)
- [ ] **Shortcuts Integration** -- Siri Shortcuts for "Ask OpenClaw..." actions
- [ ] **Background Refresh** -- Periodic health checks + notification delivery
- [ ] **Multi-Gateway** -- Save multiple gateway profiles, switch between them
- [ ] **Biometric Lock** -- Face ID / Touch ID to protect the app

## v0.5 -- Distribution
- [ ] **TestFlight** -- Beta distribution
- [ ] **App Store** -- Public release
- [ ] **App Icon** -- Custom designed icon
- [ ] **Onboarding Flow** -- First-launch walkthrough
- [ ] **iPad Layout** -- Split view optimized for iPad

## Architecture Notes

### Protocol Methods Used
| Feature | Methods |
|---------|---------|
| Chat | `agent`, `agent.wait`, `agent.identity` |
| Sessions | `sessions.list`, `sessions.resolve`, `sessions.patch`, `sessions.delete`, `sessions.usage` |
| History | `chat.history` |
| Cron | `cron.list`, `cron.add`, `cron.update`, `cron.remove`, `cron.run`, `cron.runs` |
| Nodes | `system-presence`, `node.list`, `node.describe`, `node.invoke`, `node.rename` |
| Pairing | `node.pair.request`, `node.pair.list`, `node.pair.approve`, `node.pair.reject` |
| System | `connect`, `ping`, `status`, `health`, `channels.status` |
| Config | `config.get`, `config.patch`, `config.schema` |
| Approvals | `exec.approval.requested` (read-only until IronClaw resolve support exists) |
| Messaging | `send`, `poll` |
| Wake | `wake` |

### Events Listened
- `agent.stream` -- Streaming chat responses
- `agent.done` -- Agent run completed
- `exec.approval.requested` -- Approval needed
- `node.pair.requested` -- New pairing request
- `node.pair.resolved` -- Pairing approved/rejected
- `tick` -- Keepalive

### HTTP Endpoints (Alternative)
- `POST /v1/responses` -- IronClaw Responses API
- `POST /tools/invoke` -- Direct tool invocation without agent
- `GET /v1/models` -- IronClaw model discovery
