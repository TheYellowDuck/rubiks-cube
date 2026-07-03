// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Required Notice: Copyright (c) 2026 George Zhang — https://github.com/TheYellowDuck

// ── Raycasting (Step 1) ───────────────────────────────────────────────────

void performRaycast(int mx, int my) {
  dragOnFace = false;
  dragFaceNormal = null;
  dragClickedCubelet = null;

  // Processing default camera: eye at (width/2, height/2, eyeZ), looking toward z=0.
  // A screen pixel (mx, my) maps exactly to world point (mx, my, 0) at z=0.
  float eyeZ = (height / 2.0) / tan(PI / 6.0);
  PVector rayOrigin = new PVector(width / 2.0, height / 2.0, eyeZ);
  PVector rayDir    = new PVector(mx - width / 2.0, my - height / 2.0, -eyeZ);
  rayDir.normalize();

  // Transform ray into cube local space: apply rotMatrix^T (inverse of pure rotation)
  PVector localOrigin = applyTranspose(rotMatrix, PVector.sub(rayOrigin, new PVector(CUBE_CX, CUBE_CY, 0)));
  PVector localDir    = applyTranspose(rotMatrix, rayDir);

  // Ray-AABB intersection against the full 3×3×3 cube (±1.5*S on each axis)
  float half = 1.5 * S;
  float tMin = -1e9, tMax = 1e9;
  int hitAxis = -1;

  float[] orig = { localOrigin.x, localOrigin.y, localOrigin.z };
  float[] dir  = { localDir.x,    localDir.y,    localDir.z    };

  for (int axis = 0; axis < 3; axis++) {
    if (abs(dir[axis]) < 1e-6) {
      if (orig[axis] < -half || orig[axis] > half) return; // parallel and outside
      continue;
    }
    float t1 = (-half - orig[axis]) / dir[axis];
    float t2 = ( half - orig[axis]) / dir[axis];
    if (t1 > t2) { float tmp = t1; t1 = t2; t2 = tmp; }
    if (t1 > tMin) { tMin = t1; hitAxis = axis; } // last-entered slab = hit face axis
    tMax = min(tMax, t2);
    if (tMin > tMax) return; // miss
  }

  if (hitAxis < 0 || tMin < 0 || tMax < 0) return; // missed or cube behind camera

  PVector hit = PVector.add(localOrigin, PVector.mult(localDir, tMin));
  hit.x = constrain(hit.x, -half, half);
  hit.y = constrain(hit.y, -half, half);
  hit.z = constrain(hit.z, -half, half);

  float[] h = { hit.x, hit.y, hit.z };
  float faceSign = (h[hitAxis] >= 0) ? 1 : -1;

  dragFaceNormal = new PVector(
    hitAxis == 0 ? faceSign : 0,
    hitAxis == 1 ? faceSign : 0,
    hitAxis == 2 ? faceSign : 0
  );

  // Cubelet grid index: outer layer on the hit axis, interpolated on the other two
  int[] idx = new int[3];
  for (int i = 0; i < 3; i++)
    idx[i] = (i == hitAxis) ? (int) faceSign : constrain(round(h[i] / S), -1, 1);
  dragClickedCubelet = new PVector(idx[0], idx[1], idx[2]);
  dragOnFace = true;
}

// ── Reference vector computation (Step 2) ────────────────────────────────

// Called once at the start of the first mouseDragged frame after a face press.
// Computes the three screen-space reference drag vectors for the clicked face.
void computeRefVecs() {
  // The two local-space tangent axes on the face (the axes NOT equal to the face normal axis)
  if (dragFaceNormal.x != 0) {
    dragTangent1 = new PVector(0, 1, 0);  // Y axis
    dragTangent2 = new PVector(0, 0, 1);  // Z axis
  } else if (dragFaceNormal.y != 0) {
    dragTangent1 = new PVector(1, 0, 0);  // X axis
    dragTangent2 = new PVector(0, 0, 1);  // Z axis
  } else {
    dragTangent1 = new PVector(1, 0, 0);  // X axis
    dragTangent2 = new PVector(0, 1, 0);  // Y axis
  }

  // Project each local tangent into 2D screen space and normalise
  refVec1 = projectDir(dragTangent1);  refVec1.normalize();
  refVec2 = projectDir(dragTangent2);  refVec2.normalize();

  // Face-plane coordinates of the clicked cubie (the two axes tangent to the face)
  int faceCx, faceCy;
  if      (dragFaceNormal.x != 0) { faceCx = round(dragClickedCubelet.y); faceCy = round(dragClickedCubelet.z); }
  else if (dragFaceNormal.y != 0) { faceCx = round(dragClickedCubelet.x); faceCy = round(dragClickedCubelet.z); }
  else                             { faceCx = round(dragClickedCubelet.x); faceCy = round(dragClickedCubelet.y); }

  // Spin only fires on corners — edge and centre cubies only do slices.
  // The CW drag direction at corner (faceCx, faceCy) is the tangential velocity:
  //   velocity = (-faceCy, faceCx) in (tangent1, tangent2) face coords
  // which in screen space is:  -faceCy * refVec1 + faceCx * refVec2
  // This is perpendicular to the radial (centre-pointing) direction, so it's the
  // diagonal that does NOT point toward the face centre.
  // B, L, D need the spin direction negated:
  //  - B/L: negative-side faces flip CW/CCW relative to F/R
  //  - D:   rotateY(+) has opposite handedness from rotateX/Z(+)
  //  Combined correction = faceNormSign * yAxisFlip.
  float faceNormSign = dragFaceNormal.x + dragFaceNormal.y + dragFaceNormal.z;
  float yAxisFlip    = (dragFaceNormal.y != 0) ? -1 : 1;
  float spinDir      = faceNormSign * yAxisFlip;

  canSpin = (abs(faceCx) == 1 && abs(faceCy) == 1);
  if (canSpin) {
    refVecSpin = PVector.add(PVector.mult(refVec1, -faceCy * spinDir), PVector.mult(refVec2, faceCx * spinDir));
    refVecSpin.normalize();
  } else {
    refVecSpin = null;
  }
}

// Perspective-projects a local-space direction to a 2D screen-space direction.
// Uses the Jacobian of Processing's default camera at the cube centre (CUBE_CX, CUBE_CY, 0).
PVector projectDir(PVector localDir) {
  // Rotate local direction into world space via rotMatrix
  float wx = rotMatrix.m00*localDir.x + rotMatrix.m01*localDir.y + rotMatrix.m02*localDir.z;
  float wy = rotMatrix.m10*localDir.x + rotMatrix.m11*localDir.y + rotMatrix.m12*localDir.z;
  float wz = rotMatrix.m20*localDir.x + rotMatrix.m21*localDir.y + rotMatrix.m22*localDir.z;

  // Apply perspective correction: the z component shifts x and y due to the
  // cube centre being offset from the screen centre (CUBE_CX ≠ width/2, etc.)
  float eyeZ = (height / 2.0) / tan(PI / 6.0);
  float sx = wx + wz * (CUBE_CX - width  / 2.0) / eyeZ;
  float sy = wy + wz * (CUBE_CY - height / 2.0) / eyeZ;

  return new PVector(sx, sy, 0);  // z=0 marks this as a 2D screen vector
}

// ── Intent determination (Step 3) ─────────────────────────────────────────

// Compares the normalised 2D drag vector (dx, dy) against refVec1, refVec2, and
// (for corner presses) refVecSpin using the absolute dot product, so both
// directions of each axis are covered.
// Returns the index of the most-parallel reference axis: 0=tangent1, 1=tangent2, 2=spin.
// Returns -1 if the drag is too small or the reference vectors are not yet initialised.
int pickDragAxis(float dx, float dy) {
  if (refVec1 == null) return -1;
  float mag = sqrt(dx*dx + dy*dy);
  if (mag < 1e-6) return -1;

  float nx = dx / mag,  ny = dy / mag;

  float a1 = abs(nx * refVec1.x + ny * refVec1.y);
  float a2 = abs(nx * refVec2.x + ny * refVec2.y);

  if (canSpin && refVecSpin != null) {
    float a3 = abs(nx * refVecSpin.x + ny * refVecSpin.y);
    if (a1 >= a2 && a1 >= a3) return 0;
    if (a2 >= a1 && a2 >= a3) return 1;
    return 2;
  }
  return (a1 >= a2) ? 0 : 1;
}

// ── Axis mapping (Step 4.1) ───────────────────────────────────────────────

// Maps the locked drag axis index to the local-space 3D rotation axis.
//   axis 0 → faceNormal × tangent1   (the axis the slice rotates around when dragging tangent1)
//   axis 1 → faceNormal × tangent2
//   axis 2 → faceNormal itself       (spin: the face rotates around its own normal)
// The cross product is the geometric identity: dragging a sticker along a tangent
// sweeps it around the axis perpendicular to both that tangent and the face normal.
PVector computeRotationAxis(int axis) {
  if (axis == 2) return dragFaceNormal.copy();
  PVector t = (axis == 0) ? dragTangent1.copy() : dragTangent2.copy();
  return dragFaceNormal.cross(t);
}

// ── Slice grouping (Step 4.2) ─────────────────────────────────────────────

// Identifies the active slice by extracting the clicked cubelet's coordinate
// along the rotation axis.  All 9 cubelets sharing that coordinate are the group.
// In Processing there is no scene-graph parenting: the "pivot" is always the cube's
// local origin (0,0,0), and isInSlice() acts as the membership predicate.
// Middle slices (sliceCoord == 0) are supported via the camera trick — see
// commitMiddleTurn(): a middle turn is committed as the two outer face turns plus
// a whole-cube view rotation, so the colour model only ever sees face turns.
boolean lockSlice() {
  if      (abs(rotationAxis.x) > 0.5) sliceCoord = round(dragClickedCubelet.x);
  else if (abs(rotationAxis.y) > 0.5) sliceCoord = round(dragClickedCubelet.y);
  else                                 sliceCoord = round(dragClickedCubelet.z);
  sliceAngle = 0;
  return true;
}

// Returns true when the cubelet at grid position (cx, cy, cz) belongs to the active slice.
// Uses the targetAxis int (not the rotationAxis object) so a concurrent input event that
// nulls rotationAxis can never crash this — it's called from draw() every frame.
boolean isInSlice(int cx, int cy, int cz) {
  if (targetAxis == 0) return cx == sliceCoord;
  if (targetAxis == 1) return cy == sliceCoord;
  if (targetAxis == 2) return cz == sliceCoord;
  return false;
}

// ── Cubelet position tracking (Step 4.3.D.1) ─────────────────────────────

void initCubelets() {
  int idx = 0;
  for (int x = -1; x <= 1; x++)
    for (int y = -1; y <= 1; y++)
      for (int z = -1; z <= 1; z++)
        cubelets[idx++] = new Cubelet(x, y, z);
}

// Applies snapSteps 90° CW rotations (in Processing's coordinate system) to the
// grid positions of the 9 in-slice cubelets.  snapSteps = sign × round(sliceAngle/HALF_PI),
// where sign is the ±1 component of rotationAxis on the target axis.
// A snapshot of all 9 positions is taken before any writes to prevent mid-loop overwrites.
void applyGridPositionSwap(int snapSteps) {
  if (snapSteps == 0) return;
  snapSteps = ((snapSteps % 4) + 4) % 4;  // normalise to 0..3 (handles negatives)

  for (int step = 0; step < snapSteps; step++) {
    // Phase 1 — snapshot: record the index and current position of each in-slice cubelet
    int[] ids  = new int[9];
    int[][] pre = new int[9][3];
    int n = 0;
    for (int i = 0; i < 27; i++) {
      Cubelet c = cubelets[i];
      if (isInSlice(c.gx, c.gy, c.gz)) {
        ids[n]    = i;
        pre[n][0] = c.gx;  pre[n][1] = c.gy;  pre[n][2] = c.gz;
        n++;
      }
    }

    // Phase 2 — apply: write new coords from the frozen snapshot (safe from overwrites)
    // Formulas from Processing's rotateX/Y/Z(+HALF_PI) matrix:
    //   rotateX: (x, y, z) → (x,  -z,  y)
    //   rotateY: (x, y, z) → (z,   y, -x)
    //   rotateZ: (x, y, z) → (-y,  x,  z)
    for (int k = 0; k < n; k++) {
      Cubelet c = cubelets[ids[k]];
      int ox = pre[k][0], oy = pre[k][1], oz = pre[k][2];
      switch (targetAxis) {
        case 0: c.gx = ox;  c.gy = -oz; c.gz = oy;  break;
        case 1: c.gx = oz;  c.gy = oy;  c.gz = -ox; break;
        case 2: c.gx = -oy; c.gy = ox;  c.gz = oz;  break;
      }
    }
  }
}

// ── Move-string mapping (Step 4.3.E) ─────────────────────────────────────

// Converts (targetAxis, sliceCoord, snapSteps) to a Cube.scramble() move string.
// Key: applyGridPositionSwap(norm=1) always applies rotateAxis(+HALF_PI) — the positive
// convention.  For positive-side faces (+1) that IS the standard CW move; for negative-side
// faces (-1) it is the prime move.  faceNorm remaps norm into each face's own CW frame.
// Middle slices (sliceCoord == 0) are not yet in the Cube class, so they return null.
String sliceToMoveString(int snapSteps) {
  int norm = ((snapSteps % 4) + 4) % 4;
  if (norm == 0) return null;

  String base;
  if      (targetAxis == 1 && sliceCoord == -1) base = "U";
  else if (targetAxis == 1 && sliceCoord ==  1) base = "D";
  else if (targetAxis == 0 && sliceCoord ==  1) base = "R";
  else if (targetAxis == 0 && sliceCoord == -1) base = "L";
  else if (targetAxis == 2 && sliceCoord ==  1) base = "F";
  else if (targetAxis == 2 && sliceCoord == -1) base = "B";
  else return null;

  // Remap norm into the face's own CW frame:
  // positive-side faces keep norm as-is; negative-side faces invert (4 - norm) % 4
  int faceNorm = (sliceCoord == 1) ? norm : ((4 - norm) % 4);
  if (faceNorm == 0) return null;
  if (faceNorm == 2) return base + "2";
  if (faceNorm == 1) return base;
  return base + "'";
}

// ── Orientation update (Step 4.3.D.2) ────────────────────────────────────

// Multiplies each in-slice cubelet's orientation matrix by the snap rotation.
// effectiveAngle = axisSign × finalSnapAngle — the signed angle actually shown on screen.
// preApply accumulates in world space (rot × existing), matching how spinView works.
void applySliceOrientation(float effectiveAngle) {
  if (effectiveAngle == 0) return;
  PMatrix3D rot = new PMatrix3D();
  switch (targetAxis) {
    case 0: rot.rotateX(effectiveAngle); break;
    case 1: rot.rotateY(effectiveAngle); break;
    case 2: rot.rotateZ(effectiveAngle); break;
  }
  for (int i = 0; i < 27; i++) {
    Cubelet c = cubelets[i];
    if (isInSlice(c.gx, c.gy, c.gz)) c.orientation.preApply(rot);
  }
}
