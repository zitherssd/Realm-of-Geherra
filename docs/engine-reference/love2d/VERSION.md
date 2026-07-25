# LÖVE (Love2D) — Version Reference

| Field | Value |
|-------|-------|
| **Engine Version** | LÖVE 11.5 (Mysterious Mysteries) |
| **Release Date** | December 2023 (hotfixes through April 2024) |
| **Project Pinned** | 2026-07-25 |
| **Last Docs Verified** | 2026-07-25 |
| **LLM Knowledge Cutoff** | May 2025 |
| **Risk Level** | LOW — version is within LLM training data |

## Note

LÖVE 11.5 is within the LLM's training data. Engine reference docs are optional but can be added later if agents suggest incorrect APIs.

## LÖVE 11.5 Highlights (vs 11.4)

LÖVE 11.5 is a maintenance release focused on bug fixes and platform compatibility:
- Added "LÖVE Loader" launcher on Android for easier .love file loading
- Fixed vsync stuttering and frame drops on Windows (hotfix: 2024-04-08)
- Fixed macOS arm64 (Apple Silicon) — JIT compilation off by default
- Fixed crashes on macOS 11 and earlier (hotfix: 2024-03-03)
- Fixed Windows 7 compatibility (hotfix: 2023-12-09)
- Various audio, video, thread, and rendering fixes

**No breaking API changes from 11.4.** All code written for 11.4 is compatible with 11.5.

## Key LÖVE Callbacks

- `love.load()` — called once when the game starts
- `love.update(dt)` — called every frame with delta time
- `love.draw()` — called every frame for rendering
- `love.keypressed(key, scancode, isrepeat)`
- `love.keyreleased(key, scancode)`
- `love.mousepressed(x, y, button, istouch, presses)`
- `love.mousereleased(x, y, button, istouch, presses)`

## Key Modules

- `love.graphics` — drawing (images, shapes, text, canvases, shaders)
- `love.audio` — sound and music playback
- `love.filesystem` — file I/O and save data
- `love.keyboard` — keyboard input
- `love.mouse` — mouse input
- `love.math` — random numbers, noise, transforms
- `love.window` — window management
- `love.timer` — timing and delta time

## Official Resources

- Wiki: https://love2d.org/wiki/Main_Page
- Forums: https://love2d.org/forums/
- GitHub: https://github.com/love2d/love
- 11.5 Changelog: https://love2d.org/wiki/11.5
