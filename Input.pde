// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Required Notice: Copyright (c) 2026 George Zhang — https://github.com/TheYellowDuck

void spinView(float rx, float ry) {
  PMatrix3D d = new PMatrix3D();
  if (ry != 0) d.rotateY(ry);
  if (rx != 0) d.rotateX(rx);
  rotMatrix.preApply(d);
}

// Returns the physical face label (U/D/F/B/R/L) whose normal is currently
// most aligned with the given screen-space direction.
String physicalFace(float sx, float sy, float sz) {
  float[][] n = {{0,-1,0},{0,1,0},{0,0,1},{0,0,-1},{1,0,0},{-1,0,0}};
  String[] labels = {"U","D","F","B","R","L"};
  String best = "U"; float bestDot = -1e9;
  for (int i = 0; i < 6; i++) {
    float wx = rotMatrix.m00*n[i][0] + rotMatrix.m01*n[i][1] + rotMatrix.m02*n[i][2];
    float wy = rotMatrix.m10*n[i][0] + rotMatrix.m11*n[i][1] + rotMatrix.m12*n[i][2];
    float wz = rotMatrix.m20*n[i][0] + rotMatrix.m21*n[i][1] + rotMatrix.m22*n[i][2];
    float dot = wx*sx + wy*sy + wz*sz;
    if (dot > bestDot) { bestDot = dot; best = labels[i]; }
  }
  return best;
}

// ── Mouse ─────────────────────────────────────────────────────────────────

void mousePressed() {
  pressInPanel = (mouseX > PANEL_X);
  dragStartX = mouseX; dragStartY = mouseY;
  prevMX = mouseX; prevMY = mouseY;
  didDrag = false;
  didRotate = false;

  // While a move is animating (or a solve is computing) the slice variables
  // (rotationAxis / targetAxis / isDragging / sliceAngle) belong to that
  // animation. Resetting them here would null rotationAxis mid-flight and crash
  // updateAnimation(). So for a press while busy we only allow view rotation and
  // never engage slice interaction. (Panel button clicks still work — they are
  // dispatched from mouseReleased.)
  if (busy()) {
    pressOnCube = false;
    dragOnFace  = false;
    return;
  }

  dragOnFace = false;
  chosenAxis = -1;
  axisLocked = false;
  rotationAxis = null;
  sliceAngle = 0;
  isDragging = false;
  targetAxis = -1;
  pressOnCube = false;
  canSpin = false;
  refVecSpin = null;
  if (!pressInPanel) {
    performRaycast(mouseX, mouseY);
    pressOnCube = dragOnFace;  // true only when the ray actually hit a cube face
  }
}

void mouseDragged() {
  if (pressInPanel) return;

  // Step 2: freeze the three reference vectors on the very first drag frame of a face press
  if (dragOnFace && !didDrag) computeRefVecs();

  didDrag = true;

  // Step 4.1: once the total drag exceeds the threshold, lock the chosen axis
  if (dragOnFace && !axisLocked) {
    float dx = mouseX - dragStartX, dy = mouseY - dragStartY;
    if (sqrt(dx*dx + dy*dy) >= DRAG_THRESHOLD) {
      int axis = pickDragAxis(dx, dy);
      if (axis >= 0) {
        chosenAxis   = axis;
        axisLocked   = true;
        rotationAxis = computeRotationAxis(axis);
        if (lockSlice()) {     // false → middle slice (no face move); leave gesture inert
          targetAxis = (abs(rotationAxis.x) > 0.5) ? 0 : (abs(rotationAxis.y) > 0.5) ? 1 : 2;
          isDragging = true;
        } else {
          rotationAxis = null;
          dragOnFace   = false;   // stop retrying the lock this gesture
        }
      }
    }
  }
  // Step 4.3.B: update the live slice angle from the TOTAL drag (not per-frame delta)
  // so the user can scrub the slice back and forth smoothly.
  // Gated on dragOnFace so it only runs for a genuine face drag (whose reference
  // vectors are initialised) — never against an in-progress move animation, which
  // also sets isDragging but leaves refVec* null.
  if (isDragging && dragOnFace) {
    float totalDx = mouseX - dragStartX, totalDy = mouseY - dragStartY;
    if (chosenAxis == 2) {
      sliceAngle = (totalDx * refVecSpin.x + totalDy * refVecSpin.y) * DRAG_TO_ANGLE;
    } else {
      PVector activeRef = (chosenAxis == 0) ? refVec1 : refVec2;
      sliceAngle = (totalDx * activeRef.x + totalDy * activeRef.y) * DRAG_TO_ANGLE;
    }
  }

  if (IS_MAC && mouseButton == RIGHT && macCtrl) macCtrlDrag = true;
  boolean rightDrag = (mouseButton == RIGHT) && !(IS_MAC && (macCtrl || macCtrlDrag));
  if (rotateKey || rightDrag || !pressOnCube) {
    spinView((mouseY - prevMY) * 0.01, (mouseX - prevMX) * 0.01);
    didRotate = true;
  }
  prevMX = mouseX; prevMY = mouseY;
}

void mouseReleased() {
  if (IS_MAC) rotateKey = false;  // Mac: Ctrl+click → OS right-click can leave state stuck; reset on release
  if (pressInPanel) {
    if (abs(mouseX - dragStartX) < 8 && abs(mouseY - dragStartY) < 8)
      handlePanelClick();
    return;
  }
  // An engaged user slice drag must ALWAYS resolve on release — even if a view
  // rotation also fired during the gesture (e.g. a trackpad/ctrl right-drag on
  // macOS).  Otherwise the slice can freeze mid-turn ("stuck in rotation").
  // Only finalise a genuine drag (not a running animation, which also sets
  // isDragging); animations resolve themselves in updateAnimation().
  if (isDragging && !isAnimating && !snapping && rotationAxis != null && targetAxis >= 0) {
    float axisSign       = (targetAxis == 0) ? rotationAxis.x : (targetAxis == 1) ? rotationAxis.y : rotationAxis.z;
    float finalSnapAngle = round(sliceAngle / HALF_PI) * HALF_PI;

    // Ease into the nearest 90° via the snap tween (updateDragSnap), which commits
    // the move at the end — same apply as before, just animated instead of instant.
    snapFrom       = sliceAngle;
    snapTo         = finalSnapAngle;
    snapStepsV     = round(sliceAngle / HALF_PI) * (int) axisSign;
    snapApplyAngle = axisSign * finalSnapAngle;
    snapMiddle     = (sliceCoord == 0);                       // middle slice → camera trick
    snapUndo       = false;                                   // a fresh turn, not an undo
    snapMv         = snapMiddle ? null : sliceToMoveString(snapStepsV);
    snapStartMs    = millis();
    snapping       = true;
  }

  // end the gesture (the snap tween keeps rendering/committing the slice if started)
  chosenAxis = -1;
  axisLocked = false;
  dragOnFace = false;
}

void mouseMoved() {
  if (IS_MAC && mouseX > PANEL_X) macCtrlDrag = false;  // cursor in panel → NEWT state resets
}

void mouseExited() {
  macCtrl = false;
  macCtrlDrag = false;
}

// ── Keyboard ─────────────────────────────────────────────────────────────

// physicalFace(sx,sy,sz) finds which logical face (U/D/F/B/R/L) has its
// world-space normal most aligned with the given screen-space direction, so
// keys always act on whichever face is currently facing that screen direction.
void keyPressed() {
  if (key == CODED) {
    if (IS_MAC ? keyCode == CMD : keyCode == CONTROL) { rotateKey = true; return; }
    if (IS_MAC && keyCode == CONTROL) { macCtrl = true; return; }
    if      (keyCode == LEFT)  spinView(0, -0.12);
    else if (keyCode == RIGHT) spinView(0,  0.12);
    else if (keyCode == UP)    spinView(-0.12, 0);
    else if (keyCode == DOWN)  spinView( 0.12, 0);
    return;
  }
  if (key == ENTER || key == RETURN) { doReset(); return; }
  if (key == ' ') { doScramble(); return; }
  if (key == 's' || key == 'S') { doSolve(); return; }   // auto-solve (all at once)
  if (key == 'n' || key == 'N') { doStep();  return; }   // next step
  if (key == 't' || key == 'T') { startSelfTest(); return; }   // solver self-check (console)

  boolean prime = (key >= 'A' && key <= 'Z');
  String face = null;
  switch (Character.toLowerCase(key)) {
    case 'u': face = physicalFace( 0, -1,  0); break;  // screen up
    case 'd': face = physicalFace( 0,  1,  0); break;  // screen down
    case 'r': face = physicalFace( 1,  0,  0); break;  // screen right
    case 'l': face = physicalFace(-1,  0,  0); break;  // screen left
    case 'f': face = physicalFace( 0,  0,  1); break;  // toward viewer
    case 'b': face = physicalFace( 0,  0, -1); break;  // away from viewer
  }
  if (face != null) execKeyMove(face, prime);
}

void keyReleased() {
  if (key == CODED && (IS_MAC ? keyCode == CMD : keyCode == CONTROL)) rotateKey = false;
  if (IS_MAC && key == CODED && keyCode == CONTROL) macCtrl = false;
}
