// ── Move pipeline ─────────────────────────────────────────────────────────────
// Every cube turn flows through here: one animated move at a time, fed by a single
// queue (moveQueue) shared by scramble / auto-solve / step-solve / undo.  Each
// queued move is a quarter turn ("U" / "U'").  solveCube() runs on a background
// thread so the UI never freezes; its result is consumed in updateAnimation().

// ── Applying a completed move ──────────────────────────────────────────────────
void doMove(String m) {
  cube.scramble(m);
  history.add(m);
  moveCount++;
  if (!timerRunning && !solved) { timerRunning = true; startMs = millis(); }
  boolean was = solved;
  solved = cube.isSolved();
  if (solved && !was) { timerRunning = false; solvedMs = millis() - startMs; if (!assisted) recordBestTime(solvedMs); }
}

// ── Animating one move ─────────────────────────────────────────────────────────
// face ∈ U/D/R/L/F/B, played as a 90° turn; kind decides how it is recorded when
// the animation completes (see updateAnimation).
void startMove(String face, boolean prime, int kind, int durationMs) {
  int axis, coord;
  switch (face) {
    case "U": axis=1; coord=-1; break;
    case "D": axis=1; coord= 1; break;
    case "R": axis=0; coord= 1; break;
    case "L": axis=0; coord=-1; break;
    case "F": axis=2; coord= 1; break;
    case "B": axis=2; coord=-1; break;
    default: return;
  }
  targetAxis      = axis;
  sliceCoord      = coord;
  rotationAxis    = new PVector(axis==0?coord:0, axis==1?coord:0, axis==2?coord:0);
  sliceAngle      = 0;
  isDragging      = true;
  isAnimating     = true;
  animStartMs     = millis();
  animSnapSteps   = coord * (prime ? -1 : 1);
  animMove        = prime ? face + "'" : face;
  animSliceTarget = (prime ? -1 : 1) * HALF_PI;
  animDurationMs  = durationMs;
  animKind        = kind;
}

void startMoveToken(String tok, int kind, int durationMs) {   // tok is a quarter turn
  boolean prime = tok.endsWith("'");
  startMove(prime ? tok.substring(0, tok.length()-1) : tok, prime, kind, durationMs);
}

int seqCadence() {
  if (seqKind == K_SCRAMBLE) return SCRAMBLE_ANIM_MS;
  if (seqKind == K_SOLVE)    return autoPlay ? SOLVE_ANIM_MS : ANIM_MS;
  return ANIM_MS;  // undo
}

void startNextQueued() {
  if (moveQueue.isEmpty()) return;
  startMoveToken(moveQueue.remove(0), seqKind, seqCadence());
}

// ── Per-frame tick (called from draw) ──────────────────────────────────────────
void updateAnimation() {
  if (planReady) consumePlan();        // a background solve finished
  if (snapping) { updateDragSnap(); return; }   // a drag-release is easing into place

  if (!isAnimating) return;
  float t = constrain((float)(millis() - animStartMs) / animDurationMs, 0, 1);
  float ease = t < 0.5 ? 2*t*t : -1 + (4 - 2*t)*t;   // ease-in-out quad
  sliceAngle = animSliceTarget * ease;
  if (t < 1.0) return;

  // commit to the cubelet grid + orientation
  applyGridPositionSwap(animSnapSteps);
  applySliceOrientation(animSnapSteps * HALF_PI);

  // record the move (kind-specific)
  switch (animKind) {
    case K_SCRAMBLE: cube.scramble(animMove); history.add(animMove); break;  // undoable, not counted/timed
    case K_UNDO:     cube.scramble(animMove); break;                          // history already popped
    default:                                                                  // manual + solve
      if (animKind == K_SOLVE) assisted = true;   // solver help → this solve won't count as a best time
      doMove(animMove);
  }

  // clear the active-slice view
  sliceAngle = 0; isDragging = false; isAnimating = false;
  rotationAxis = null; targetAxis = -1; animMove = null; animKind = K_NONE;

  // advance the queue, or finish the sequence
  if (autoPlay && seqKind != K_NONE && !moveQueue.isEmpty() && !solved) {
    startNextQueued();
  } else if (moveQueue.isEmpty()) {
    seqKind  = K_NONE;
    autoPlay = false;
    solved   = cube.isSolved();
  }
  // else: paused mid-plan (queue non-empty, autoPlay false) — keep the plan
}

// ── Stopping / cancelling ──────────────────────────────────────────────────────
void cancelPlanCompute() { planGen++; planComputing = false; planReady = false; }

// Cancel a running scramble / auto-solve / undo and discard any solve plan.  The
// move currently animating finishes; updateAnimation() then finalises the empty queue.
void stopSequence() {
  moveQueue.clear();
  seqKind  = K_NONE;
  autoPlay = false;
  cancelPlanCompute();
}

// ── Background solve ────────────────────────────────────────────────────────────
void requestPlan(boolean autoIntent) {
  planSnapshot   = copyCube(cube);     // worker reads only this snapshot, never the live cube
  planAutoIntent = autoIntent;
  planRunId      = ++planGen;
  planComputing  = true;
  planReady      = false;
  thread("computePlanAsync");
}
void computePlanAsync() {              // runs on a worker thread
  int id = planRunId;
  String sol = solveCube(planSnapshot);
  planResult    = sol;
  planResultGen = id;
  planReady     = true;
}
void consumePlan() {                   // main thread, from updateAnimation
  planReady     = false;
  planComputing = false;
  boolean stale = (planResultGen != planGen);   // superseded by a scramble/reset/newer request
  String sol = planResult; planResult = null;
  if (stale) return;

  moveQueue.clear();
  if (sol != null && !sol.trim().isEmpty()) {
    for (String m : sol.trim().split("\\s+")) {
      if (m.isEmpty()) continue;
      if (m.endsWith("2")) { String q = m.substring(0, 1); moveQueue.add(q); moveQueue.add(q); }
      else moveQueue.add(m);
    }
  }
  if (moveQueue.isEmpty()) { seqKind = K_NONE; return; }
  seqKind  = K_SOLVE;
  autoPlay = planAutoIntent;
  startNextQueued();                   // play the first move (auto-advances if autoPlay)
}

// ── User actions ────────────────────────────────────────────────────────────────
void doScramble() {
  stopSequence();
  isAnimating = false; isDragging = false; rotationAxis = null; targetAxis = -1; sliceAngle = 0; snapping = false;
  cube = new Cube();
  initCubelets();
  moveCount = 0; timerRunning = false; startMs = 0; assisted = false;
  solved = false; solvedMs = 0; history.clear();

  String[] faces = {"U","D","R","L","F","B"};
  String[] mods  = {"","'","2"};
  int last = -1;
  for (int i = 0; i < 20; i++) {
    int f; do { f = (int) random(6); } while (f == last);
    last = f;
    String mod = mods[(int) random(3)];
    if (mod.equals("2")) { moveQueue.add(faces[f]); moveQueue.add(faces[f]); }
    else moveQueue.add(faces[f] + mod);
  }
  seqKind  = K_SCRAMBLE;
  autoPlay = true;
  startNextQueued();
}

void doSolve() {
  if (planComputing || snapping) return;
  if (seqKind == K_SCRAMBLE || seqKind == K_UNDO) { stopSequence(); return; }   // interrupt
  if (solved) return;
  if (seqKind == K_SOLVE) {
    if (autoPlay) { autoPlay = false; return; }          // pause
    if (!moveQueue.isEmpty()) {                           // resume a paused plan
      autoPlay = true;
      if (!isAnimating) startNextQueued();
      return;
    }
  }
  if (isAnimating) return;
  requestPlan(true);                                      // compute (async) → auto-play
}

void doStep() {
  if (planComputing || snapping) return;
  if (seqKind == K_SCRAMBLE || seqKind == K_UNDO) { stopSequence(); return; }
  if (solved) return;
  if (seqKind == K_SOLVE && autoPlay) { autoPlay = false; return; }             // pause auto-play
  if (isAnimating) return;
  if (seqKind == K_SOLVE && !moveQueue.isEmpty()) { startNextQueued(); return; } // step existing plan
  requestPlan(false);                                     // compute (async) → single step
}

void doUndo() {
  if (autoPlay) { stopSequence(); return; }   // a running sequence: stop it
  if (isAnimating || planComputing || snapping) return;
  if (history.isEmpty()) return;
  stopSequence();                              // discard any paused plan; the cube is about to change

  String m = history.remove(history.size() - 1);   // reverse the most recent move (manual/scramble/solve)
  if (isMiddleToken(m)) { startMiddleUndo(m); return; }   // middle turn: rewind outers + camera

  String invm = inv(m);
  moveCount = max(0, moveCount - 1);
  solved = false;
  if (moveCount == 0) { timerRunning = false; startMs = 0; }

  moveQueue.clear();
  if (invm.endsWith("2")) { String q = invm.substring(0, 1); moveQueue.add(q); moveQueue.add(q); }
  else moveQueue.add(invm);
  seqKind  = K_UNDO;
  autoPlay = true;
  startNextQueued();
}

void doReset() {
  stopSequence();
  isAnimating = false; isDragging = false; rotationAxis = null; targetAxis = -1; sliceAngle = 0; snapping = false;
  cube = new Cube();
  initCubelets();
  moveCount = 0; timerRunning = false; startMs = 0; assisted = false;
  solved = false; solvedMs = 0; history.clear();
}

// Manual move from a key press or a panel move button.
void execKeyMove(String face, boolean prime) {
  if (autoPlay) { stopSequence(); return; }     // a move input interrupts a running sequence
  if (busy()) return;                            // mid-move / snapping / computing
  stopSequence();                                // discard any paused solve plan
  startMove(face, prime, K_MANUAL, ANIM_MS);
}

// Eases a released drag from where you let go to the nearest 90°, then commits the
// move (same apply as the old instant release, just deferred to the tween's end).
void updateDragSnap() {
  float t = constrain((float)(millis() - snapStartMs) / SNAP_MS, 0, 1);
  float ease = t < 0.5 ? 2*t*t : -1 + (4 - 2*t)*t;   // ease-in-out quad
  sliceAngle = snapFrom + (snapTo - snapFrom) * ease;
  if (t < 1.0) return;

  if (snapMiddle) {
    commitMiddleTurnRaw(targetAxis, snapStepsV);           // two outer turns + a view rotation
    if (snapUndo) {                                         // undoing a middle turn
      moveCount = max(0, moveCount - 1);
      solved = cube.isSolved();
      if (moveCount == 0) { timerRunning = false; startMs = 0; }
    } else {                                                // a fresh middle turn = one move
      recordMiddle(targetAxis, snapStepsV);
    }
  } else {
    applyGridPositionSwap(snapStepsV);
    applySliceOrientation(snapApplyAngle);
    if (snapMv != null) { stopSequence(); doMove(snapMv); } // a manual turn invalidates any solve plan
  }

  sliceAngle = 0; isDragging = false; rotationAxis = null; targetAxis = -1;
  snapMv = null; snapping = false; snapMiddle = false; snapUndo = false;
}

// Commits a middle-slice turn without ever doing an M/E/S move on the colour model.
// Identity: a middle turn = turning the two OUTER layers the opposite way + rotating
// the whole cube.  The outer turns are real face moves (model stays solvable); the
// "whole-cube rotation" is applied to the camera (rotMatrix), so the outer layers end
// up visually fixed and the middle appears to have turned.
//
//  middle(+k around axis)  ≡  outer±1 layers turned −k   (model + cubelets)
//                              + camera rotated +k        (view only)
//
// Applies the geometry only (cubelets + colour model + camera) — no history/timer/
// count.  The same routine runs forward and in reverse (pass the inverse steps).
void commitMiddleTurnRaw(int axis, int steps) {
  int s = ((steps % 4) + 4) % 4;
  if (s == 0) return;
  int outer = (4 - s) % 4;          // outer layers turn opposite to the middle

  int savedCoord = sliceCoord;
  for (int oc = 1; oc >= -1; oc -= 2) {     // the +1 and −1 outer layers on this axis
    sliceCoord = oc;
    applyGridPositionSwap(outer);
    applySliceOrientation(outer * HALF_PI);
    String m = sliceToMoveString(outer);
    if (m != null) cube.scramble(m);        // colour model only — no history/count
  }
  sliceCoord = savedCoord;

  float camAngle = s * HALF_PI;     // camera rotates the same way the middle should
  switch (axis) {
    case 0: rotMatrix.rotateX(camAngle); break;
    case 1: rotMatrix.rotateY(camAngle); break;
    case 2: rotMatrix.rotateZ(camAngle); break;
  }
}

// A middle turn is one history entry "~<axis><steps>" (so it's one move and one undo).
String  middleToken(int axis, int steps) { return "~" + axis + (((steps % 4) + 4) % 4); }
boolean isMiddleToken(String t) { return t != null && t.startsWith("~"); }

// Records a just-applied middle turn as a single move (history + count + timer + solved).
void recordMiddle(int axis, int steps) {
  stopSequence();                                  // a manual turn invalidates any solve plan
  history.add(middleToken(axis, steps));
  moveCount++;
  if (!timerRunning && !solved) { timerRunning = true; startMs = millis(); }
  boolean was = solved;
  solved = cube.isSolved();
  if (solved && !was) { timerRunning = false; solvedMs = millis() - startMs; if (!assisted) recordBestTime(solvedMs); }
}

// Undo of a middle turn: animate the middle sweeping back, then apply the inverse
// (which also rewinds the camera).  Driven through the snap tween with snapUndo=true.
void startMiddleUndo(String token) {
  int axis = token.charAt(1) - '0';
  int s    = token.charAt(2) - '0';
  int invSteps = (4 - s) % 4;
  targetAxis   = axis;
  sliceCoord   = 0;
  rotationAxis = new PVector(axis==0?1:0, axis==1?1:0, axis==2?1:0);
  isDragging   = true;
  snapFrom     = 0;
  snapTo       = invSteps * HALF_PI;
  snapStepsV   = invSteps;
  snapMv       = null;
  snapMiddle   = true;
  snapUndo     = true;
  snapStartMs  = millis();
  snapping     = true;
}

// True while a move is animating / snapping / a solve is computing — gates slice dragging.
boolean busy() { return isAnimating || planComputing || snapping; }

String inv(String m) {
  if (m.endsWith("'")) return m.substring(0, m.length() - 1);
  if (m.endsWith("2")) return m;
  return m + "'";
}

String fmtTime(long ms) {
  return String.format("%02d:%02d.%01d", ms/60000, (ms/1000)%60, (ms/100)%10);
}
