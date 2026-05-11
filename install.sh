#!/bin/bash
# meet-audio-bridge installer for macOS
# Run this on your MacBook (one-liner: curl -fsSL ... | bash)

set -e

BANNER="
╔═══════════════════════════════════════════╗
║   🎙️  Meet Audio Bridge Installer         ║
╚═══════════════════════════════════════════╝
"

echo "$BANNER"

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    echo "[INFO] Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install Node.js if needed
if ! command -v node &> /dev/null; then
    echo "[INFO] Installing Node.js..."
    brew install node
fi

# Install ffmpeg with BlackHole support
echo "[INFO] Installing ffmpeg..."
brew install ffmpeg

# Create the audio bridge directory
BRIDGE_DIR="$HOME/meet-audio-bridge"
mkdir -p "$BRIDGE_DIR"

# Get Pi address from user if not set
PI_ADDRESS="${PI_ADDRESS:-$1}"
if [ -z "$PI_ADDRESS" ]; then
    echo ""
    echo "Enter your Pi's Tailscale IP address (e.g. 100.x.x.x)"
    echo "To find it, run 'tailscale ip -4' on your Pi"
    read -p "Pi Tailscale IP: " PI_ADDRESS
fi

# Create the Node.js bridge script
cat > "$BRIDGE_DIR/bridge.js" << 'SCRIPT'
#!/usr/bin/env node
/**
 * meet-audio-bridge - Lightweight audio bridge for Google Meet
 * Runs on MacBook, sends audio to Pi over WebSocket
 */

const WebSocket = require('ws');
const { spawn } = require('child_process');

// Configuration
const PI_HOST = process.env.PI_HOST || process.argv[2] || 'localhost';
const PI_PORT = process.env.PI_PORT || 9876;
const SAMPLE_RATE = 24000;
const CHANNELS = 2;

// Colors for output
const log = {
    info: (msg) => console.log(`\x1b[36m[INFO]\x1b[0m ${msg}`),
    ok: (msg) => console.log(`\x1b[32m[OK]\x1b[0m ${msg}`),
    warn: (msg) => console.log(`\x1b[33m[WARN]\x1b[0m ${msg}`),
    error: (msg) => console.log(`\x1b[31m[ERROR]\x1b[0m ${msg}`)
};

const BANNER = `
╔═══════════════════════════════════════════╗
║   🎙️  Google Meet Audio Bridge v1.0      ║
║   MacBook → Pi Audio Forwarder            ║
╚═══════════════════════════════════════════╝
`;

// Check for BlackHole device
function checkAudioDevice() {
    return new Promise((resolve) => {
        const ffmpeg = spawn('ffmpeg', ['-f', 'avfoundation', '-list_devices', 'true', '-i', '']);
        let output = '';
        ffmpeg.stderr.on('data', (data) => { output += data.toString(); });
        ffmpeg.on('close', () => {
            if (output.includes('BlackHole')) {
                resolve(true);
            } else {
                resolve(false);
            }
        });
    });
}

// Start ffmpeg to capture BlackHole audio
function startAudioCapture() {
    log.info(`Capturing audio from BlackHole 2ch (${SAMPLE_RATE}Hz, ${CHANNELS}ch)...`);
    
    const ffmpeg = spawn('ffmpeg', [
        '-f', 'avfoundation',
        '-i', ':1',
        '-ar', String(SAMPLE_RATE),
        '-ac', String(CHANNELS),
        '-c:a', 'pcm_s16le',
        '-f', 's16le',
        'pipe:1'
    ]);

    ffmpeg.on('error', (err) => {
        log.error(`FFmpeg error: ${err.message}`);
        process.exit(1);
    });

    return ffmpeg;
}

// Connect to Pi WebSocket server
let ws;
let audioProcess;
let reconnectDelay = 1000;
let bytesSent = 0;

function connect() {
    console.log(BANNER);
    log.info(`Connecting to Pi at ${PI_HOST}:${PI_PORT}...`);
    
    ws = new WebSocket(`ws://${PI_HOST}:${PI_PORT}`, {
        headers: { 'X-Audio-Bridge': 'meet-bridge' }
    });

    ws.on('open', () => {
        log.ok(`Connected! Streaming audio to Pi...`);
        reconnectDelay = 1000;
        audioProcess = startAudioCapture();
        
        audioProcess.stdout.on('data', (chunk) => {
            if (ws.readyState === WebSocket.OPEN) {
                ws.send(Buffer.from(chunk));
                bytesSent += chunk.length;
            }
        });
    });

    ws.on('close', () => {
        log.warn(`Disconnected. Reconnecting in ${reconnectDelay/1000}s...`);
        if (audioProcess) audioProcess.kill();
        setTimeout(connect, reconnectDelay);
        reconnectDelay = Math.min(reconnectDelay * 2, 30000);
    });

    ws.on('error', (err) => {
        log.warn(`Connection error: ${err.message}`);
    });
}

process.on('SIGINT', () => {
    log.info('Shutting down...');
    if (audioProcess) audioProcess.kill();
    if (ws) ws.close();
    process.exit(0);
});

(async () => {
    log.info('Checking for BlackHole audio device...');
    const hasBlackHole = await checkAudioDevice();
    if (!hasBlackHole) {
        log.error('BlackHole not found!');
        log.info('Please install from: https://existential.audio/blackhole/');
        log.info('After installing, run this script again.');
        process.exit(1);
    }
    log.ok('BlackHole found!');
    connect();
})();
SCRIPT

# Create package.json
cat > "$BRIDGE_DIR/package.json" << 'EOF'
{
  "name": "meet-audio-bridge",
  "version": "1.0.0",
  "description": "Lightweight audio bridge for Google Meet on Mac",
  "main": "bridge.js",
  "scripts": {
    "start": "node bridge.js"
  },
  "dependencies": {
    "ws": "^8.16.0"
  }
}
EOF

# Install dependencies
cd "$BRIDGE_DIR"
npm install

echo ""
echo "═══════════════════════════════════════════"
echo "✅ Installation complete!"
echo ""
echo "Next steps:"
echo ""
echo "1. On your Pi, run the meet-audio-server:"
echo "   node server.js"
echo ""
echo "2. On this Mac, run the bridge:"
echo "   PI_HOST=$PI_ADDRESS node bridge.js"
echo ""
echo "3. In Chrome, set audio input/output to BlackHole 2ch"
echo ""
echo "4. Join Google Meet!"
echo "═══════════════════════════════════════════"
echo ""
echo "To auto-start with Pi IP, run:"
echo "  echo 'export PI_HOST=$PI_ADDRESS' >> ~/.zshrc"