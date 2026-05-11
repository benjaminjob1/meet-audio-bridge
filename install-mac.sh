#!/bin/bash
# meet-audio-bridge installer for macOS
# Run this on your MacBook

set -e

echo "🎙️ Google Meet Audio Bridge Installer"
echo "======================================"
echo ""

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install ffmpeg with BlackHole support
echo "Installing ffmpeg..."
brew install ffmpeg

# Create the audio bridge script
BRIDGE_DIR="$HOME/meet-audio-bridge"
mkdir -p "$BRIDGE_DIR"

# Get Pi address from user if not set
PI_ADDRESS="${PI_ADDRESS:-$1}"
if [ -z "$PI_ADDRESS" ]; then
    read -p "Enter your Pi's Tailscale address (e.g. 100.x.x.x): " PI_ADDRESS
fi

# Create the Node.js bridge script
cat > "$BRIDGE_DIR/bridge.js" << 'SCRIPT'
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
                log.warn('BlackHole not found. Please install from: https://existential.audio/blackhole/');
                resolve(false);
            }
        });
    });
}

// Start ffmpeg to capture BlackHole audio
function startAudioCapture() {
    log.info('Starting audio capture from BlackHole 2ch...');
    
    const ffmpeg = spawn('ffmpeg', [
        '-f', 'avfoundation',
        '-i', ':1',  // BlackHole 2ch device
        '-ar', String(SAMPLE_RATE),
        '-ac', String(CHANNELS),
        '-c:a', 'pcm_s16le',
        '-f', 's16le',
        '-acodec', 'pcm_s16le',
        'pipe:1'
    ]);

    ffmpeg.stderr.on('data', (data) => {
        // Suppress ffmpeg verbose output
    });

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

function connect() {
    log.info(`Connecting to Pi at ${PI_HOST}:${PI_PORT}...`);
    
    ws = new WebSocket(`ws://${PI_HOST}:${PI_PORT}`, {
        headers: {
            'X-Audio-Bridge': 'meet-bridge'
        }
    });

    ws.on('open', () => {
        log.ok('Connected to Pi!');
        reconnectDelay = 1000;
        
        // Start audio capture
        audioProcess = startAudioCapture();
        
        // Pipe audio to WebSocket
        audioProcess.stdout.on('data', (chunk) => {
            if (ws.readyState === WebSocket.OPEN) {
                ws.send(Buffer.from(chunk));
            }
        });
    });

    ws.on('message', (data) => {
        // Received audio from Pi - would play here if needed
        // For now just acknowledge
    });

    ws.on('close', () => {
        log.warn('Disconnected from Pi. Reconnecting in ' + (reconnectDelay/1000) + 's...');
        if (audioProcess) {
            audioProcess.kill();
            audioProcess = null;
        }
        setTimeout(connect, reconnectDelay);
        reconnectDelay = Math.min(reconnectDelay * 2, 30000);
    });

    ws.on('error', (err) => {
        log.warn(`Connection error: ${err.message}`);
    });
}

// Graceful shutdown
process.on('SIGINT', () => {
    log.info('Shutting down...');
    if (audioProcess) audioProcess.kill();
    if (ws) ws.close();
    process.exit(0);
});

// Main
(async () => {
    const hasBlackHole = await checkAudioDevice();
    if (!hasBlackHole) {
        log.error('Please install BlackHole and run this script again.');
        process.exit(1);
    }
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
npm install 2>/dev/null || npm install

echo ""
echo "======================================"
echo "✅ Installation complete!"
echo ""
echo "To run the bridge:"
echo "  cd ~/meet-audio-bridge"
echo "  PI_HOST=<your-pi-address> node bridge.js"
echo ""
echo "Example:"
echo "  PI_HOST=100.x.x.x node bridge.js"
echo ""
echo "Get your Pi's Tailscale address with: tailscale ip -4"
echo ""
echo "After running, set Chrome's audio input/output to BlackHole 2ch"
echo "Then join your Google Meet on the Mac!"
echo "======================================"