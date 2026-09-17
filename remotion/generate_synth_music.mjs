import fs from 'fs';
import path from 'path';

// Helper to write standard 16-bit PCM WAV file
function createWavBuffer(sampleRate, durationSec, generateSample) {
  const numChannels = 2;
  const bytesPerSample = 2;
  const numSamples = Math.floor(sampleRate * durationSec);
  const dataSize = numSamples * numChannels * bytesPerSample;
  const headerSize = 44;
  const buffer = Buffer.alloc(headerSize + dataSize);

  // RIFF header
  buffer.write('RIFF', 0);
  buffer.writeUInt32LE(36 + dataSize, 4);
  buffer.write('WAVE', 8);

  // fmt subchunk
  buffer.write('fmt ', 12);
  buffer.writeUInt32LE(16, 16); // subchunk1size (16 for PCM)
  buffer.writeUInt16LE(1, 20); // audio format (1 = PCM)
  buffer.writeUInt16LE(numChannels, 22);
  buffer.writeUInt32LE(sampleRate, 24);
  buffer.writeUInt32LE(sampleRate * numChannels * bytesPerSample, 28); // byte rate
  buffer.writeUInt16LE(numChannels * bytesPerSample, 32); // block align
  buffer.writeUInt16LE(16, 34); // bits per sample

  // data subchunk
  buffer.write('data', 36);
  buffer.writeUInt32LE(dataSize, 40);

  let offset = 44;
  for (let i = 0; i < numSamples; i++) {
    const t = i / sampleRate;
    const [left, right] = generateSample(t, i);
    
    // Clamp to -1.0 .. 1.0
    const l = Math.max(-1, Math.min(1, left));
    const r = Math.max(-1, Math.min(1, right));

    const valL = Math.floor(l < 0 ? l * 32768 : l * 32767);
    const valR = Math.floor(r < 0 ? r * 32768 : r * 32767);

    buffer.writeInt16LE(valL, offset);
    buffer.writeInt16LE(valR, offset + 2);
    offset += 4;
  }

  return buffer;
}

// Generate upbeat Anime Synthwave / Cyberpunk music track
function generateAnimeMusic(durationSec) {
  const sampleRate = 44100;
  const bpm = 126;
  const beatDuration = 60 / bpm;

  // Chord progression: Am - F - C - G (Anime/Otaku Anthem progression)
  // Am: A3(220), C4(261.63), E4(329.63)
  // F:  F3(174.61), A3(220), C4(261.63)
  // C:  C3(130.81), E3(164.81), G3(196.00)
  // G:  G3(196.00), B3(246.94), D4(293.66)
  const chordNotes = [
    [220, 261.63, 329.63, 440],
    [174.61, 220, 261.63, 349.23],
    [261.63, 329.63, 392.00, 523.25],
    [196.00, 246.94, 293.66, 392.00],
  ];

  const buffer = createWavBuffer(sampleRate, durationSec, (t) => {
    const currentBeat = t / beatDuration;
    const bar = Math.floor(currentBeat / 4);
    const chordIndex = bar % 4;
    const currentChord = chordNotes[chordIndex];

    // 1. Kick Drum (on beats 0, 1, 2, 3)
    const beatPos = currentBeat % 1;
    let kick = 0;
    if (beatPos < 0.25) {
      const kickFreq = 140 * Math.exp(-beatPos * 25);
      kick = Math.sin(2 * Math.PI * kickFreq * beatPos) * Math.exp(-beatPos * 14) * 0.7;
    }

    // 2. Hi-Hat (on offbeats 0.5)
    let hat = 0;
    const hatPos = (currentBeat + 0.5) % 1;
    if (hatPos < 0.12) {
      const noise = (Math.random() * 2 - 1);
      hat = noise * Math.exp(-hatPos * 40) * 0.25;
    }

    // 3. Synth Arpeggio (16th notes = 4 per beat)
    const subStep = Math.floor(currentBeat * 4) % 16;
    const arpNote = currentChord[subStep % currentChord.length] * 2; // 1 octave higher
    const stepPos = (currentBeat * 4) % 1;
    const arpEnv = Math.exp(-stepPos * 8);
    // Sawtooth-like synth with harmonics
    const arp = (
      Math.sin(2 * Math.PI * arpNote * t) * 0.5 +
      Math.sin(4 * Math.PI * arpNote * t) * 0.25 +
      Math.sin(6 * Math.PI * arpNote * t) * 0.15
    ) * arpEnv * 0.25;

    // 4. Warm Bassline
    const bassNote = currentChord[0] / 2;
    const bass = (
      Math.sin(2 * Math.PI * bassNote * t) * 0.6 +
      Math.sin(4 * Math.PI * bassNote * t) * 0.2
    ) * 0.35;

    // 5. Ambient Chords Pad
    const padEnv = 0.5 + 0.5 * Math.sin(t * 1.5);
    const pad = (
      Math.sin(2 * Math.PI * currentChord[0] * t) +
      Math.sin(2 * Math.PI * currentChord[1] * t) +
      Math.sin(2 * Math.PI * currentChord[2] * t)
    ) * 0.08 * padEnv;

    // Mixdown & Master Fade
    const fadeIn = Math.min(1, t / 1.5);
    const fadeOut = Math.min(1, (durationSec - t) / 2.0);
    const totalMix = (kick * 0.6 + hat * 0.4 + arp * 0.5 + bass * 0.5 + pad * 0.4) * fadeIn * fadeOut;

    // Stereo panning (arpeggio slight ping-pong, bass center)
    const panL = 0.5 + Math.sin(t * 4) * 0.2;
    const panR = 0.5 - Math.sin(t * 4) * 0.2;

    const left = totalMix * panL;
    const right = totalMix * panR;

    return [left, right];
  });

  return buffer;
}

const publicDir = path.resolve('public');
console.log('Generating 42s Synthwave background music track...');
const bgMusicLandscape = generateAnimeMusic(42);
fs.writeFileSync(path.join(publicDir, 'background_music.wav'), bgMusicLandscape);
console.log('Saved: public/background_music.wav');

console.log('Generating 30s Synthwave background music track for Shorts...');
const bgMusicShorts = generateAnimeMusic(30);
fs.writeFileSync(path.join(publicDir, 'background_music_shorts.wav'), bgMusicShorts);
console.log('Saved: public/background_music_shorts.wav');
