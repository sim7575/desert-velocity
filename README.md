# Desert Velocity

Desert Velocity is a 3D arcade desert racing game built with Godot and GDScript for OpenAI Build Week 2026.

## Play the game

- Windows build: https://sim75.itch.io/desert-velocity
- Gameplay video: https://youtu.be/Qqn7Mt-HrE8

## OpenAI Build Week — use of Codex and GPT-5.6

Codex was used as the main repository-level development assistant throughout the project. It helped inspect and modify the Godot codebase, implement and refine gameplay systems, debug scripts and scene-loading issues, develop checkpoint, timer, HUD and difficulty logic, organize multi-stage development work, run validation passes, review changes and reduce regressions.

GPT-5.6 was used for technical planning, structured prompting, architecture and implementation decisions, debugging support, documentation, iterative review and evaluation of alternative solutions.

The AI-assisted workflow was supervised by the creator: generated changes were reviewed, tested, corrected and validated before being included in the final Windows build.

## Project story

I work full-time in real estate in Rome and developed Desert Velocity during evenings, weekends and the limited free time available alongside my professional work. The project began as a personal challenge to explore how far a non-professional game developer could go by combining a clear creative vision with Codex and GPT-5.6.

## Main features

- 3D desert racing gameplay
- Endurance mode and timed Special Stage
- Six checkpoints and race progression
- Multiple difficulty levels
- Two playable vehicles
- Vehicle physics, boost, damage and recovery systems
- Dynamic desert environments, canyon sections, obstacles and collectibles
- Custom HUD, timing and scoring systems
- Optimized 3D assets, materials, LODs and MultiMesh environment elements
- Windows build

## Built with

- Godot 4
- GDScript
- Codex
- GPT-5.6
- OpenAI
- Blender

## Run the source project

1. Install Godot 4.3 or later.
2. Clone or download this repository.
3. Open `project.godot` in the Godot Project Manager.
4. Run the main project scene.

## Controls

- W / Up Arrow: accelerate
- S / Down Arrow: brake and reverse
- A-D / Arrow Keys: steer
- Space: handbrake
- C: change camera distance/view
- Esc: pause
- Enter: confirm in menus
- R: recover to the last safe point with a penalty

## Repository structure

- `assets/`: game assets and shaders
- `audio/`: audio resources
- `data/`: vehicle statistics and balancing
- `materials/`: Godot materials
- `models/`: 3D model resources
- `scenes/`: Godot scenes
- `scripts/`: gameplay, systems and tools
- `source_art/`: editable Blender source files
- `tests/`: validation and regression tests
- `ui/`: interface resources
- `reports/`: performance and validation reports
- `screenshots/`: development and gameplay captures

## Windows build

The ready-to-play Windows build is distributed through itch.io rather than stored in this repository.

## Originality and licenses

The project uses original game logic, original procedural/3D assets and original materials created for Desert Velocity. No external credentials are required to run the downloadable build.
