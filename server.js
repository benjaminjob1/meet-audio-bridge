#!/usr/bin/env node
/**
 * meet-audio-server - Server that runs on Pi, receives audio from MacBook bridge
 * Bridges audio to OpenClaw google-meet plugin
 */

const WebSocket = require('ws');
const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 9876;
const GOOGLE_MEET_PORT = process.env.GOOGLE_MEET_PORT || 18789;

// Colors
const log = {
    info: (msg) => console.log(`\x1b[36m[INFO]\x1b[0m ${msg}`),
    ok: (msg) => console.log(`\x1b[32m[OK]\x1b[0m ${msg}`),
    warn: (msg) => console.log(`\x1b[33m[WARN]\x1b[0m ${msg}`),
    error: (msg) => console.log(`\x1b[31m[ERROR]\x1b[0m ${msg}`)
};

const BANNER = `
╔═══════════════════════════════════════════╗
║   🎙️  Meet Audio Server v1.0               ║
║   Raspberry Pi → OpenClaw Bridge           ║
╚═══════════════════════════════════════════╝
`;

// Audio buffer for accumulating chunks
let audioBuffer = Buffer.alloc(0);
let meetSession = null;

// Connect to OpenClaw gateway for google-meet integration
function getMeetSessionUrl() {
    return `http://localhost:${GOOGLE_MEET_PORT}`;
}

// WebSocket server for MacBook audio bridge
const wss = new WebSocket.Server({ port: PORT }, () => {
    console.log(BANNER);
    log.ok(`Server listening on port ${PORT}`);
    log.info(`Waiting for MacBook audio bridge to connect...`);
});

wss.on('connection', (ws, req) => {
    log.ok('MacBook audio bridge connected!');
    
    ws.on('message', (data) => {
        // Accumulate audio chunks
        audioBuffer = Buffer.concat([audioBuffer, data]);
        
        // Process when we have enough audio (roughly 0.5 seconds of audio)
        // 24000Hz * 2ch * 2bytes/sample = 96000 bytes per second
        // So 48000 bytes ≈ 0.5 seconds
        if (audioBuffer.length >= 48000) {
            processAudio(Buffer.from(audioBuffer));
            audioBuffer = Buffer.alloc(0);
        }
    });

    ws.on('close', () => {
        log.warn('MacBook disconnected');
        audioBuffer = Buffer.alloc(0);
    });

    ws.on('error', (err) => {
        log.error(`WebSocket error: ${err.message}`);
    });
});

async function processAudio(audioChunk) {
    // This is where we'd integrate with OpenClaw's google-meet
    // For now, log the audio data
    // In full implementation, this would send to the meet session API
    
    // Placeholder for actual integration
    // The audio chunk is 24kHz stereo PCM (S16LE)
    
    // For testing, just log size
    // log.info(`Received ${audioChunk.length} bytes of audio`);
}

// HTTP endpoint for status
const server = http.createServer((req, res) => {
    if (req.url === '/status') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            status: 'running',
            connections: wss.clients.size,
            bufferSize: audioBuffer.length
        }));
    } else if (req.url === '/health') {
        res.writeHead(200);
        res.end('OK');
    } else {
        res.writeHead(404);
        res.end('Not found');
    }
});

server.listen(PORT + 1, () => {
    log.info(`HTTP status server on port ${PORT + 1}`);
});

// Graceful shutdown
process.on('SIGINT', () => {
    log.info('Shutting down server...');
    wss.close();
    server.close();
    process.exit(0);
});

log.info(`Audio format: 24kHz, stereo, 16-bit PCM`);
log.info(`Waiting for connection from MacBook...`);