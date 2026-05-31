// ── Persistence ───────────────────────────────────────────────────────────────
// Best solve time and the theme choice are stored in a small JSON file kept WITH
// the app (next to its jar — i.e. inside the .app / app folder), so nothing is
// scattered in the user's home directory.  If that location isn't writable (e.g.
// the app was moved somewhere read-only), it falls back to the home directory.

long bestMs = 0;   // best (lowest) solve time in ms; 0 = none recorded yet

String prefsPath() {
  try {
    java.io.File src = new java.io.File(getClass().getProtectionDomain().getCodeSource().getLocation().toURI());
    java.io.File dir = src.isDirectory() ? src : src.getParentFile();   // the app/ folder for a packaged build
    if (dir != null && dir.canWrite()) return new java.io.File(dir, "prefs.json").getPath();
  } catch (Exception e) { /* fall through to home dir */ }
  return System.getProperty("user.home") + java.io.File.separator + ".rubikscube_prefs.json";
}

void loadPrefs() {
  try {
    if (!new java.io.File(prefsPath()).exists()) return;
    JSONObject j = loadJSONObject(prefsPath());
    if (j.hasKey("bestMs"))   bestMs   = j.getLong("bestMs");
    if (j.hasKey("darkMode")) darkMode = j.getBoolean("darkMode");
  } catch (Exception e) { /* corrupt/old file — ignore, keep defaults */ }
}

void savePrefs() {
  try {
    JSONObject j = new JSONObject();
    j.setLong("bestMs", bestMs);
    j.setBoolean("darkMode", darkMode);
    saveJSONObject(j, prefsPath());
  } catch (Exception e) { }
}

// Called when a solve completes; keeps the lowest time and persists it.
void recordBestTime(long ms) {
  if (ms <= 0) return;
  if (bestMs == 0 || ms < bestMs) { bestMs = ms; savePrefs(); }
}
