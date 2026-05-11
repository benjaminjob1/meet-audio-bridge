# 🎙️ Meet Audio Bridge

Lightweight audio bridge that lets your MacBook forward Google Meet audio to your Raspberry Pi over WebSocket. No OpenClaw needed on the Mac!

## Requirements

1. **MacBook** with macOS
2. **BlackHole** virtual audio driver (free): https://existential.audio/blackhole/
3. **Node.js** (v16+)
4. **Raspberry Pi** running the meet-audio-server (see below)

## Quick Install (One Line)

```bash
curl -fsSL https://raw.githubusercontent.com/benjaminjob1/meet-audio-bridge/main/install.sh | bash
```

Or manually:

```bash
git clone https://github.com/benjaminjob1/meet-audio-bridge.git
cd meet-audio-bridge
npm install
```

## Get Your Pi's Tailscale Address

On your Pi:
```bash
tailscale ip -4
```

## Run the Bridge

```bash
PI_HOST=100.x.x.x node bridge.js
```

Replace `100.x.x.x` with your Pi's Tailscale IP.

## Setup Google Meet

1. Open Chrome
2. Go to **System Settings → Sound → Output**
3. Select **BlackHole 2ch**
4. **System Settings → Sound → Input** → select **BlackHole 2ch**
5. Join your Google Meet
6. Audio flows: Chrome → BlackHole → bridge → Pi → BenBot

## Troubleshooting

**"BlackHole not found"**
- Install BlackHole from https://existential.audio/blackhole/
- Restart your Mac after installation

**Can't connect to Pi**
- Check your Pi's Tailscale IP: `tailscale ip -4`
- Make sure the server is running on the Pi
- Check firewall/port 9876 is open

**No audio in Meet**
- In Chrome, check that BlackHole is selected as both input and output
- Test in Meet settings that your microphone works with BlackHole

## How It Works

```
MacBook Chrome (Meet) 
    ↓ [BlackHole]
    ↓ [ffmpeg capture]
    ↓ [Node.js WebSocket]
    →→→ INTERNET →→→
    ↓ [Raspberry Pi server]
    ↓ [OpenClaw BenBot]
    ↓ [TTS response]
    ←←← INTERNET ←←←
```

The bridge captures audio from BlackHole and streams it to the Pi in real-time. BenBot processes it and responds with voice.

## Pi Server Setup

On your Pi, you need to run the meet-audio-server:

```bash
cd ~/meet-audio-bridge
npm install
node server.js
```

The server listens on port 9876 and bridges audio to OpenClaw.

## License

MIT