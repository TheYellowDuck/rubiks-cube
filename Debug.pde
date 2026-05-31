// ── Solver self-check ─────────────────────────────────────────────────────────
// Press 't' to run a batch of random scrambles through solveCube() on a worker
// thread and print the result to the console.  A regression guard for the cube
// move tables + solver (both have subtle correctness requirements).

boolean selfTestRunning = false;

void startSelfTest() {
  if (selfTestRunning) return;
  selfTestRunning = true;
  println("[self-test] running 200 random solves…");
  thread("runSelfTest");
}

void runSelfTest() {
  int N = 200, fail = 0;
  long t0 = millis();
  java.util.Random rnd = new java.util.Random();
  String[] faces = {"U","D","R","L","F","B"};
  String[] mods  = {"", "'", "2"};

  for (int i = 0; i < N; i++) {
    StringBuilder sb = new StringBuilder();
    int last = -1;
    for (int k = 0; k < 25; k++) {
      int f; do { f = rnd.nextInt(6); } while (f == last); last = f;
      sb.append(faces[f]).append(mods[rnd.nextInt(3)]).append(' ');
    }
    String scr = sb.toString();

    Cube c = new Cube(); c.scramble(scr);
    String sol = solveCube(c);

    Cube v = new Cube(); v.scramble(scr);
    if (sol != null) v.scramble(sol);
    if (sol == null || !v.isSolved()) {
      fail++;
      if (fail <= 5) println("[self-test] FAIL: " + scr.trim());
    }
  }

  println("[self-test] " + (N - fail) + "/" + N + " solved  (" + (millis() - t0) + " ms)");
  selfTestRunning = false;
}
