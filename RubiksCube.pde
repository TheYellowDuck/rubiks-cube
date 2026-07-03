// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Required Notice: Copyright (c) 2026 George Zhang — https://github.com/TheYellowDuck

Cube cube;

PMatrix3D rotMatrix;
int   prevMX, prevMY, dragStartX, dragStartY;
boolean didDrag = false, pressInPanel = false, pressOnCube = false, didRotate = false, rotateKey = false, macCtrl = false, macCtrlDrag = false;
final boolean IS_MAC = System.getProperty("os.name").toLowerCase().contains("mac");
final int CMD = 157;
final String MOD_KEY = IS_MAC ? "⌘" : "Ctrl";   // rotate modifier label, shown in the UI hints

final int   PANEL_X = 558;
final int   CUBE_CX = 268, CUBE_CY = 308;
final float S   = 55;
final float HS  = S * 0.5;
final float GAP = 3;
final float SO  = 0.5;  // sticker offset — pushes quads off cube surface to kill z-fighting

int     moveCount    = 0;
long    startMs      = 0;
boolean timerRunning = false, solved = false;
long    solvedMs     = 0;
boolean assisted     = false;   // Solve/Step used since last scramble → don't count as a best time
ArrayList<String> history = new ArrayList<String>();

boolean darkMode = true;
color   BG, PNL, SURF, SURF2, BORD, T1, T2, T3, ACCENT, SUCCESS;

// ── Drag-to-slice state ───────────────────────────────────────────────────
PVector dragFaceNormal     = null;  // local-space outward normal of the clicked face
PVector dragClickedCubelet = null;  // grid coords of clicked cubelet (-1/0/1 per axis)
boolean dragOnFace         = false; // true when mousePressed landed on a visible face

PVector dragTangent1 = null;  // first local-space tangent axis on the clicked face
PVector dragTangent2 = null;  // second local-space tangent axis on the clicked face
PVector refVec1      = null;  // screen-space projection of dragTangent1 (normalized)
PVector refVec2      = null;  // screen-space projection of dragTangent2 (normalized)
PVector refVecSpin   = null;  // CW drag direction at the pressed corner; null if not a corner press
boolean canSpin      = false; // true only when the pressed cubie is a face corner (|faceCx|=|faceCy|=1)

int     chosenAxis   = -1;   // 0/1/2 once locked; -1 = intent not yet committed
boolean axisLocked   = false; // true once total drag exceeds DRAG_THRESHOLD
PVector rotationAxis = null;  // local-space unit vector to rotate around (set when locked)
final float DRAG_THRESHOLD = 18.0; // pixels of total drag before axis is committed
final float DRAG_TO_ANGLE = PI / (3.0 * S); // radians per pixel (90° per half-face-width)

int   sliceCoord = 0;   // grid index (-1/0/1) of the active slice
float sliceAngle = 0;   // live slice rotation in radians

boolean isDragging = false; // true while a slice is live-rotating (gate for the draw loop)
int     targetAxis = -1;    // 0=X, 1=Y, 2=Z — integer form of rotationAxis for switch/draw use

// Move kinds — what a queued/animating move is, so it can be applied correctly
// when its animation completes.  (Declared first: animKind below references these.)
final int K_NONE = 0, K_MANUAL = 1, K_SCRAMBLE = 2, K_SOLVE = 3, K_UNDO = 4;

// ── Move animation ────────────────────────────────────────────────────────────
// One move animates at a time.  animKind records how it should be applied when it
// finishes (see Moves.pde): manual/scramble/solve/undo.
boolean isAnimating     = false;
long    animStartMs     = 0;
int     animSnapSteps   = 0;
String  animMove        = null;
float   animSliceTarget = 0;
int     animDurationMs  = 150;
int     animKind        = K_NONE;
final   int ANIM_MS          = 150;
final   int SCRAMBLE_ANIM_MS = 90;
final   int SOLVE_ANIM_MS    = 130;

// ── Drag-release snap tween ─────────────────────────────────────────────────────
// After a face drag, the slice eases from where you let go to the nearest 90°,
// then commits the move (instead of snapping instantly). See updateDragSnap().
boolean snapping       = false;
long    snapStartMs    = 0;
float   snapFrom       = 0;   // slice angle at release
float   snapTo         = 0;   // nearest 90° target (raw, pre-sign)
float   snapApplyAngle = 0;   // signed angle committed to the cubelets
int     snapStepsV     = 0;   // 90° steps committed to the grid
String  snapMv         = null;// the move string to record (may be null)
boolean snapMiddle     = false;// true → middle slice: commit via commitMiddleTurnRaw()
boolean snapUndo       = false;// true → this snap is undoing a middle turn (rewind, don't record)
final   int SNAP_MS    = 80;

// ── Move queue (single pipeline) ────────────────────────────────────────────────
// Scramble, auto-solve, step-solve and undo all feed this one queue of quarter
// turns.  seqKind tags what the queue is; autoPlay = advance automatically (false
// = paused / single-stepping).
ArrayList<String> moveQueue = new ArrayList<String>();
int     seqKind  = K_NONE;
boolean autoPlay = false;

// ── Background solve ────────────────────────────────────────────────────────────
// solveCube() runs on a worker thread so the UI never freezes.  A generation id
// invalidates a result if the cube changed (scramble/reset/manual) before it lands.
volatile boolean planReady     = false;   // worker → main: a result is ready
volatile String  planResult    = null;
volatile int     planResultGen = -1;      // generation the ready result belongs to
volatile int     planGen       = 0;       // bumped on every request / cancel
boolean planComputing  = false;           // main-thread view: a solve is in flight
boolean planAutoIntent = false;           // when ready: true = auto-play, false = single step
Cube    planSnapshot   = null;
int     planRunId      = 0;

Cubelet[] cubelets = new Cubelet[27]; // all 27 cubelet objects, initialised in setup()

PFont   fontUI, fontMono;
PShape  cubeShape;

final float BEVEL = 2;  // chamfer radius in pixels

// ── Setup ────────────────────────────────────────────────────────────────

// Returns the first installed font from `candidates`, else a guaranteed logical
// font ("SansSerif" / "Monospaced") — so the UI looks right on macOS, Windows and
// Linux instead of silently falling back to a default.
PFont pickFont(String[] candidates, String generic, float size) {
  String[] available = PFont.list();
  for (String c : candidates)
    for (String a : available)
      if (a.equalsIgnoreCase(c)) return createFont(c, size, true);
  return createFont(generic, size, true);
}

void setup() {
  size(800, 640, P3D);
  smooth(4);
  // Cross-platform fonts: try OS-native faces, fall back to a guaranteed logical font.
  fontUI   = pickFont(new String[]{ "Helvetica Neue", "Segoe UI", "Helvetica", "Arial", "DejaVu Sans", "Roboto" }, "SansSerif", 13);
  fontMono = pickFont(new String[]{ "Menlo", "SF Mono", "Consolas", "DejaVu Sans Mono", "Roboto Mono", "Courier New" }, "Monospaced", 48);
  textFont(fontUI);
  darkMode = detectOSDarkMode();
  loadPrefs();          // overrides darkMode with the saved choice (if any) and loads bestMs
  setTheme();
  cubeShape = buildRoundedCube(S - 1, BEVEL);
  cube = new Cube();
  initCubelets();
  TRIG = triggers();   // pre-build solver tables so worker threads never race the lazy init
  rotMatrix = new PMatrix3D();
  rotMatrix.rotateX(-0.5);
  rotMatrix.rotateY(0.6);
}

// ── Draw ─────────────────────────────────────────────────────────────────

void draw() {
  updateAnimation();
  updateTheme();        // advance the dark/light colour fade, if one is running
  background(BG);

  // 3D scene — draw first so 2D overlays don't poison the depth buffer
  pushMatrix();
  translate(CUBE_CX, CUBE_CY, 0);
  applyMatrix(rotMatrix);
  if (darkMode) {
    ambientLight(100, 102, 118);
    directionalLight(240, 238, 252, -1, -1.5, -0.6);   // key: upper-left-front
    directionalLight( 80,  78, 100,  0.8, 1.2,  0.6);  // fill: lower-right-back
  } else {
    ambientLight(110, 112, 122);
    directionalLight(215, 212, 220, -1, -1.5, -0.8);
  }
  noStroke();
  for (Cubelet c : cubelets) {
    pushMatrix();
    if (isDragging && isInSlice(c.gx, c.gy, c.gz)) applySliceRotation(); // pivot at origin, before translate
    translate(c.gx*S, c.gy*S, c.gz*S);
    applyMatrix(c.orientation); // accumulated world-space rotation history
    shape(cubeShape);
    popMatrix();
  }
  noLights(); noStroke();
  drawStickers();
  popMatrix();

  // 2D overlays — depth test off so nothing interferes with the 3D scene
  hint(DISABLE_DEPTH_TEST);
  camera();
  noLights();

  // Solved glow
  if (solved) {
    noStroke();
    for (int r = 220; r > 0; r -= 22)
      { fill(red(SUCCESS), green(SUCCESS), blue(SUCCESS), darkMode ? 5 : 8); ellipse(CUBE_CX, CUBE_CY, r*2.6, r*2.6); }
  }

  drawPanel();
  hint(ENABLE_DEPTH_TEST);
}
