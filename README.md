# 🎙️ Meet Audio Bridge

Lightweight audio bridge that lets your MacBook forward Google Meet audio to your Raspberry Pi over WebSocket. No OpenClaw needed on the Mac!

## ⚡ Quick Install (One Line)

```bash
curl -fsSL https://raw.githubusercontent.com/benjaminjob1/meet-audio-bridge/main/install.sh | bash
```

## 📥 Download Pre-Built

Go to [Releases](https://github.com/benjaminjob1/meet-audio-bridge/releases) and download for your platform:
- **macOS**: `meet-audio-bridge-macos` (just double-click to run!)
- **Linux**: `meet-audio-bridge-linux.tar.gz`
- **Windows**: Coming soon

## 🔧 Setup

### On your Pi (once):
1. Make sure Node.js is installed: `node --version`
2. Run: `cd ~/meet-audio-bridge && npm install && node server.js`

### On your Mac:

1. **Install BlackHole** (free): https://existential.audio/blackhole/
   - Restart Mac after installation

2. **Get your Pi's Tailscale IP**:
   ```bash
   tailscale ip -4
   ```
   Note it down (looks like `100.x.x.x`)

3. **Run the bridge**:
   ```bash
   # With pre-built binary:
   ./meet-audio-bridge-macos <pi-ip>
   
   # Or with Node.js:
   PI_HOST=<pi-ip> node bridge.js
   ```

4. **Set up Chrome audio**:
   - System Settings → Sound → Output → **BlackHole 2ch**
   - System Settings → Sound → Input → **BlackHole 2ch**
   - Join Google Meet — audio flows to Pi!

## 🌐 Access the Voice Site

Once server is running on Pi, access from your Tailscale network:
- **Tailscale URL**: `https://bens.dinosaur-char.ts.net:3456`
- Has 3 tabs: **Agent** (Realtime-2), **Translate** (Realtime-Translate), **Transcribe** (Whisper)

## 🔧 Troubleshooting

**"BlackHole not found"**
- Install from https://existential.audio/blackhole/
- Restart your Mac after installation

**Can't connect to Pi**
- Check Pi's Tailscale IP: `tailscale ip -4` on Pi
- Make sure server is running: `node server.js` on Pi
- Check port 9876 is open on Pi

**No audio in Meet**
- In Chrome, verify BlackHole is selected as input AND output
- Test in Meet settings that mic works with BlackHole

## 📱 For Developers

### Build from source
```bash
git clone https://github.com/benjaminjob1/meet-audio-bridge.git
cd meet-audio-bridge
npm install
```

### Run
```bash
PI_HOST=100.x.x.x node bridge.js
```

### Create standalone binary (requires pkg)
```bash
npm install -g pkg
pkg bridge.js --targets node18-macos-x64 --output meet-audio-bridge
```

## 🔄 Auto-Update Releases

GitHub Actions automatically builds releases when you create a tag:
```bash
git tag v1.0.0
git push origin v1.0.0
```

Find releases at: https://github.com/benjaminjob1/meet-audio-bridge/releases

## 📋 How It Works

```
MacBook Chrome (Google Meet)
    ↓ [BlackHole 2ch virtual audio]
    ↓ [ffmpeg captures audio]
    ↓ [Node.js WebSocket client]
    →→→ INTERNET →→→ (Tailscale/port 9876)
    ↓ [Pi WebSocket server]
    ↓ [OpenClaw BenBot processes]
    ↓ [TTS response sent back]
    ←←← INTERNET ←←←
```

Audio is captured from BlackHole (24kHz stereo PCM), streamed to Pi, processed by BenBot, and response audio returns through the same channel.

## ⚙️ Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PI_HOST` | localhost | Pi's Tailscale IP address |
| `PI_PORT` | 9876 | Server port on Pi |

## License

MIT