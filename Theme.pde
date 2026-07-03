// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Required Notice: Copyright (c) 2026 George Zhang — https://github.com/TheYellowDuck

// Theme transition state — the 10 live colours (BG…SUCCESS) are lerped from the
// old palette to the new one over THEME_MS when the theme is toggled.
int[]   palFrom = new int[10];
int[]   palTo   = new int[10];
boolean themeAnim = false;
long    themeAnimStart = 0;
final int THEME_MS = 300;

void fillPalette(int[] p, boolean dark) {
  if (dark) {
    p[0]=color( 10,  10,  16); p[1]=color( 20,  20,  30); p[2]=color( 32,  32,  46);
    p[3]=color( 42,  42,  58); p[4]=color( 50,  50,  68); p[5]=color(236, 236, 243);
    p[6]=color(115, 115, 138); p[7]=color( 58,  58,  78); p[8]=color( 10, 132, 255);
    p[9]=color( 48, 209,  88);
  } else {
    p[0]=color(232, 232, 240); p[1]=color(252, 252, 255); p[2]=color(220, 220, 232);
    p[3]=color(206, 206, 220); p[4]=color(190, 190, 208); p[5]=color( 18,  18,  28);
    p[6]=color( 84,  84, 104); p[7]=color(150, 150, 170); p[8]=color(  0, 122, 255);
    p[9]=color( 38, 178,  74);
  }
}

void applyPalette(int[] p) {
  BG=p[0]; PNL=p[1]; SURF=p[2]; SURF2=p[3]; BORD=p[4];
  T1=p[5]; T2=p[6]; T3=p[7]; ACCENT=p[8]; SUCCESS=p[9];
}

// Instant — used at startup.
void setTheme() {
  fillPalette(palTo, darkMode);
  applyPalette(palTo);
  themeAnim = false;
}

// Animated — used when the user toggles the theme: fade from the current colours.
void startThemeTransition() {
  palFrom[0]=BG; palFrom[1]=PNL; palFrom[2]=SURF; palFrom[3]=SURF2; palFrom[4]=BORD;
  palFrom[5]=T1; palFrom[6]=T2; palFrom[7]=T3; palFrom[8]=ACCENT; palFrom[9]=SUCCESS;
  fillPalette(palTo, darkMode);
  themeAnim = true;
  themeAnimStart = millis();
}

// Called every frame from draw(): advances the colour fade if one is running.
void updateTheme() {
  if (!themeAnim) return;
  float t = constrain((float)(millis() - themeAnimStart) / THEME_MS, 0, 1);
  float e = t < 0.5 ? 2*t*t : -1 + (4 - 2*t)*t;   // ease-in-out quad
  int[] cur = new int[10];
  for (int i = 0; i < 10; i++) cur[i] = lerpColor(palFrom[i], palTo[i], e);
  applyPalette(cur);
  if (t >= 1.0) { applyPalette(palTo); themeAnim = false; }
}

// ── Cube colours ──────────────────────────────────────────────────────────────
// Two palettes, both keyed off the same six faces:
//   faceColor(char)       — the actual sticker colour painted on the 3D cube
//   faceButtonColor(face) — a legibility-tuned variant for the panel move labels
//                           (e.g. white → grey, so it reads on a surface button)

color faceColor(char c) {
  switch (c) {
    case 'W': return color(255, 255, 255);
    case 'Y': return color(255, 213,   0);
    case 'G': return color(  0, 172,   0);
    case 'B': return color(  0,  78, 218);
    case 'O': return color(255, 128,   0);
    case 'R': return color(208,   0,   0);
    default:  return color(70);
  }
}

color faceButtonColor(String face) {
  switch (face) {
    case "U": return color(195, 195, 195);
    case "D": return color(228, 190,   0);
    case "R": return color(224,  40,  40);
    case "L": return color(252, 128,  16);
    case "F": return color( 16, 172,  16);
    case "B": return color( 36, 100, 250);
    default:  return color(128);
  }
}

boolean detectOSDarkMode() {
  try {
    String os = System.getProperty("os.name").toLowerCase();
    if (os.contains("mac")) {
      Process p = Runtime.getRuntime().exec(new String[]{"defaults", "read", "-g", "AppleInterfaceStyle"});
      p.waitFor();
      return p.exitValue() == 0;  // exit 0 = "Dark" was found
    } else if (os.contains("nux") || os.contains("nix")) {
      // GNOME 42+: color-scheme preference
      Process p = Runtime.getRuntime().exec(new String[]{"gsettings", "get", "org.gnome.desktop.interface", "color-scheme"});
      p.waitFor();
      java.util.Scanner sc = new java.util.Scanner(p.getInputStream());
      if (sc.hasNextLine() && sc.nextLine().contains("dark")) return true;
      // Older GNOME: check GTK theme name
      p = Runtime.getRuntime().exec(new String[]{"gsettings", "get", "org.gnome.desktop.interface", "gtk-theme"});
      p.waitFor();
      sc = new java.util.Scanner(p.getInputStream());
      if (sc.hasNextLine() && sc.nextLine().toLowerCase().contains("dark")) return true;
    } else if (os.contains("win")) {
      Process p = Runtime.getRuntime().exec(
        "reg query \"HKCU\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize\" /v AppsUseLightTheme");
      p.waitFor();
      java.util.Scanner sc = new java.util.Scanner(p.getInputStream());
      while (sc.hasNextLine()) {
        String line = sc.nextLine();
        if (line.contains("AppsUseLightTheme") && line.contains("0x0")) return true;
      }
    }
  } catch (Exception e) {}
  return false;
}
