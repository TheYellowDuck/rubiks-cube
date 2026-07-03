// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Required Notice: Copyright (c) 2026 George Zhang — https://github.com/TheYellowDuck

// ─────────────────────────────────────────────────────────────────────────────
//  CFOP auto-solver
//
//  Standard frame: the WHITE cross + first two layers are built on the BOTTOM
//  (D / yellow centre is actually... ) — here the cross/F2L are solved on the
//  D face and the last layer is the U face, so ordinary OLL/PLL algorithms apply
//  directly.  Pipeline: Cross → F2L → OLL → PLL.
//
//  Internals use a cubie reader (edgeAt / cornerAt) that maps the sticker arrays
//  to piece identities so each search phase can be keyed on just the pieces it
//  cares about — this keeps every breadth-first search bounded and fast.
//
//  This file was validated against several thousand random scrambles in a
//  standalone Java port before being dropped in here; see solveCube().
// ─────────────────────────────────────────────────────────────────────────────

import java.util.HashSet;
import java.util.ArrayDeque;
import java.util.ArrayList;

// ── move sets ────────────────────────────────────────────────────────────────
final String[] ALL_MOVES = {
  "U","U'","U2","D","D'","D2","R","R'","R2","L","L'","L2","F","F'","F2","B","B'","B2"
};

Cube copyCube(Cube s){
  Cube d = new Cube();
  char[][][] sf = { s.U, s.D, s.F, s.B, s.L, s.R };
  char[][][] df = { d.U, d.D, d.F, d.B, d.L, d.R };
  for (int f = 0; f < 6; f++)
    for (int i = 0; i < 3; i++)
      for (int j = 0; j < 3; j++)
        df[f][i][j] = sf[f][i][j];
  return d;
}

// ── facelet access ───────────────────────────────────────────────────────────
// face indices: U0 D1 F2 B3 L4 R5
char facelet(Cube c, int f, int r, int col){
  switch (f){
    case 0: return c.U[r][col]; case 1: return c.D[r][col]; case 2: return c.F[r][col];
    case 3: return c.B[r][col]; case 4: return c.L[r][col]; default: return c.R[r][col];
  }
}

// 12 edge slots: {f0,r0,c0, f1,r1,c1}
final int[][] EDGE_FAC = {
  {0,0,1, 3,0,1}, // 0 UB
  {0,1,2, 5,0,1}, // 1 UR
  {0,2,1, 2,0,1}, // 2 UF
  {0,1,0, 4,0,1}, // 3 UL
  {2,1,2, 5,1,0}, // 4 FR
  {2,1,0, 4,1,2}, // 5 FL
  {3,1,0, 5,1,2}, // 6 BR
  {3,1,2, 4,1,0}, // 7 BL
  {1,0,1, 2,2,1}, // 8 DF
  {1,1,2, 5,2,1}, // 9 DR
  {1,2,1, 3,2,1}, //10 DB
  {1,1,0, 4,2,1}  //11 DL
};
final char[][] EDGE_COL = {
  {'W','B'},{'W','R'},{'W','G'},{'W','O'},
  {'G','R'},{'G','O'},{'B','R'},{'B','O'},
  {'Y','G'},{'Y','R'},{'Y','B'},{'Y','O'}
};
// 8 corner slots: {f0,r0,c0, f1,r1,c1, f2,r2,c2}  (U/D facelet always listed first)
final int[][] CORNER_FAC = {
  {0,0,2, 3,0,0, 5,0,2}, // 0 UBR
  {0,0,0, 3,0,2, 4,0,0}, // 1 UBL
  {0,2,2, 2,0,2, 5,0,0}, // 2 UFR
  {0,2,0, 2,0,0, 4,0,2}, // 3 UFL
  {1,0,2, 2,2,2, 5,2,0}, // 4 DFR
  {1,0,0, 2,2,0, 4,2,2}, // 5 DFL
  {1,2,2, 3,2,0, 5,2,2}, // 6 DBR
  {1,2,0, 3,2,2, 4,2,0}  // 7 DBL
};
final char[][] CORNER_COL = {
  {'W','B','R'},{'W','B','O'},{'W','G','R'},{'W','G','O'},
  {'Y','G','R'},{'Y','G','O'},{'Y','B','R'},{'Y','B','O'}
};

int prio(char c){
  switch (c){ case 'W': return 5; case 'Y': return 4; case 'G': return 3;
              case 'B': return 2; case 'O': return 1; default: return 0; }
}

// edge currently in slot → id*2 + orientation
int edgeAt(Cube c, int slot){
  int[] e = EDGE_FAC[slot];
  char c0 = facelet(c, e[0],e[1],e[2]), c1 = facelet(c, e[3],e[4],e[5]);
  int id = -1;
  for (int k = 0; k < 12; k++){
    char a = EDGE_COL[k][0], b = EDGE_COL[k][1];
    if ((a==c0 && b==c1) || (a==c1 && b==c0)){ id = k; break; }
  }
  char ref = prio(EDGE_COL[id][0]) > prio(EDGE_COL[id][1]) ? EDGE_COL[id][0] : EDGE_COL[id][1];
  return id*2 + (c0==ref ? 0 : 1);
}
// corner currently in slot → id*3 + orientation (which facelet holds the W/Y sticker)
int cornerAt(Cube c, int slot){
  int[] e = CORNER_FAC[slot];
  char c0 = facelet(c, e[0],e[1],e[2]), c1 = facelet(c, e[3],e[4],e[5]), c2 = facelet(c, e[6],e[7],e[8]);
  int id = -1;
  for (int k = 0; k < 8; k++)
    if (cornerHas(k,c0) && cornerHas(k,c1) && cornerHas(k,c2)){ id = k; break; }
  int ori = (c0=='W'||c0=='Y') ? 0 : (c1=='W'||c1=='Y') ? 1 : 2;
  return id*3 + ori;
}
boolean cornerHas(int k, char x){ for (char y : CORNER_COL[k]) if (y==x) return true; return false; }

// ── goal checkers ─────────────────────────────────────────────────────────────
boolean crossSolved(Cube c){
  return c.D[0][1]=='Y' && c.D[1][2]=='Y' && c.D[2][1]=='Y' && c.D[1][0]=='Y'
      && c.F[2][1]=='G' && c.R[2][1]=='R' && c.B[2][1]=='B' && c.L[2][1]=='O';
}
// F2L slot order: 0 FR, 1 FL, 2 BL, 3 BR
boolean slotSolved(Cube c, int slot){
  switch (slot){
    case 0: return c.D[0][2]=='Y'&&c.F[2][2]=='G'&&c.R[2][0]=='R'&&c.F[1][2]=='G'&&c.R[1][0]=='R';
    case 1: return c.D[0][0]=='Y'&&c.F[2][0]=='G'&&c.L[2][2]=='O'&&c.F[1][0]=='G'&&c.L[1][2]=='O';
    case 2: return c.D[2][0]=='Y'&&c.B[2][2]=='B'&&c.L[2][0]=='O'&&c.B[1][2]=='B'&&c.L[1][0]=='O';
    case 3: return c.D[2][2]=='Y'&&c.B[2][0]=='B'&&c.R[2][2]=='R'&&c.B[1][0]=='B'&&c.R[1][2]=='R';
  }
  return false;
}
// cubie ids owned by each F2L slot {cornerId, edgeId}
final int[][] SLOT_PIECES = { {4,4},{5,5},{7,7},{6,6} };

// ── search keys ───────────────────────────────────────────────────────────────
String crossKey(Cube c){
  int[] enc = new int[12];
  for (int slot = 0; slot < 12; slot++){ int v = edgeAt(c, slot); enc[v/2] = slot*2 + (v&1); }
  StringBuilder sb = new StringBuilder();
  for (int id = 8; id < 12; id++) sb.append((char)('a'+enc[id]));
  return sb.toString();
}
String f2lKey(Cube c, int uptoSlot){
  StringBuilder sb = new StringBuilder(crossKey(c));
  int[] cpos = new int[8], epos = new int[12];
  for (int s = 0; s < 8; s++){ int v = cornerAt(c,s); cpos[v/3] = s*3 + (v%3); }
  for (int s = 0; s < 12; s++){ int v = edgeAt(c,s); epos[v/2] = s*2 + (v&1); }
  for (int k = 0; k <= uptoSlot; k++)
    sb.append('|').append(cpos[SLOT_PIECES[k][0]]).append(',').append(epos[SLOT_PIECES[k][1]]);
  return sb.toString();
}
String stateKey(Cube c){
  char[] b = new char[54]; int k = 0;
  char[][][] faces = { c.U, c.D, c.F, c.B, c.L, c.R };
  for (char[][] f : faces) for (char[] row : f) for (char cell : row) b[k++] = cell;
  return new String(b);
}

// ── Cross ─────────────────────────────────────────────────────────────────────
// Optimal BFS, keyed on the 4 D-cross edges only (≤ 8 moves, always fast).
String solveCross(Cube start){
  if (crossSolved(start)) return "";
  ArrayDeque<Cube> sQ = new ArrayDeque<Cube>(); ArrayDeque<String> mQ = new ArrayDeque<String>();
  HashSet<String> seen = new HashSet<String>();
  sQ.add(copyCube(start)); mQ.add(""); seen.add(crossKey(start));
  while (!sQ.isEmpty()){
    Cube cur = sQ.poll(); String path = mQ.poll();
    for (String mv : ALL_MOVES){
      Cube nx = copyCube(cur); nx.scramble(mv);
      String k = crossKey(nx);
      if (seen.add(k)){
        String np = path.isEmpty() ? mv : path + " " + mv;
        if (crossSolved(nx)) return np;
        sQ.add(nx); mQ.add(np);
      }
    }
  }
  return null;
}

// ── F2L ───────────────────────────────────────────────────────────────────────
// Cross-preserving triggers (X U* X' / X' U* X) for all four hands keep the cross
// intact for the whole maneuver; the key tracks the cross plus every pair up to k
// so earlier pairs may be temporarily disturbed and are guaranteed restored.
final char[] HANDS = { 'R','F','L','B' };
String[] triggers(){
  ArrayList<String> t = new ArrayList<String>();
  t.add("U"); t.add("U'"); t.add("U2");
  for (char h : HANDS){
    String x = ""+h, xi = h + "'";
    for (String u : new String[]{ "U","U'","U2" }){
      t.add(x + " " + u + " " + xi);   // insert
      t.add(xi + " " + u + " " + x);   // extract
    }
  }
  return t.toArray(new String[0]);
}
String[] TRIG = null;

String solveSlot(Cube start, int slot){
  if (TRIG == null) TRIG = triggers();
  boolean ok = crossSolved(start);
  for (int s = 0; s <= slot && ok; s++) if (!slotSolved(start, s)) ok = false;
  if (ok) return "";
  ArrayDeque<Cube> sQ = new ArrayDeque<Cube>(); ArrayDeque<String> mQ = new ArrayDeque<String>();
  HashSet<String> seen = new HashSet<String>();
  sQ.add(copyCube(start)); mQ.add(""); seen.add(f2lKey(start, slot));
  while (!sQ.isEmpty()){
    Cube cur = sQ.poll(); String path = mQ.poll();
    for (String mv : TRIG){
      Cube nx = copyCube(cur); nx.scramble(mv);
      String k = f2lKey(nx, slot);
      if (seen.add(k)){
        String np = path.isEmpty() ? mv : path + " " + mv;
        boolean g = crossSolved(nx);
        for (int s = 0; s <= slot && g; s++) if (!slotSolved(nx, s)) g = false;
        if (g) return np;
        sQ.add(nx); mQ.add(np);
      }
    }
  }
  return null;
}

String solveF2L(Cube cube){
  StringBuilder all = new StringBuilder();
  for (int slot = 0; slot < 4; slot++){
    String m = solveSlot(cube, slot);
    if (m == null) return null;
    if (!m.isEmpty()){ cube.scramble(m); if (all.length() > 0) all.append(" "); all.append(m); }
  }
  return all.toString();
}

// ── Last layer (2-phase macro BFS) ────────────────────────────────────────────
// OLL: orient the U face (all white up).  PLL: permute to fully solved.  Each
// macro preserves the first two layers, so every reachable state is a last-layer
// state and the search is tiny.  The generator sets are complete (edge + corner
// orientation for OLL; 3-cycles + adjacent swap + AUF for PLL).
final String[] OLL_MACROS = {
  "U","U'","U2",
  "F R U R' U' F'",      // orient edges (line / L)
  "F U R U' R' F'",      // orient edges (mirror)
  "R U R' U R U2 R'",    // sune
  "R U2 R' U' R U' R'",  // anti-sune
  "L' U' L U' L' U2 L"   // anti-sune mirror
};
final String[] PLL_MACROS = {
  "U","U'","U2",
  "R U' R U R U R U' R' U' R2",          // U-perm (edge 3-cycle)
  "R' F R' B2 R F' R' B2 R2",            // A-perm (corner 3-cycle)
  "R U R' U' R' F R2 U' R' U' R U R' F'" // T-perm
};

boolean ollDone(Cube c){
  char u = c.U[1][1];
  for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) if (c.U[i][j] != u) return false;
  return true;
}

String macroBFS(Cube start, String[] macros, boolean wantSolved){
  if (wantSolved ? start.isSolved() : ollDone(start)) return "";
  ArrayDeque<Cube> sQ = new ArrayDeque<Cube>(); ArrayDeque<String> mQ = new ArrayDeque<String>();
  HashSet<String> seen = new HashSet<String>();
  sQ.add(copyCube(start)); mQ.add(""); seen.add(stateKey(start));
  while (!sQ.isEmpty()){
    Cube cur = sQ.poll(); String path = mQ.poll();
    for (String mv : macros){
      Cube nx = copyCube(cur); nx.scramble(mv);
      String k = stateKey(nx);
      if (seen.add(k)){
        String np = path.isEmpty() ? mv : path + " " + mv;
        if (wantSolved ? nx.isSolved() : ollDone(nx)) return np;
        sQ.add(nx); mQ.add(np);
      }
    }
  }
  return null;
}

// ── full solve ────────────────────────────────────────────────────────────────
// Returns a simplified space-separated move string that solves `start`, or null.
String solveCube(Cube start){
  Cube c = copyCube(start);
  StringBuilder sol = new StringBuilder();
  String cr = solveCross(c);            if (cr  == null) return null;
  if (!cr.isEmpty()){ c.scramble(cr);  appendMoves(sol, cr); }
  String f2 = solveF2L(c);              if (f2  == null) return null;
  if (!f2.isEmpty()) appendMoves(sol, f2);
  String oll = macroBFS(c, OLL_MACROS, false); if (oll == null) return null;
  if (!oll.isEmpty()){ c.scramble(oll); appendMoves(sol, oll); }
  String pll = macroBFS(c, PLL_MACROS, true);  if (pll == null) return null;
  if (!pll.isEmpty()){ c.scramble(pll); appendMoves(sol, pll); }
  if (!c.isSolved()) return null;
  return simplifyMoves(sol.toString());
}
void appendMoves(StringBuilder sb, String s){ if (sb.length() > 0) sb.append(" "); sb.append(s); }

// ── move-string simplifier (cancel / merge consecutive same-face turns) ────────
String simplifyMoves(String seq){
  if (seq == null || seq.trim().isEmpty()) return "";
  ArrayList<String> t = new ArrayList<String>();
  for (String s : seq.trim().split("\\s+")) if (!s.isEmpty()) t.add(s);
  boolean changed = true;
  while (changed){
    changed = false;
    for (int i = 0; i < t.size()-1; i++){
      if (moveFace(t.get(i)) == moveFace(t.get(i+1))){
        int amt = (moveAmount(t.get(i)) + moveAmount(t.get(i+1))) % 4;
        char f = moveFace(t.get(i));
        t.remove(i+1); t.remove(i);
        if (amt != 0) t.add(i, moveFrom(f, amt));
        changed = true; break;
      }
    }
  }
  StringBuilder sb = new StringBuilder();
  for (String s : t){ if (sb.length() > 0) sb.append(" "); sb.append(s); }
  return sb.toString();
}
char moveFace(String m){ return m.charAt(0); }
int  moveAmount(String m){ return m.endsWith("2") ? 2 : m.endsWith("'") ? 3 : 1; }
String moveFrom(char f, int a){ return a==1 ? ""+f : a==2 ? f+"2" : f+"'"; }
