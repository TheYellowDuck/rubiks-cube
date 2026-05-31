// ── Cubelet class ─────────────────────────────────────────────────────────
class Cubelet {
  int gx, gy, gz;          // grid position: each component ∈ {-1, 0, 1}
  PMatrix3D orientation;   // accumulated world-space rotation history (identity = home pose)

  Cubelet(int gx, int gy, int gz) {
    this.gx = gx;  this.gy = gy;  this.gz = gz;
    orientation = new PMatrix3D();  // identity — no rotation yet
  }
}
