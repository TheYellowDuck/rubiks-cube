// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Required Notice: Copyright (c) 2026 George Zhang — https://github.com/TheYellowDuck

// ── Panel ─────────────────────────────────────────────────────────────────
// All y-values are absolute screen coordinates shared between drawPanel() and handlePanelClick()

final int PAD   = 16;   // horizontal padding inside panel
final int T_Y   = 44;   // timer card top
final int SC_Y  = 144;  // scramble row top (full width)
final int SV_Y  = 184;  // solve / step row top
final int A_Y   = 224;  // reset / undo row top
final int MV_Y  = 290;  // move grid top
final int MV_RH = 28;   // move row height

void drawPanel() {
  int px = PANEL_X, pw = width - px, iw = pw - PAD*2;
  textFont(fontUI);

  // Background
  fill(PNL); noStroke(); rect(px, 0, pw, height);
  fill(BORD); noStroke(); rect(px, 0, 1, height);

  // ── Header ──────────────────────────────────────────────────────────
  fill(T3); textAlign(LEFT, CENTER); textSize(10);
  text("RUBIK'S CUBE", px + PAD, 26);

  // Theme toggle
  int tw = 48, th = 22, tx = px + pw - PAD - tw, ty = 15;
  boolean tHov = hit(tx, ty, tw, th);
  fill(tHov ? SURF2 : SURF); noStroke(); rect(tx, ty, tw, th, 11);
  fill(T2); textAlign(CENTER, CENTER); textSize(10);
  text(darkMode ? "Light" : "Dark", tx + tw/2, ty + th/2);

  // ── Timer card ──────────────────────────────────────────────────────
  fill(SURF); noStroke(); rect(px + PAD, T_Y, iw, 90, 14);

  long elapsed = timerRunning ? (millis()-startMs) : (solved ? solvedMs : 0);
  textFont(fontMono);
  fill(solved ? SUCCESS : T1);
  textSize(40); textAlign(CENTER, TOP);
  text(fmtTime(elapsed), px + pw/2, T_Y + 10);
  textFont(fontUI);

  color moveLabelColor = solved ? lerpColor(SUCCESS, T2, 0.45) : T2;
  fill(moveLabelColor); textSize(11); textAlign(CENTER, TOP);
  text(moveCount + (moveCount == 1 ? " move" : " moves"), px + pw/2, T_Y + 58);
  // status line: solved badge, otherwise the saved best time
  textSize(11); textAlign(CENTER, TOP);
  if (solved) {
    fill(SUCCESS);
    text(bestMs > 0 ? "Solved  ✓   ·   best " + fmtTime(bestMs) : "Solved  ✓", px + pw/2, T_Y + 74);
  } else if (bestMs > 0) {
    fill(T2);
    text("best  " + fmtTime(bestMs), px + pw/2, T_Y + 74);
  }

  int hw = (iw - 8) / 2;   // half-row button width, shared by the rows below

  // ── Scramble (full width) ─────────────────────────────────────────────
  solidBtn("Scramble", px + PAD, SC_Y, iw, 34, ACCENT, true);

  // ── Solve / Step ──────────────────────────────────────────────────────
  // Shared plan: Solve auto-plays it (toggles to Pause); Step advances one move
  // and pauses auto-play. The count ticks down for both.
  boolean autoSolving = (seqKind == K_SOLVE && autoPlay);
  String solveLabel = planComputing ? "Solving…" : (autoSolving ? "Pause" : "Solve");
  solidBtn(solveLabel, px + PAD, SV_Y, hw, 34, SUCCESS, !solved);

  boolean planLoaded = (seqKind == K_SOLVE && !moveQueue.isEmpty());
  String stepLabel = planComputing ? "…" : (planLoaded ? "Step " + moveQueue.size() : "Step");
  secondaryBtn(stepLabel, px + PAD + hw + 8, SV_Y, hw, 34, !solved);

  // ── Reset / Undo ────────────────────────────────────────────────────
  ghostBtn("Reset", px + PAD,          A_Y, hw, 30, true);
  ghostBtn("Undo",  px + PAD + hw + 8, A_Y, hw, 30, !history.isEmpty());

  // ── Moves ────────────────────────────────────────────────────────────
  fill(T3); textSize(10); textAlign(LEFT, TOP);
  text("MOVES", px + PAD, MV_Y - 14);

  String[][] mv  = { {"U","U'"}, {"D","D'"}, {"R","R'"}, {"L","L'"}, {"F","F'"}, {"B","B'"} };
  float[][] dirs = { {0,-1,0},  {0,1,0},   {1,0,0},   {-1,0,0},  {0,0,1},   {0,0,-1}  };
  int mbw = hw;
  for (int i = 0; i < 6; i++) {
    color lCol = faceButtonColor(physicalFace(dirs[i][0], dirs[i][1], dirs[i][2]));
    movBtn(mv[i][0], px + PAD,           MV_Y + i*MV_RH, mbw, 26, lCol);
    movBtn(mv[i][1], px + PAD + mbw + 8, MV_Y + i*MV_RH, mbw, 26, lCol);
  }

  // ── Footer ───────────────────────────────────────────────────────────
  int fy = MV_Y + 6*MV_RH + 12;
  fill(T3); textSize(9); textAlign(CENTER, TOP);
  text("drag face to turn  ·  " + MOD_KEY + "/right-drag spin", px + pw/2, fy);
  text("keys u – b move  ·  Shift = prime", px + pw/2, fy + 13);
  text("space scramble  ·  s solve  ·  n step", px + pw/2, fy + 26);
}

// Primary call-to-action button (filled, pill-shaped).
void solidBtn(String label, float x, float y, float w, float h, color base, boolean enabled) {
  boolean over = enabled && hit(x, y, w, h);
  fill(!enabled ? SURF : (over ? lerpColor(base, color(255), 0.12) : base));
  noStroke(); rect(x, y, w, h, h*0.5);
  fill(enabled ? color(255) : T3); textAlign(CENTER, CENTER); textSize(13);
  text(label, x + w/2, y + h/2);
}

// Secondary action button (subtle surface fill, accent text) — used for Step.
void secondaryBtn(String label, float x, float y, float w, float h, boolean enabled) {
  boolean over = enabled && hit(x, y, w, h);
  fill(over ? SURF2 : SURF); noStroke(); rect(x, y, w, h, h*0.5);
  fill(enabled ? ACCENT : T3); textAlign(CENTER, CENTER); textSize(13);
  text(label, x + w/2, y + h/2);
}

void ghostBtn(String label, float x, float y, float w, float h, boolean enabled) {
  boolean over = enabled && hit(x, y, w, h);
  fill(over ? SURF2 : SURF); noStroke(); rect(x, y, w, h, 8);
  fill(!enabled ? T3 : (over ? T1 : T2)); textAlign(CENTER, CENTER); textSize(12);
  text(label, x + w/2, y + h/2);
}

void movBtn(String label, float x, float y, float w, float h, color lCol) {
  boolean over = hit(x, y, w, h);
  fill(over ? SURF2 : SURF); noStroke(); rect(x, y, w, h, 7);
  fill(over ? lerpColor(lCol, color(255), 0.25) : lCol);
  textAlign(CENTER, CENTER); textSize(13);
  text(label, x + w/2, y + h/2);
}

void handlePanelClick() {
  int px = PANEL_X, pw = width - px, iw = pw - PAD*2;
  int hw = (iw - 8) / 2, mbw = hw;
  int tw = 48, tx = px + pw - PAD - tw;

  if (hit(tx,              15,    tw, 22)) { darkMode = !darkMode; startThemeTransition(); savePrefs(); return; }
  if (hit(px+PAD,          SC_Y,  iw, 34)) { doScramble(); return; }
  if (hit(px+PAD,          SV_Y,  hw, 34)) { doSolve();    return; }
  if (hit(px+PAD+hw+8,     SV_Y,  hw, 34)) { doStep();     return; }
  if (hit(px+PAD,          A_Y,   hw, 30)) { doReset();    return; }
  if (hit(px+PAD+hw+8,     A_Y,   hw, 30)) { doUndo();     return; }

  float[][] dirs = {{0,-1,0},{0,1,0},{1,0,0},{-1,0,0},{0,0,1},{0,0,-1}};
  for (int i = 0; i < 6; i++) {
    String face = physicalFace(dirs[i][0], dirs[i][1], dirs[i][2]);
    if (hit(px+PAD,       MV_Y+i*MV_RH, mbw, 26)) { execKeyMove(face, false); return; }
    if (hit(px+PAD+mbw+8, MV_Y+i*MV_RH, mbw, 26)) { execKeyMove(face, true);  return; }
  }
}

boolean hit(float x, float y, float w, float h) {
  return mouseX>=x && mouseX<=x+w && mouseY>=y && mouseY<=y+h;
}
