# Rubik's Cube v1.0.0 — Interactive 3D Simulator & CFOP Auto-Solver

An interactive 3D Rubik's Cube built from scratch in Processing 4 (Java / P3D OpenGL), with a
from-scratch **CFOP auto-solver** that solves any scramble and animates the solution — automatically
or one step at a time.

## ✨ Features

- **3D cube** with chamfered cubies, per-face lighting, and drag-to-turn face control (ray-cast picking).
- **CFOP auto-solver** (Cross → F2L → OLL → PLL) — no external libraries. **Solve** plays the whole
  solution; **Step** walks it move-by-move; the two share one plan, so you can pause auto-play and
  take over at any point.
- **Solver runs on a background thread** — the UI never freezes while solving.
- **Scramble, animated undo** (reaches back through scrambles and solves), **timer with saved best
  time**, and a **move counter**.
- **Light/dark themes** that follow the OS and are remembered between sessions.
- **Cross-platform** — fonts and key hints adapt to macOS, Windows, and Linux.

## 🧠 Under the hood

- Cross solved by BFS keyed on just the four cross edges (optimal, instant).
- F2L inserted with cross-preserving triggers; last layer via bounded OLL/PLL algorithm searches.
- The cube model and solver were **property-tested against 1500+ random scrambles (0 failures)**,
  and a hidden `t` key re-runs that self-check live. Development also surfaced and fixed a subtle
  corner-cycling bug in the cube model, caught via the identity `(R U R' U')⁶ = solved`.

## ▶️ How to run

- **App:** download the build for your OS below, unzip, and double-click. *(macOS: if Gatekeeper
  blocks it, right-click → Open the first time.)*
- **From source:** open the folder in [Processing 4](https://processing.org/) and press Run.

## ⌨️ Controls

Drag a face to turn it · `u d r l f b` (Shift = prime) · **⌘/Ctrl** or right-drag to spin the view ·
**Space** scramble · **s** solve · **n** step · **Enter** reset.
