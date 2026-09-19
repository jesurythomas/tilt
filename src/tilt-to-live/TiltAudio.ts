// =========================================================================
// TiltAudio.ts - Procedural Web Audio Sound Engine & Synthesizer
// =========================================================================

export class TiltAudio {
  private ctx: AudioContext | null = null;
  private masterGain: GainNode | null = null;
  private musicGain: GainNode | null = null;
  private sfxGain: GainNode | null = null;
  private muted: boolean = false;

  // Background Cyber Synthwave Engine (Lookahead Scheduler at 134 BPM)
  private isMusicPlaying: boolean = false;
  private currentStep: number = 0;
  private nextStepTime: number = 0;
  private scheduleTimer: number | null = null;
  private noiseBuffer: AudioBuffer | null = null;
  private readonly stepDuration: number = 60 / 134 / 4; // 134 BPM 16th note (~0.1119s)
  private readonly lookaheadMs: number = 25;
  private readonly scheduleAheadSec: number = 0.12;

  // Pentatonic scale frequencies for combo pops
  private readonly scale: number[] = [
    261.63, 293.66, 329.63, 392.00, 440.00, // C4 - A4
    523.25, 587.33, 659.25, 783.99, 880.00, // C5 - A5
    1046.50, 1174.66, 1318.51, 1567.98, 1760.00 // C6 - A6
  ];

  public unlock() {
    if (!this.ctx) {
      const AudioCtx = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
      this.ctx = new AudioCtx();

      this.masterGain = this.ctx.createGain();
      this.masterGain.gain.value = 0.28;
      this.masterGain.connect(this.ctx.destination);

      this.sfxGain = this.ctx.createGain();
      this.sfxGain.gain.value = 1.0;
      this.sfxGain.connect(this.masterGain);

      this.musicGain = this.ctx.createGain();
      this.musicGain.gain.value = 0.35;
      this.musicGain.connect(this.masterGain);
    }
    if (this.ctx.state === 'suspended') {
      void this.ctx.resume();
    }
  }

  public toggleMute(): boolean {
    this.muted = !this.muted;
    if (this.masterGain) {
      this.masterGain.gain.value = this.muted ? 0 : 0.28;
    }
    return !this.muted;
  }

  public setMuted(muted: boolean) {
    this.muted = muted;
    if (this.masterGain) {
      this.masterGain.gain.value = this.muted ? 0 : 0.28;
    }
  }

  public setSfxVolume(vol: number) {
    if (this.sfxGain) {
      this.sfxGain.gain.value = Math.max(0, Math.min(1, vol));
    }
  }

  public setMusicVolume(vol: number) {
    if (this.musicGain) {
      this.musicGain.gain.value = Math.max(0, Math.min(1, vol)) * 0.35;
    }
  }

  public isMuted(): boolean {
    return this.muted;
  }

  // --- Background Cyber Synthwave Soundtrack ---

  public startMusic() {
    this.unlock();
    if (this.isMusicPlaying) return;
    this.isMusicPlaying = true;
    this.currentStep = 0;
    this.nextStepTime = (this.ctx?.currentTime || 0) + 0.05;

    if (this.scheduleTimer !== null) {
      clearInterval(this.scheduleTimer);
    }
    this.scheduleTimer = window.setInterval(() => this.scheduler(), this.lookaheadMs);
  }

  public stopMusic() {
    this.isMusicPlaying = false;
    if (this.scheduleTimer !== null) {
      clearInterval(this.scheduleTimer);
      this.scheduleTimer = null;
    }
  }

  private scheduler() {
    if (!this.ctx || !this.isMusicPlaying || this.muted) return;
    while (this.nextStepTime < this.ctx.currentTime + this.scheduleAheadSec) {
      this.scheduleStep(this.currentStep, this.nextStepTime);
      this.nextStepTime += this.stepDuration;
      this.currentStep = (this.currentStep + 1) % 256; // 16 bars * 16 steps = 256 steps (~28.7s cycle)
    }
  }

  private getNoiseBuffer(): AudioBuffer {
    if (!this.noiseBuffer && this.ctx) {
      const bufferSize = Math.floor(this.ctx.sampleRate * 1.5);
      this.noiseBuffer = this.ctx.createBuffer(1, bufferSize, this.ctx.sampleRate);
      const data = this.noiseBuffer.getChannelData(0);
      for (let i = 0; i < bufferSize; i++) {
        data[i] = Math.random() * 2 - 1;
      }
    }
    return this.noiseBuffer!;
  }

  private scheduleStep(step: number, time: number) {
    if (!this.ctx || !this.musicGain || this.muted) return;

    const bar = Math.floor(step / 16); // 0 to 15
    const stepInBar = step % 16;
    const chordIndex = bar % 4; // 0: Dm, 1: Bb, 2: C, 3: A

    // 1. Drum Layer (Punchy Electro Kit)
    this.scheduleDrums(bar, stepInBar, time);

    // 2. Rolling Synth Bassline (16th-note Saw Bass with resonant cutoff sweep)
    this.scheduleBassLine(bar, stepInBar, chordIndex, time);

    // 3. Neon Vector Arpeggio (Lush 16th-note plucks)
    this.scheduleArpeggio(bar, stepInBar, chordIndex, time);

    // 4. Soaring Synth Lead Melody (Enters on Bar 4, evolves through Bar 11)
    if (bar >= 4 && bar < 12) {
      this.scheduleLeadMelody(bar, stepInBar, time);
    }

    // 5. Breakdown Pad / Swell (Bars 12-15 tension before drop)
    if (bar >= 12 && stepInBar === 0) {
      const padFreqs = bar === 15 ? [220, 277.18, 329.63] : [146.83, 220, 293.66];
      for (const f of padFreqs) {
        this.schedulePadChord(time, f, this.stepDuration * 16);
      }
    }
  }

  private scheduleDrums(bar: number, stepInBar: number, time: number) {
    const isBreakdown = bar >= 12 && bar < 15;

    // Crash Cymbal on section transitions
    if ((bar === 0 || bar === 4 || bar === 8 || bar === 12) && stepInBar === 0) {
      this.triggerCrash(time);
    }

    if (!isBreakdown) {
      // Kick: Four-on-the-floor + syncopated push on step 10
      if (stepInBar === 0 || stepInBar === 4 || stepInBar === 8 || stepInBar === 12 || stepInBar === 10) {
        this.triggerKick(time, stepInBar === 0 || stepInBar === 8);
      }

      // Snare: Backbeat on 4 and 12, plus turnaround fills on bar 3, 7, 11
      const isFillBar = (bar % 4 === 3);
      if (stepInBar === 4 || stepInBar === 12) {
        this.triggerSnare(time, false);
      } else if (isFillBar && (stepInBar === 13 || stepInBar === 14 || stepInBar === 15)) {
        this.triggerSnare(time, true);
      }

      // Hi-Hats: 16th-note groove with sizzling open hats on off-beats (2, 6, 10, 14)
      const isOpen = (stepInBar === 2 || stepInBar === 6 || stepInBar === 10 || stepInBar === 14);
      this.triggerHiHat(time, isOpen);
    } else {
      // Breakdown Drum Build: Snare roll building into drop!
      if (bar === 14) {
        if (stepInBar % 2 === 0) this.triggerSnare(time, true);
      } else if (bar === 15) {
        // High-tension 16th-note snare roll with rising intensity
        this.triggerSnare(time, false);
        if (stepInBar % 4 === 0) this.triggerKick(time, true);
      }
    }
  }

  private triggerKick(time: number, isAccent: boolean) {
    if (!this.ctx || !this.musicGain) return;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();

    osc.frequency.setValueAtTime(isAccent ? 145 : 125, time);
    osc.frequency.exponentialRampToValueAtTime(36, time + 0.085);

    gain.gain.setValueAtTime(isAccent ? 0.38 : 0.28, time);
    gain.gain.exponentialRampToValueAtTime(0.001, time + 0.095);

    osc.connect(gain);
    gain.connect(this.musicGain);
    osc.start(time);
    osc.stop(time + 0.1);
  }

  private triggerSnare(time: number, isRoll: boolean) {
    if (!this.ctx || !this.musicGain) return;

    // Snare tonal body
    const bodyOsc = this.ctx.createOscillator();
    const bodyGain = this.ctx.createGain();
    bodyOsc.type = 'triangle';
    bodyOsc.frequency.setValueAtTime(210, time);
    bodyOsc.frequency.exponentialRampToValueAtTime(80, time + 0.07);

    bodyGain.gain.setValueAtTime(isRoll ? 0.10 : 0.18, time);
    bodyGain.gain.exponentialRampToValueAtTime(0.001, time + 0.08);

    bodyOsc.connect(bodyGain);
    bodyGain.connect(this.musicGain);
    bodyOsc.start(time);
    bodyOsc.stop(time + 0.085);

    // Gated noise snap
    const buffer = this.getNoiseBuffer();
    const noise = this.ctx.createBufferSource();
    noise.buffer = buffer;

    const filter = this.ctx.createBiquadFilter();
    filter.type = 'bandpass';
    filter.frequency.setValueAtTime(1750, time);
    filter.Q.value = 1.6;

    const noiseGain = this.ctx.createGain();
    noiseGain.gain.setValueAtTime(isRoll ? 0.12 : 0.24, time);
    noiseGain.gain.exponentialRampToValueAtTime(0.001, time + (isRoll ? 0.08 : 0.13));

    noise.connect(filter);
    filter.connect(noiseGain);
    noiseGain.connect(this.musicGain);

    noise.start(time);
    noise.stop(time + 0.14);
  }

  private triggerHiHat(time: number, isOpen: boolean) {
    if (!this.ctx || !this.musicGain) return;
    const buffer = this.getNoiseBuffer();
    const noise = this.ctx.createBufferSource();
    noise.buffer = buffer;

    const filter = this.ctx.createBiquadFilter();
    filter.type = 'highpass';
    filter.frequency.setValueAtTime(7500, time);

    const gain = this.ctx.createGain();
    gain.gain.setValueAtTime(isOpen ? 0.08 : 0.038, time);
    gain.gain.exponentialRampToValueAtTime(0.001, time + (isOpen ? 0.11 : 0.032));

    noise.connect(filter);
    filter.connect(gain);
    gain.connect(this.musicGain);

    noise.start(time);
    noise.stop(time + (isOpen ? 0.12 : 0.035));
  }

  private triggerCrash(time: number) {
    if (!this.ctx || !this.musicGain) return;
    const buffer = this.getNoiseBuffer();
    const noise = this.ctx.createBufferSource();
    noise.buffer = buffer;

    const filter = this.ctx.createBiquadFilter();
    filter.type = 'bandpass';
    filter.frequency.setValueAtTime(3200, time);
    filter.Q.value = 0.9;

    const gain = this.ctx.createGain();
    gain.gain.setValueAtTime(0.32, time);
    gain.gain.exponentialRampToValueAtTime(0.001, time + 0.75);

    noise.connect(filter);
    filter.connect(gain);
    gain.connect(this.musicGain);

    noise.start(time);
    noise.stop(time + 0.8);
  }

  private scheduleBassLine(bar: number, stepInBar: number, chordIndex: number, time: number) {
    if (!this.ctx || !this.musicGain) return;
    if (bar >= 12 && bar < 14) return; // Silent during initial breakdown

    // Chord Root Frequencies
    // 0: Dm (D2 = 73.42, D3 = 146.83)
    // 1: Bb (Bb1 = 58.27, Bb2 = 116.54)
    // 2: C  (C2 = 65.41, C3 = 130.81)
    // 3: A  (A1 = 55.00, A2 = 110.00)
    const rootFreqs = [73.42, 58.27, 65.41, 55.00];
    const root = rootFreqs[chordIndex];
    const octave = root * 2;

    // Rolling 16th-note synthwave bass groove:
    // Root, Root, Octave, Root, Root, Octave, Root, Octave...
    const isOctave = (stepInBar === 2 || stepInBar === 5 || stepInBar === 10 || stepInBar === 13);
    const isTurnaround = (chordIndex === 3 && (stepInBar === 14 || stepInBar === 15));
    const freq = isTurnaround ? (stepInBar === 14 ? 69.30 : 82.41) : (isOctave ? octave : root);

    const osc = this.ctx.createOscillator();
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(freq, time);

    // Resonant lowpass filter envelope
    const filter = this.ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.Q.value = 4.2;
    filter.frequency.setValueAtTime(isOctave ? 1150 : 750, time);
    filter.frequency.exponentialRampToValueAtTime(170, time + 0.085);

    const gain = this.ctx.createGain();
    const vol = (stepInBar === 0 || stepInBar === 8) ? 0.16 : 0.12;
    gain.gain.setValueAtTime(vol, time);
    gain.gain.exponentialRampToValueAtTime(0.001, time + 0.095);

    osc.connect(filter);
    filter.connect(gain);
    gain.connect(this.musicGain);

    osc.start(time);
    osc.stop(time + 0.10);
  }

  private scheduleArpeggio(bar: number, stepInBar: number, chordIndex: number, time: number) {
    if (!this.ctx || !this.musicGain) return;

    // 16th-note arpeggio notes for each chord
    const arpTables = [
      // Dm
      [293.66, 349.23, 440.00, 587.33, 440.00, 349.23, 293.66, 220.00, 293.66, 349.23, 440.00, 587.33, 698.46, 587.33, 440.00, 349.23],
      // Bb
      [233.08, 293.66, 349.23, 466.16, 349.23, 293.66, 233.08, 174.61, 233.08, 293.66, 349.23, 466.16, 587.33, 466.16, 349.23, 293.66],
      // C
      [261.63, 329.63, 392.00, 523.25, 392.00, 329.63, 261.63, 196.00, 261.63, 329.63, 392.00, 523.25, 659.25, 523.25, 392.00, 329.63],
      // A
      [220.00, 277.18, 329.63, 440.00, 392.00, 329.63, 277.18, 220.00, 220.00, 277.18, 329.63, 392.00, 440.00, 554.37, 659.25, 880.00]
    ];

    const noteFreq = arpTables[chordIndex][stepInBar];

    const osc = this.ctx.createOscillator();
    osc.type = 'square';
    osc.frequency.setValueAtTime(noteFreq, time);

    const filter = this.ctx.createBiquadFilter();
    filter.type = 'bandpass';
    const filterFreq = (bar >= 12) ? 1800 + (stepInBar * 60) : 1400;
    filter.frequency.setValueAtTime(filterFreq, time);
    filter.Q.value = 1.6;

    const gain = this.ctx.createGain();
    gain.gain.setValueAtTime(0.065, time);
    gain.gain.exponentialRampToValueAtTime(0.001, time + 0.08);

    osc.connect(filter);
    filter.connect(gain);
    gain.connect(this.musicGain);

    osc.start(time);
    osc.stop(time + 0.085);
  }

  private scheduleLeadMelody(bar: number, stepInBar: number, time: number) {
    if (!this.ctx || !this.musicGain) return;

    // Lead notes defined per (bar, stepInBar)
    let note: { freq: number; dur: number } | null = null;

    // Phrase 1 Lead (Bars 4 - 7)
    if (bar === 4) {
      if (stepInBar === 0) note = { freq: 587.33, dur: 0.38 }; // D5
      else if (stepInBar === 4) note = { freq: 698.46, dur: 0.18 }; // F5
      else if (stepInBar === 8) note = { freq: 659.25, dur: 0.18 }; // E5
      else if (stepInBar === 12) note = { freq: 587.33, dur: 0.35 }; // D5
    } else if (bar === 5) {
      if (stepInBar === 0) note = { freq: 587.33, dur: 0.35 }; // D5
      else if (stepInBar === 4) note = { freq: 466.16, dur: 0.18 }; // Bb4
      else if (stepInBar === 8) note = { freq: 523.25, dur: 0.18 }; // C5
      else if (stepInBar === 12) note = { freq: 587.33, dur: 0.35 }; // D5
    } else if (bar === 6) {
      if (stepInBar === 0) note = { freq: 659.25, dur: 0.35 }; // E5
      else if (stepInBar === 4) note = { freq: 783.99, dur: 0.18 }; // G5
      else if (stepInBar === 8) note = { freq: 698.46, dur: 0.18 }; // F5
      else if (stepInBar === 12) note = { freq: 659.25, dur: 0.35 }; // E5
    } else if (bar === 7) {
      if (stepInBar === 0) note = { freq: 880.00, dur: 0.45 }; // A5
      else if (stepInBar === 6) note = { freq: 783.99, dur: 0.18 }; // G5
      else if (stepInBar === 10) note = { freq: 659.25, dur: 0.18 }; // E5
      else if (stepInBar === 13) note = { freq: 554.37, dur: 0.32 }; // C#5
    }
    // Phrase 2 High Climax Lead (Bars 8 - 11)
    else if (bar === 8) {
      if (stepInBar === 0) note = { freq: 880.00, dur: 0.35 }; // A5
      else if (stepInBar === 4) note = { freq: 1046.50, dur: 0.18 }; // C6
      else if (stepInBar === 8) note = { freq: 880.00, dur: 0.18 }; // A5
      else if (stepInBar === 12) note = { freq: 698.46, dur: 0.35 }; // F5
    } else if (bar === 9) {
      if (stepInBar === 0) note = { freq: 783.99, dur: 0.35 }; // G5
      else if (stepInBar === 4) note = { freq: 932.33, dur: 0.18 }; // Bb5
      else if (stepInBar === 8) note = { freq: 880.00, dur: 0.18 }; // A5
      else if (stepInBar === 12) note = { freq: 698.46, dur: 0.35 }; // F5
    } else if (bar === 10) {
      if (stepInBar === 0) note = { freq: 783.99, dur: 0.35 }; // G5
      else if (stepInBar === 4) note = { freq: 659.25, dur: 0.18 }; // E5
      else if (stepInBar === 8) note = { freq: 783.99, dur: 0.18 }; // G5
      else if (stepInBar === 12) note = { freq: 1046.50, dur: 0.35 }; // C6
    } else if (bar === 11) {
      if (stepInBar === 0) note = { freq: 1174.66, dur: 0.45 }; // D6
      else if (stepInBar === 6) note = { freq: 1108.73, dur: 0.22 }; // C#6
      else if (stepInBar === 10) note = { freq: 880.00, dur: 0.22 }; // A5
      else if (stepInBar === 13) note = { freq: 659.25, dur: 0.32 }; // E5
    }

    if (!note) return;

    // Dual detuned saw oscillators for wide, fat synth lead
    const osc1 = this.ctx.createOscillator();
    const osc2 = this.ctx.createOscillator();
    osc1.type = 'sawtooth';
    osc2.type = 'sawtooth';
    osc1.frequency.setValueAtTime(note.freq, time);
    osc2.frequency.setValueAtTime(note.freq * 1.004, time); // Detuned chorus sheen

    const filter = this.ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.setValueAtTime(2800, time);

    const gain = this.ctx.createGain();
    gain.gain.setValueAtTime(0.001, time);
    gain.gain.linearRampToValueAtTime(0.12, time + 0.02);
    gain.gain.exponentialRampToValueAtTime(0.001, time + note.dur);

    osc1.connect(filter);
    osc2.connect(filter);
    filter.connect(gain);
    gain.connect(this.musicGain);

    osc1.start(time);
    osc2.start(time);
    osc1.stop(time + note.dur + 0.02);
    osc2.stop(time + note.dur + 0.02);
  }

  private schedulePadChord(time: number, freq: number, duration: number) {
    if (!this.ctx || !this.musicGain) return;
    const osc = this.ctx.createOscillator();
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(freq, time);

    const filter = this.ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.setValueAtTime(650, time);

    const gain = this.ctx.createGain();
    gain.gain.setValueAtTime(0.001, time);
    gain.gain.linearRampToValueAtTime(0.05, time + 0.3);
    gain.gain.exponentialRampToValueAtTime(0.001, time + duration);

    osc.connect(filter);
    filter.connect(gain);
    gain.connect(this.musicGain);

    osc.start(time);
    osc.stop(time + duration + 0.05);
  }

  // --- Sound Effects ---

  public playOrbPickup() {
    if (!this.ctx || !this.sfxGain || this.muted) return;
    const now = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();

    osc.type = 'sine';
    osc.frequency.setValueAtTime(440, now);
    osc.frequency.exponentialRampToValueAtTime(880, now + 0.12);

    gain.gain.setValueAtTime(0.25, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.13);

    osc.connect(gain);
    gain.connect(this.sfxGain);
    osc.start(now);
    osc.stop(now + 0.14);
  }

  public playNuke() {
    if (!this.ctx || !this.sfxGain || this.muted) return;
    const now = this.ctx.currentTime;

    // Deep sub-bass boom
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(140, now);
    osc.frequency.exponentialRampToValueAtTime(20, now + 0.6);

    gain.gain.setValueAtTime(0.6, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.65);

    osc.connect(gain);
    gain.connect(this.sfxGain);
    osc.start(now);
    osc.stop(now + 0.7);
  }

  public playMissileLaunch() {
    if (!this.ctx || !this.sfxGain || this.muted) return;
    const now = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();

    osc.type = 'triangle';
    osc.frequency.setValueAtTime(320, now);
    osc.frequency.exponentialRampToValueAtTime(1100, now + 0.15);

    gain.gain.setValueAtTime(0.18, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.16);

    osc.connect(gain);
    gain.connect(this.sfxGain);
    osc.start(now);
    osc.stop(now + 0.17);
  }

  public playMissileExplode() {
    if (!this.ctx || !this.sfxGain || this.muted) return;
    const now = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();

    osc.type = 'square';
    osc.frequency.setValueAtTime(180, now);
    osc.frequency.exponentialRampToValueAtTime(45, now + 0.12);

    gain.gain.setValueAtTime(0.22, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.13);

    osc.connect(gain);
    gain.connect(this.sfxGain);
    osc.start(now);
    osc.stop(now + 0.14);
  }

  public playLaserBeam() {
    if (!this.ctx || !this.sfxGain || this.muted) return;
    const now = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();

    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(800, now);
    osc.frequency.exponentialRampToValueAtTime(300, now + 0.22);

    gain.gain.setValueAtTime(0.24, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.23);

    osc.connect(gain);
    gain.connect(this.sfxGain);
    osc.start(now);
    osc.stop(now + 0.24);
  }

  public playLightning() {
    if (!this.ctx || !this.sfxGain || this.muted) return;
    const now = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();

    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(1200 + Math.random() * 400, now);
    osc.frequency.exponentialRampToValueAtTime(200, now + 0.08);

    gain.gain.setValueAtTime(0.22, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.09);

    osc.connect(gain);
    gain.connect(this.sfxGain);
    osc.start(now);
    osc.stop(now + 0.1);
  }

  public playFreeze() {
    if (!this.ctx || !this.sfxGain || this.muted) return;
    const now = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();

    osc.type = 'sine';
    osc.frequency.setValueAtTime(1400, now);
    osc.frequency.exponentialRampToValueAtTime(450, now + 0.25);

    gain.gain.setValueAtTime(0.2, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.26);

    osc.connect(gain);
    gain.connect(this.sfxGain);
    osc.start(now);
    osc.stop(now + 0.27);
  }

  public playIceShatter() {
    if (!this.ctx || !this.sfxGain || this.muted) return;
    const now = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();

    osc.type = 'triangle';
    osc.frequency.setValueAtTime(2200, now);
    osc.frequency.exponentialRampToValueAtTime(800, now + 0.08);

    gain.gain.setValueAtTime(0.18, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.09);

    osc.connect(gain);
    gain.connect(this.sfxGain);
    osc.start(now);
    osc.stop(now + 0.1);
  }

  public playSiren() {
    if (!this.ctx || !this.sfxGain || this.muted) return;
    const now = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();

    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(520, now);
    osc.frequency.linearRampToValueAtTime(880, now + 0.22);
    osc.frequency.linearRampToValueAtTime(520, now + 0.44);

    gain.gain.setValueAtTime(0.2, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.48);

    osc.connect(gain);
    gain.connect(this.sfxGain);
    osc.start(now);
    osc.stop(now + 0.5);
  }

  public playIceCascade() {
    if (!this.ctx || !this.sfxGain || this.muted) return;
    const now = this.ctx.currentTime;
    for (let i = 0; i < 3; i++) {
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();

      osc.type = 'sine';
      const freq = 1600 + i * 420;
      osc.frequency.setValueAtTime(freq, now + i * 0.04);
      osc.frequency.exponentialRampToValueAtTime(freq * 1.4, now + i * 0.04 + 0.1);

      gain.gain.setValueAtTime(0.16, now + i * 0.04);
      gain.gain.exponentialRampToValueAtTime(0.001, now + i * 0.04 + 0.12);

      osc.connect(gain);
      gain.connect(this.sfxGain);
      osc.start(now + i * 0.04);
      osc.stop(now + i * 0.04 + 0.13);
    }
  }

  public playGauntletKlaxon() {
    if (!this.ctx || !this.sfxGain || this.muted) return;
    const now = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();

    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(140, now);
    osc.frequency.setValueAtTime(170, now + 0.1);
    osc.frequency.exponentialRampToValueAtTime(70, now + 0.35);

    gain.gain.setValueAtTime(0.24, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.38);

    osc.connect(gain);
    gain.connect(this.sfxGain);
    osc.start(now);
    osc.stop(now + 0.4);
  }

  public playVortex() {
    if (!this.ctx || !this.sfxGain || this.muted) return;
    const now = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();

    osc.type = 'sine';
    osc.frequency.setValueAtTime(160, now);
    osc.frequency.exponentialRampToValueAtTime(50, now + 0.35);

    gain.gain.setValueAtTime(0.25, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.36);

    osc.connect(gain);
    gain.connect(this.sfxGain);
    osc.start(now);
    osc.stop(now + 0.37);
  }

  public playDotPop(comboIndex: number = 0) {
    if (!this.ctx || !this.sfxGain || this.muted) return;
    const now = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();

    const noteFreq = this.scale[comboIndex % this.scale.length];
    osc.type = 'sine';
    osc.frequency.setValueAtTime(noteFreq, now);

    gain.gain.setValueAtTime(0.12, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.06);

    osc.connect(gain);
    gain.connect(this.sfxGain);
    osc.start(now);
    osc.stop(now + 0.065);
  }

  public playMilestone() {
    if (!this.ctx || !this.sfxGain || this.muted) return;
    const now = this.ctx.currentTime;

    // Major chord triumphant burst (C - E - G)
    const notes = [523.25, 659.25, 783.99, 1046.50];
    notes.forEach((freq, idx) => {
      const osc = this.ctx!.createOscillator();
      const gain = this.ctx!.createGain();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(freq, now + idx * 0.04);
      gain.gain.setValueAtTime(0.15, now + idx * 0.04);
      gain.gain.exponentialRampToValueAtTime(0.001, now + idx * 0.04 + 0.22);
      osc.connect(gain);
      gain.connect(this.sfxGain!);
      osc.start(now + idx * 0.04);
      osc.stop(now + idx * 0.04 + 0.24);
    });
  }

  public playPlayerDeath() {
    if (!this.ctx || !this.sfxGain || this.muted) return;
    const now = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();

    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(260, now);
    osc.frequency.exponentialRampToValueAtTime(30, now + 0.5);

    gain.gain.setValueAtTime(0.45, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.55);

    osc.connect(gain);
    gain.connect(this.sfxGain);
    osc.start(now);
    osc.stop(now + 0.6);
  }

  public playCloseCall() {
    if (!this.ctx || !this.sfxGain || this.muted) return;
    const now = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();

    osc.type = 'sine';
    osc.frequency.setValueAtTime(880, now);
    osc.frequency.linearRampToValueAtTime(1320, now + 0.08);

    gain.gain.setValueAtTime(0.08, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.09);

    osc.connect(gain);
    gain.connect(this.sfxGain);
    osc.start(now);
    osc.stop(now + 0.1);
  }

  // --- Space Invader Intro Cinematic SFX ---
  public playSpaceInvaderStep(step: number) {
    if (!this.ctx || !this.sfxGain || this.muted) return;
    const now = this.ctx.currentTime;
    const notes = [175, 155, 139, 123]; // Classic 4-note descending march
    const freq = notes[step % notes.length];

    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'square';
    osc.frequency.setValueAtTime(freq, now);
    osc.frequency.exponentialRampToValueAtTime(freq * 0.7, now + 0.12);

    gain.gain.setValueAtTime(0.22, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.14);

    osc.connect(gain);
    gain.connect(this.sfxGain);
    osc.start(now);
    osc.stop(now + 0.15);
  }

  public playWarpIn() {
    if (!this.ctx || !this.sfxGain || this.muted) return;
    const now = this.ctx.currentTime;

    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(110, now);
    osc.frequency.exponentialRampToValueAtTime(880, now + 0.22);
    osc.frequency.exponentialRampToValueAtTime(220, now + 0.45);

    gain.gain.setValueAtTime(0.28, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.5);

    osc.connect(gain);
    gain.connect(this.sfxGain);
    osc.start(now);
    osc.stop(now + 0.52);
  }

  public playInvasionAlarm() {
    if (!this.ctx || !this.sfxGain || this.muted) return;
    const now = this.ctx.currentTime;

    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(740, now);
    osc.frequency.setValueAtTime(550, now + 0.08);
    osc.frequency.setValueAtTime(740, now + 0.16);

    gain.gain.setValueAtTime(0.2, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.25);

    osc.connect(gain);
    gain.connect(this.sfxGain);
    osc.start(now);
    osc.stop(now + 0.26);
  }
}
