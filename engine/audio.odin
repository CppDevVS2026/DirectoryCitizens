package engine

/*
	audio.odin
	==========
	E7 — Reactive audio system.

	Sound design:
	  Spawn   — short ascending chirp (440 → 880 Hz, 0.15s) — arrival
	  Death   — slow descending tone  (220 → 110 Hz, 0.4s)  — loss
	  Move    — neutral blip (550 Hz, 0.08s)                 — movement
	  Rename  — two-tone chime (440 + 660 Hz, 0.2s)          — identity shift
	  Unrest  — low rumble pulse (80 Hz, 0.3s)               — political tension
	  Revolt  — harsh buzz (150 Hz, modulated, 0.5s)         — exile

	Ambient:
	  startup_glitch        — one-shot on launch (assets/sfx/startup_glitch.wav)
	  ambience_server_room  — constant background loop, low volume
	  ambience_server_wide  — second loop, volume rises with stress (layered texture)
	  stress drone          — procedural 55 Hz sub-bass, also stress-driven

	Architecture:
	  AudioState lives inside GameState.
	  init_audio()       → call once at startup (after InitAudioDevice)
	  shutdown_audio()   → call at shutdown
	  play_event_sound() → called from push_event to queue a sound
	  update_audio()     → call each frame to service streams and update volumes
*/

import rl "vendor:raylib"
import "core:math"

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

AudioState :: struct {
	ready:        bool,           // false if InitAudioDevice failed
	sfx_spawn:    rl.Sound,
	sfx_death:    rl.Sound,
	sfx_move:     rl.Sound,
	sfx_rename:   rl.Sound,
	sfx_unrest:   rl.Sound,
	sfx_revolt:   rl.Sound,
	sfx_startup:  rl.Sound,      // one-shot boot glitch
	amb_room:     rl.Music,      // server room loop (constant low-volume bed)
	amb_wide:     rl.Music,      // wider server room loop (fades in with stress)
	drone:        rl.AudioStream, // procedural 55 Hz stress drone
	drone_active: bool,
}

// ---------------------------------------------------------------------------
// Initialization
// ---------------------------------------------------------------------------

/*
	init_audio — generates all sounds and starts the drone stream.
	Must be called AFTER rl.InitAudioDevice() in main.
*/
init_audio :: proc(a: ^AudioState) {
	if !rl.IsAudioDeviceReady() { return }
	a.ready = true

	a.sfx_spawn  = gen_chirp(440, 880, 0.15, 0.6)
	a.sfx_death  = gen_chirp(220, 110, 0.40, 0.5)
	a.sfx_move   = gen_tone(550, 0.08, 0.3)
	a.sfx_rename = gen_chime(440, 660, 0.20, 0.4)
	a.sfx_unrest = gen_tone(80,  0.30, 0.35)
	a.sfx_revolt = gen_buzz(150, 0.50, 0.5)

	// Drone stream: 44100 Hz, 32-bit float, mono.
	a.drone = rl.LoadAudioStream(44100, 32, 1)
	rl.SetAudioStreamVolume(a.drone, 0)
	rl.PlayAudioStream(a.drone)
	a.drone_active = true
}

/*
	shutdown_audio — unloads all sounds and stops the drone.
*/
shutdown_audio :: proc(a: ^AudioState) {
	if !a.ready { return }
	rl.StopAudioStream(a.drone)
	rl.UnloadAudioStream(a.drone)
	rl.UnloadSound(a.sfx_spawn)
	rl.UnloadSound(a.sfx_death)
	rl.UnloadSound(a.sfx_move)
	rl.UnloadSound(a.sfx_rename)
	rl.UnloadSound(a.sfx_unrest)
	rl.UnloadSound(a.sfx_revolt)
}

// ---------------------------------------------------------------------------
// Per-frame update
// ---------------------------------------------------------------------------

/*
	update_audio — feeds the drone stream and adjusts its volume.

	AudioStream requires data to be pushed every frame or the audio device
	callback reads uninitialized memory. We push a chunk of silence each frame
	and scale the volume by stress_level so the drone rises as citizens suffer.

	stress_level: 0.0 (everyone fine) → 1.0 (everyone in danger).
*/
DRONE_CHUNK :: 1024 // frames per update — small enough to avoid lag

update_audio :: proc(a: ^AudioState, stress_level: f32) {
	if !a.ready { return }

	target_vol := stress_level * 0.35
	rl.SetAudioStreamVolume(a.drone, target_vol)

	// Only push data when the stream has consumed the previous chunk.
	if rl.IsAudioStreamProcessed(a.drone) {
		// Generate a sine wave at 55 Hz (sub-bass) for the drone.
		// We use a static phase so the wave is continuous across frames.
		@static phase: f32
		buf: [DRONE_CHUNK]f32
		freq :: f32(55)
		for i in 0..<DRONE_CHUNK {
			buf[i] = math.sin_f32(phase)
			phase  += 2 * math.PI * freq / f32(SAMPLE_RATE)
			if phase > 2 * math.PI { phase -= 2 * math.PI }
		}
		rl.UpdateAudioStream(a.drone, raw_data(buf[:]), DRONE_CHUNK)
	}
}

// ---------------------------------------------------------------------------
// Event sound dispatch
// ---------------------------------------------------------------------------

/*
	play_event_sound — plays the sound matching an EventKind.
	Called by push_event so every game event has an audio cue.
*/
play_event_sound :: proc(a: ^AudioState, kind: EventKind) {
	if !a.ready { return }
	switch kind {
	case .Spawn:  rl.PlaySound(a.sfx_spawn)
	case .Death:  rl.PlaySound(a.sfx_death)
	case .Move:   rl.PlaySound(a.sfx_move)
	case .Rename: rl.PlaySound(a.sfx_rename)
	case .Info:   // silent — avoid sound fatigue on frequent info events
	}
}

/*
	play_unrest_sound, play_revolt_sound — for political events that don't
	map to an EventKind directly.
*/
play_unrest_sound :: proc(a: ^AudioState) {
	if !a.ready { return }
	rl.PlaySound(a.sfx_unrest)
}

play_revolt_sound :: proc(a: ^AudioState) {
	if !a.ready { return }
	rl.PlaySound(a.sfx_revolt)
}

// ---------------------------------------------------------------------------
// Sound synthesis helpers (private)
// ---------------------------------------------------------------------------

// Sample rate used for all generated sounds.
@(private) SAMPLE_RATE :: u32(44100)

/*
	gen_tone — generates a pure sine wave at `freq` Hz for `duration` seconds.
	volume: 0–1.
*/
@(private)
gen_tone :: proc(freq: f32, duration: f32, volume: f32) -> rl.Sound {
	n  := int(f32(SAMPLE_RATE) * duration)
	buf := make([]f32, n, context.temp_allocator)
	for i in 0..<n {
		t := f32(i) / f32(SAMPLE_RATE)
		env := envelope(f32(i), f32(n))
		buf[i] = volume * env * math.sin_f32(2 * math.PI * freq * t)
	}
	return load_sound_from_f32(buf)
}

/*
	gen_chirp — frequency sweeps linearly from freq_start to freq_end.
*/
@(private)
gen_chirp :: proc(freq_start, freq_end: f32, duration: f32, volume: f32) -> rl.Sound {
	n   := int(f32(SAMPLE_RATE) * duration)
	buf := make([]f32, n, context.temp_allocator)
	phase := f32(0)
	for i in 0..<n {
		t    := f32(i) / f32(n)
		freq := freq_start + (freq_end - freq_start) * t
		env  := envelope(f32(i), f32(n))
		buf[i] = volume * env * math.sin_f32(phase)
		phase  += 2 * math.PI * freq / f32(SAMPLE_RATE)
	}
	return load_sound_from_f32(buf)
}

/*
	gen_chime — mixes two tones at different frequencies (interval = chime character).
*/
@(private)
gen_chime :: proc(freq_a, freq_b: f32, duration: f32, volume: f32) -> rl.Sound {
	n   := int(f32(SAMPLE_RATE) * duration)
	buf := make([]f32, n, context.temp_allocator)
	for i in 0..<n {
		t   := f32(i) / f32(SAMPLE_RATE)
		env := envelope(f32(i), f32(n))
		a   := math.sin_f32(2 * math.PI * freq_a * t)
		b   := math.sin_f32(2 * math.PI * freq_b * t)
		buf[i] = volume * env * (a + b) * 0.5
	}
	return load_sound_from_f32(buf)
}

/*
	gen_buzz — frequency-modulated tone: carrier modulated by a sub-oscillator.
	Produces a harsh, distressed quality suitable for revolt events.
*/
@(private)
gen_buzz :: proc(carrier_freq: f32, duration: f32, volume: f32) -> rl.Sound {
	n   := int(f32(SAMPLE_RATE) * duration)
	buf := make([]f32, n, context.temp_allocator)
	mod_freq := carrier_freq * 1.5
	for i in 0..<n {
		t   := f32(i) / f32(SAMPLE_RATE)
		env := envelope(f32(i), f32(n))
		mod := 0.5 + 0.5 * math.sin_f32(2 * math.PI * mod_freq * t)
		sig := math.sin_f32(2 * math.PI * carrier_freq * mod * t)
		// Soft-clip to prevent harsh digital crunch.
		// Soft-clip via tanh approximation: tanh(x) ≈ x/(1+|x|) for speed.
		softclip :: #force_inline proc(x: f32) -> f32 { return x / (1 + abs(x)) }
		sig = softclip(sig * 2.0)
		buf[i] = volume * env * sig
	}
	return load_sound_from_f32(buf)
}

/*
	envelope — attack/release amplitude curve.
	Ramps in over the first 10% of the sound, ramps out over the last 20%.
	Prevents clicks at the start and end of sounds.
*/
@(private)
envelope :: proc(i, n: f32) -> f32 {
	attack  := n * 0.10
	release := n * 0.20
	if i < attack  { return i / attack }
	if i > n - release { return (n - i) / release }
	return 1.0
}

/*
	load_sound_from_f32 — wraps a []f32 PCM buffer into a Raylib Sound.

	Raylib's Wave struct lets us pass raw sample data:
	  frame_count  = number of frames (one f32 per frame for mono)
	  sample_rate  = 44100
	  sample_size  = 32 (bits per sample, f32)
	  channels     = 1 (mono)
	  data         = pointer to the float buffer
*/
@(private)
load_sound_from_f32 :: proc(buf: []f32) -> rl.Sound {
	wave := rl.Wave{
		frameCount = u32(len(buf)),
		sampleRate = SAMPLE_RATE,
		sampleSize = 32,
		channels   = 1,
		data       = raw_data(buf),
	}
	return rl.LoadSoundFromWave(wave)
}
