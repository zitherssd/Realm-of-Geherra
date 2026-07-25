# Audio/Music System

> **Status**: Complete
> **Author**: Developer + AI agents
> **Last Updated**: 2026-07-25
> **Implements Pillar**: Foundation — supports all pillars

## Overview

The Audio/Music System manages all audio playback in the game: sound effects (SFX), background music (BGM), ambient environmental audio, and UI sounds. It wraps LÖVE's `love.audio` module into a simple event-driven interface that any system can call. Audio is organised into categories (Music, SFX, Ambient, UI) with independent volume control. Music tracks support crossfading for seamless transitions (e.g., world map ambient → combat music). Short SFX are loaded as static Sources for instant playback; long music tracks are streamed from disk to minimise memory usage.

## Player Fantasy

Audio is the game's invisible storyteller. The warm drone of bronze-age instrumentation on the world map evokes a world that is ancient and fading. The sharp crack of a bronze blade on stone armour in combat makes every hit feel weighty. The quiet chime of a gemstone interface click grounds the UI in the Antediluvian setting. The player should never consciously notice the audio system — only its absence when sound cuts out.

## Detailed Design

### Core Rules

1. **Audio categories**: All sounds belong to one of four categories — Music, SFX, Ambient, UI. Each category has its own volume multiplier (0.0–1.0), independent master control, and concurrent source limit.

2. **Event-driven playback**: Systems call `Audio.play(sound_id, category, options)` to trigger a sound. `sound_id` references a key in `data/audio_manifest.lua` which maps to the actual audio file path, format, and category.

3. **Source pooling**: SFX and UI sounds use a pool of pre-allocated static Sources. The pool size is configurable. If all sources in a category are in use and a new sound fires, the oldest/lowest-priority source is stolen.

4. **Music crossfading**: When a music transition is requested (e.g., world → combat), the current track fades out over a configurable duration while the new track fades in simultaneously. Only one music track plays at a time.

5. **Ambient layering**: Ambient sounds can layer (wind, birds, distant thunder). Up to 3 ambient sources can play simultaneously per biome definition. Ambients loop indefinitely.

6. **Volume hierarchy**: Global Master volume → Category volume → Per-source volume. Final volume = Master × Category × Source.

### States and Transitions

| State | Description | Entry | Exit |
|-------|-------------|-------|------|
| **Silent** | No audio playing. Game hasn't loaded audio yet. | Game starts | First `Audio.play()` call |
| **Active** | Normal playback. Music + SFX + Ambient all active. | First audio played | Mute all, or scene transition |
| **Music Crossfading** | One track fading out, another fading in. Only one music active. | `Audio.crossfade_music(new_track)` | Fade completes → new track at full volume |
| **Paused** | All audio suspended (e.g., game paused, window unfocused). | `Audio.pause_all()` | `Audio.resume_all()` |
| **Muted** | All categories silenced. Individual volumes preserved. | `Audio.set_master_volume(0)` | `Audio.set_master_volume(prior)` |

### Interactions with Other Systems

| System | Direction | Interface |
|--------|-----------|-----------|
| Main Menu System | Consumed by | `Audio.play("menu_select", "sfx")`, `Audio.play("menu_music", "music")` |
| Tactical Combat | Consumed by | `Audio.play("sword_hit", "sfx")`, `Audio.crossfade_music("combat_bgm")` |
| World Map Biome | Consumed by | `Audio.play_ambient(biome_ambient_id)` on biome entry |
| Dialogue System | Consumed by | `Audio.play("dialogue_advance", "ui")` |
| Scene Manager | Consumed by | `Audio.crossfade_music(scene_default_music)` on scene change |

## Formulas

No mathematical formulas. Audio playback is event-driven with volume multiplication:
- `final_volume = master_volume × category_volume × source_volume`
- All volumes are floats in range `[0.0, 1.0]`

## Edge Cases

- **If an audio file is missing**: `Audio.play()` logs a warning and returns silently. No crash — the game continues without that sound.
- **If the audio manifest is malformed**: The system falls back to hardcoded defaults and logs an error. All `play()` calls still work; sounds without entries fail silently.
- **If too many sounds fire simultaneously**: SFX pool exhaustion steals the oldest source. No crash — some sounds may cut off early.
- **If the window loses focus**: All audio pauses automatically via LÖVE's built-in behaviour. `Audio.resume_all()` on focus gain.
- **If music crossfade is interrupted by another crossfade**: The first fade is cancelled. New fade starts from the current blend position.
- **If the user has no audio device**: `love.audio` returns silent sources. No crash. The system detects this and sets all volumes to 0 silently.
- **At 800×600 resolution**: Audio is resolution-independent. No changes needed.

## Dependencies

| Dependency | Type | Interface |
|------------|------|-----------|
| LÖVE love.audio | Hard (engine) | `love.audio.newSource(path, type)`, `source:play()`, `source:stop()`, `source:setVolume()` |
| LÖVE love.filesystem | Hard (engine) | File loading for audio assets |

**Depended on by:** Main Menu System, Tactical Combat, World Map/Time System, Dialogue System, all UI systems.

## Tuning Knobs

- **Master volume**: Float `0.0–1.0`. Default: `1.0`. Saved to preferences.
- **Music volume**: Float `0.0–1.0`. Default: `0.7`.
- **SFX volume**: Float `0.0–1.0`. Default: `1.0`.
- **Ambient volume**: Float `0.0–1.0`. Default: `0.5`.
- **UI volume**: Float `0.0–1.0`. Default: `0.8`.
- **Crossfade duration**: Float seconds `0.5–4.0`. Default: `1.5`.
- **SFX pool size**: Integer `4–32`. Default: `8`. Number of simultaneous SFX sources.
- **Ambient layer count**: Integer `1–5`. Default: `3`. Maximum simultaneous ambient sources.

## Visual/Audio Requirements

- **No visual requirements.** This system is purely audio.
- **Audio asset manifest** (`data/audio_manifest.lua`): Maps sound IDs to file paths, categories, and playback options. All audio files stored in `assets/audio/`.
- **Music format**: OGG Vorbis (streaming). WAV for short SFX (static).
- **Estimate**: ~10–15 SFX files for MVP (menu clicks, sword hits, footsteps, UI sounds), ~3 music tracks (menu theme, world map ambient, basic combat BGM).

## UI Requirements

- **No direct UI.** Volume settings belong to a future Settings/Options screen. The Audio System provides the data interface (`get_volume(category)`, `set_volume(category, value)`) for that screen to consume.
- **No in-game audio mixer UI** for MVP — volume controls will use config file editing if needed.

## Acceptance Criteria

- **GIVEN** the game starts, **WHEN** `Audio.play("menu_music", "music")` is called, **THEN** the menu music plays and loops.
- **GIVEN** a sound ID that doesn't exist, **WHEN** `Audio.play("nonexistent", "sfx")` is called, **THEN** no crash occurs — a warning is logged.
- **GIVEN** master volume is set to 0, **WHEN** any sound is played, **THEN** no audio is heard.
- **GIVEN** music is playing, **WHEN** `Audio.crossfade_music("combat_bgm")` is called, **THEN** the current track fades out while the combat track fades in over the crossfade duration.
- **GIVEN** 10 SFX sounds fire simultaneously with a pool size of 8, **WHEN** the pool is exhausted, **THEN** the oldest source is stolen and no crash occurs.
- **GIVEN** the window loses focus, **WHEN** focus is regained, **THEN** audio resumes at the correct volume.

## Open Questions

- **Number of music tracks for MVP**: 3 proposed (menu, world map, combat). Confirm when world map and combat are designed.
- **Audio file creation**: Will sounds be sourced from free libraries (e.g., freesound.org) or commissioned? Decision deferred.
