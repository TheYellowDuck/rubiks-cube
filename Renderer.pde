// ── 3D cube geometry ─────────────────────────────────────────────────────────

// Chamfered cube: 6 flat faces + 12 bevel edges + 8 corner triangles, all with normals.
PShape buildRoundedCube(float s, float r) {
  float h = s * 0.5, ih = h - r;
  float s2 = 0.70711, s3 = 0.57735;  // 1/sqrt(2), 1/sqrt(3)

  PShape q = createShape();
  q.beginShape(QUADS);
  q.noStroke();
  q.fill(52);

  // 6 main faces
  q.normal( 0, 1, 0); q.vertex(-ih, h,-ih); q.vertex( ih, h,-ih); q.vertex( ih, h, ih); q.vertex(-ih, h, ih);
  q.normal( 0,-1, 0); q.vertex(-ih,-h,-ih); q.vertex(-ih,-h, ih); q.vertex( ih,-h, ih); q.vertex( ih,-h,-ih);
  q.normal( 0, 0, 1); q.vertex(-ih,-ih, h); q.vertex( ih,-ih, h); q.vertex( ih, ih, h); q.vertex(-ih, ih, h);
  q.normal( 0, 0,-1); q.vertex(-ih,-ih,-h); q.vertex(-ih, ih,-h); q.vertex( ih, ih,-h); q.vertex( ih,-ih,-h);
  q.normal( 1, 0, 0); q.vertex( h,-ih,-ih); q.vertex( h, ih,-ih); q.vertex( h, ih, ih); q.vertex( h,-ih, ih);
  q.normal(-1, 0, 0); q.vertex(-h,-ih,-ih); q.vertex(-h,-ih, ih); q.vertex(-h, ih, ih); q.vertex(-h, ih,-ih);

  // 12 bevel edges — top ring
  q.normal(   0, s2, s2); q.vertex(-ih, h, ih);  q.vertex( ih, h, ih);  q.vertex( ih, ih, h);  q.vertex(-ih, ih, h);
  q.normal(   0, s2,-s2); q.vertex(-ih, h,-ih);  q.vertex(-ih, ih,-h);  q.vertex( ih, ih,-h);  q.vertex( ih, h,-ih);
  q.normal( s2, s2,  0);  q.vertex( ih, h,-ih);  q.vertex( ih, h, ih);  q.vertex( h, ih, ih);  q.vertex( h, ih,-ih);
  q.normal(-s2, s2,  0);  q.vertex(-ih, h,-ih);  q.vertex(-h, ih,-ih);  q.vertex(-h, ih, ih);  q.vertex(-ih, h, ih);
  // bottom ring
  q.normal(   0,-s2, s2); q.vertex(-ih,-h, ih);  q.vertex(-ih,-ih, h);  q.vertex( ih,-ih, h);  q.vertex( ih,-h, ih);
  q.normal(   0,-s2,-s2); q.vertex(-ih,-h,-ih);  q.vertex( ih,-h,-ih);  q.vertex( ih,-ih,-h);  q.vertex(-ih,-ih,-h);
  q.normal( s2,-s2,  0);  q.vertex( ih,-h,-ih);  q.vertex( h,-ih,-ih);  q.vertex( h,-ih, ih);  q.vertex( ih,-h, ih);
  q.normal(-s2,-s2,  0);  q.vertex(-ih,-h,-ih);  q.vertex(-ih,-h, ih);  q.vertex(-h,-ih, ih);  q.vertex(-h,-ih,-ih);
  // middle ring
  q.normal( s2,  0, s2);  q.vertex( ih,-ih, h);  q.vertex( ih, ih, h);  q.vertex( h, ih, ih);  q.vertex( h,-ih, ih);
  q.normal(-s2,  0, s2);  q.vertex(-ih,-ih, h);  q.vertex(-h,-ih, ih);  q.vertex(-h, ih, ih);  q.vertex(-ih, ih, h);
  q.normal( s2,  0,-s2);  q.vertex( ih,-ih,-h);  q.vertex( h,-ih,-ih);  q.vertex( h, ih,-ih);  q.vertex( ih, ih,-h);
  q.normal(-s2,  0,-s2);  q.vertex(-ih,-ih,-h);  q.vertex(-ih, ih,-h);  q.vertex(-h, ih,-ih);  q.vertex(-h,-ih,-ih);

  q.endShape();

  // 8 corner triangles
  PShape t = createShape();
  t.beginShape(TRIANGLES);
  t.noStroke();
  t.fill(52);

  t.normal( s3, s3, s3); t.vertex( ih, h, ih);  t.vertex( h, ih, ih);  t.vertex( ih, ih, h);
  t.normal(-s3, s3, s3); t.vertex(-ih, h, ih);  t.vertex(-ih, ih, h);  t.vertex(-h, ih, ih);
  t.normal( s3, s3,-s3); t.vertex( ih, h,-ih);  t.vertex( ih, ih,-h);  t.vertex( h, ih,-ih);
  t.normal(-s3, s3,-s3); t.vertex(-ih, h,-ih);  t.vertex(-h, ih,-ih);  t.vertex(-ih, ih,-h);
  t.normal( s3,-s3, s3); t.vertex( ih,-h, ih);  t.vertex( ih,-ih, h);  t.vertex( h,-ih, ih);
  t.normal(-s3,-s3, s3); t.vertex(-ih,-h, ih);  t.vertex(-h,-ih, ih);  t.vertex(-ih,-ih, h);
  t.normal( s3,-s3,-s3); t.vertex( ih,-h,-ih);  t.vertex( h,-ih,-ih);  t.vertex( ih,-ih,-h);
  t.normal(-s3,-s3,-s3); t.vertex(-ih,-h,-ih);  t.vertex(-ih,-ih,-h);  t.vertex(-h,-ih,-ih);

  t.endShape();

  PShape g = createShape(GROUP);
  g.addChild(q);
  g.addChild(t);
  return g;
}

// ── Sticker rendering ─────────────────────────────────────────────────────────

void drawStickers() {
  drawStickerPass(false);        // static: all cubelets not in the active slice
  if (isDragging) {
    pushMatrix();
    applySliceRotation();
    drawStickerPass(true);       // rotating: only the 9 cubelets in the active slice
    popMatrix();
  }
}

// Draws the stickers that either belong (sliceOnly=true) or don't belong (sliceOnly=false)
// to the active slice.  When not dragging, !isDragging short-circuits every check so all
// stickers are drawn in the single sliceOnly=false call.
// Cubelet grid positions per face (derived from the row/col → world coordinate mapping):
//   U[row][col] → (col-1,  -1, row-1)     D[row][col] → (col-1,  +1, 1-row)
//   F[row][col] → (col-1, row-1,  +1)     B[row][col] → (1-col, row-1,  -1)
//   R[row][col] → ( +1,  row-1, 1-col)    L[row][col] → ( -1,  row-1, col-1)
void drawStickerPass(boolean sliceOnly) {
  float u = -1.5*S - SO;
  float d =  1.5*S + SO;
  float f =  1.5*S + SO;
  float b = -1.5*S - SO;
  float r =  1.5*S + SO;
  float l = -1.5*S - SO;

  for (int row = 0; row < 3; row++) {
    for (int col = 0; col < 3; col++) {
      float cx = (col-1)*S, cy = (row-1)*S;
      float x0 = cx-HS+GAP, x1 = cx+HS-GAP;
      float y0 = cy-HS+GAP, y1 = cy+HS-GAP;
      float z0 = (row-1)*S-HS+GAP, z1 = (row-1)*S+HS-GAP;
      float zd0= (1-row)*S-HS+GAP, zd1= (1-row)*S+HS-GAP;
      float zr0= (1-col)*S-HS+GAP, zr1= (1-col)*S+HS-GAP;
      float zl0= (col-1)*S-HS+GAP, zl1= (col-1)*S+HS-GAP;
      float bx0= (1-col)*S-HS+GAP, bx1= (1-col)*S+HS-GAP;

      if (!isDragging || isInSlice(col-1, -1,    row-1) == sliceOnly) {
        fill(faceColor(cube.U[row][col]));
        quad3(x0,u,z0,  x1,u,z0,  x1,u,z1,  x0,u,z1);
      }
      if (!isDragging || isInSlice(col-1, +1,    1-row) == sliceOnly) {
        fill(faceColor(cube.D[row][col]));
        quad3(x0,d,zd0, x1,d,zd0, x1,d,zd1, x0,d,zd1);
      }
      if (!isDragging || isInSlice(col-1, row-1, +1   ) == sliceOnly) {
        fill(faceColor(cube.F[row][col]));
        quad3(x0,y0,f,  x1,y0,f,  x1,y1,f,  x0,y1,f);
      }
      if (!isDragging || isInSlice(1-col, row-1, -1   ) == sliceOnly) {
        fill(faceColor(cube.B[row][col]));
        quad3(bx0,y0,b, bx1,y0,b, bx1,y1,b, bx0,y1,b);
      }
      if (!isDragging || isInSlice(+1,    row-1, 1-col) == sliceOnly) {
        fill(faceColor(cube.R[row][col]));
        quad3(r,y0,zr0, r,y0,zr1, r,y1,zr1, r,y1,zr0);
      }
      if (!isDragging || isInSlice(-1,    row-1, col-1) == sliceOnly) {
        fill(faceColor(cube.L[row][col]));
        quad3(l,y0,zl0, l,y0,zl1, l,y1,zl1, l,y1,zl0);
      }
    }
  }
}

void quad3(float x1,float y1,float z1, float x2,float y2,float z2,
           float x3,float y3,float z3, float x4,float y4,float z4) {
  beginShape();
  vertex(x1,y1,z1); vertex(x2,y2,z2); vertex(x3,y3,z3); vertex(x4,y4,z4);
  endShape(CLOSE);
}

// Applies a rotation of sliceAngle around targetAxis.
// The sign of rotationAxis (±1) corrects for cross-product handedness so the
// slice always moves in the direction the user is dragging.
void applySliceRotation() {
  PVector ra = rotationAxis;            // snapshot — an input event on another thread may null it mid-frame
  if (ra == null || targetAxis < 0) return;
  float sign = (targetAxis == 0) ? ra.x
             : (targetAxis == 1) ? ra.y : ra.z;
  switch (targetAxis) {
    case 0: rotateX(sign * sliceAngle); break;
    case 1: rotateY(sign * sliceAngle); break;
    case 2: rotateZ(sign * sliceAngle); break;
  }
}

// Applies the transpose (= inverse) of a pure-rotation PMatrix3D to a PVector
PVector applyTranspose(PMatrix3D m, PVector v) {
  return new PVector(
    m.m00 * v.x + m.m10 * v.y + m.m20 * v.z,
    m.m01 * v.x + m.m11 * v.y + m.m21 * v.z,
    m.m02 * v.x + m.m12 * v.y + m.m22 * v.z
  );
}
