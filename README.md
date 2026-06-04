<p align="center">
  <img src="assets/icon.png" width="120" alt="app icon">
</p>

# Rubik's Cube — Interactive 3D Simulator & CFOP Auto-Solver

An interactive 3D Rubik's Cube built from scratch in **Processing 4 (Java / P3D OpenGL)**, with a
**from-scratch CFOP solver** that solves any scramble and animates the solution move-by-move.

## Demo

<p align="center">
  <a href="https://youtu.be/p14M3V3xtMY">
    <img src="assets/thumbnail.jpg" width="720" alt="Watch the Rubik's Cube demo on YouTube">
  </a>
</p>

▶ **[Watch the demo on YouTube](https://youtu.be/p14M3V3xtMY)**

## Highlights

- **Real-time 3D cube** — 27 chamfered cubies with per-face lighting, beveled edges, and
  z-fight-free stickers, rendered in P3D (OpenGL).
- **Natural controls** — grab any face and drag to turn it (ray-cast picking + axis-locked
  slice dragging), spin the whole cube to look around, or drive it from the keyboard.
- **From-scratch CFOP auto-solver** — Cross → F2L → OLL → PLL, no external libraries.
  Solve the whole thing automatically, or **step through it one move at a time**.
- **Runs off the UI thread** — the solver computes on a background worker so the interface
  never freezes; the solution is streamed into the animation queue when ready.
- **Polished UX** — scramble, timer with persisted best time, move counter, undo (animated,
  reaches back through scrambles and solves), light/dark themes that follow the OS, and
  cross-platform fonts/labels (macOS · Windows · Linux).

## The solver (what I'm most proud of)

A complete **CFOP** ("Fridrich method") pipeline implemented over the cube's sticker model:

| Stage | Approach |
| --- | --- |
| **Cross** | Breadth-first search keyed on *only the four cross edges*, so the state space collapses to ~190k and it returns an optimal cross instantly. |
| **F2L** | Each corner–edge pair is inserted with **cross-preserving triggers** (`R U R'`, etc.); the search is keyed on just the cross + solved pairs, keeping it bounded and correct. |
| **OLL / PLL** | Two small **last-layer searches** over complete algorithm sets (edge/corner orientation; 3-cycles + adjacent swap + AUF), bounded by the last-layer coset. |

The whole pipeline was **validated against thousands of random scrambles** (a standalone Java
port of the cube + solver) before shipping — **0 failures over 1500 scrambles**. A hidden
`t` key re-runs that self-check live from the console.

### A debugging story worth telling

While building the solver I discovered the **cube model itself was subtly wrong**: it passed
casual play but failed the classic identity `(R U R' U')⁶ = solved`. Property-style testing
(checking cubie groupings across thousands of scrambles, then move-order identities) isolated a
**corner-cycling bug** that was invisible to edges and centers — a reversed strip in two of the
turn functions. Fixing it made the model a mathematically valid cube and the solver correct.

## Controls

| Action | Input |
| --- | --- |
| Turn a face | Drag a face on the cube, or keys `u d r l f b` (hold **Shift** for prime / counter-clockwise) |
| Spin the view | **⌘**/**Ctrl** + drag, right-drag, or arrow keys |
| Scramble | **Space** / Scramble button |
| Auto-solve (toggles to Pause) | **s** / Solve button |
| Solve one move at a time | **n** / Step button |
| Undo (animated) | Undo button |
| Reset | **Enter** / Reset button |
| Toggle theme | Light/Dark button (remembered) |
| Solver self-check (console) | **t** |

## Architecture

The sketch is split into focused tabs:

| File | Responsibility |
| --- | --- |
| `Cube.pde` | Logical cube: six `char[3][3]` faces + the 18 face turns |
| `Solver.pde` | CFOP solver (cube-reader, cross/F2L/OLL/PLL search, simplifier) |
| `Moves.pde` | Single move/animation pipeline — one queue feeding scramble, solve, step, and undo; threaded solve |
| `Input.pde` | Raw mouse/keyboard → intent |
| `Raycast.pde` | Ray-cast face picking, slice locking, grid bookkeeping |
| `Renderer.pde` | 3D geometry, sticker rendering, slice animation |
| `Panel.pde` | Side panel UI (timer, buttons, move grid) |
| `Theme.pde` | Color palettes + OS dark-mode detection |
| `Persistence.pde` | Best time + theme saved to `~/.rubikscube_prefs.json` |
| `RubiksCube.pde` | Globals, setup, draw loop |
| `Cubelet.pde` | Per-cubie grid position + orientation |
| `Debug.pde` | Background solver self-check |

## Running it

**Download:** grab the build for your OS from the [latest release](../../releases/latest), unzip, and
double-click. The apps bundle their own Java runtime — nothing else to install.
*(macOS: if Gatekeeper blocks it the first time, right-click → Open.)*

**From source:** open the folder in [Processing 4](https://processing.org/) and press Run (P3D / OpenGL).

**Build the app yourself:** a tiny preprocessor lets the sketch build with plain `javac` + `jpackage`
— no Processing IDE needed (Processing's core libraries are vendored in `packaging/lib/`):

```bash
bash packaging/build-app.sh      # → dist/ : a double-clickable app for your current OS
```

The [`Build apps`](.github/workflows/release.yml) GitHub Actions workflow runs this on macOS, Windows
and Linux runners and attaches all three apps to the release when you push a `v*` tag.

## Tech

Processing 4 · Java · P3D (OpenGL via JOGL) · no third-party solver/cube libraries.

---

*Built as a personal project to explore 3D graphics, interaction design, and the algorithmics of
the CFOP method — including writing (and property-testing) a correct cube model and solver from
first principles.*
