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
                log.warn('BlackHole not found. Please install from: https://existential.audio/blackhole/');
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
        '-i', ':1',  // BlackHole 2ch device
        '-ar', String(SAMPLE_RATE),
        '-ac', String(CHANNELS),
        '-c:a', 'pcm_s16le',
        '-f', 's16le',
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
let bytesSent = 0;
let lastBytes = 0;
let lastCheck = Date.now();

function connect() {
    console.log(BANNER);
    log.info(`Connecting to Pi at ${PI_HOST}:${PI_PORT}...`);
    
    ws = new WebSocket(`ws://${PI_HOST}:${PI_PORT}`, {
        headers: {
            'X-Audio-Bridge': 'meet-bridge'
        }
    });

    ws.on('open', () => {
        log.ok(`Connected! Streaming audio to Pi...`);
        reconnectDelay = 1000;
        
        // Start audio capture
        audioProcess = startAudioCapture();
        
        // Pipe audio to WebSocket
        audioProcess.stdout.on('data', (chunk) => {
            if (ws.readyState === WebSocket.OPEN) {
                ws.send(Buffer.from(chunk));
                bytesSent += chunk.length;
            }
        });
        
        // Log stats every 10 seconds
        setInterval(() => {
            const now = Date.now();
            const elapsed = (now - lastCheck) / 1000;
            const speed = ((bytesSent - lastBytes) / 1024 / elapsed).toFixed(1);
            log.info(`Sent: ${(bytesSent / 1024 / 1024).toFixed(1)} MB | Speed: ${speed} KB/s`);
            lastBytes = bytesSent;
            lastCheck = now;
        }, 10000);
    });

    ws.on('close', () => {
        log.warn(`Disconnected. Reconnecting in ${reconnectDelay/1000}s...`);
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

    ws.on('message', (data) => {
        // Received audio from Pi - could add playback here
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
    log.info('Checking for BlackHole audio device...');
    const hasBlackHole = await checkAudioDevice();
    if (!hasBlackHole) {
        log.error('BlackHole not found! Please install: https://existential.audio/blackhole/');
        log.info('After installing, restart this script.');
        process.exit(1);
    }
    log.ok('BlackHole found!');
    connect();
})();