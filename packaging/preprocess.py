#!/usr/bin/env python3
"""Turn the Processing sketch (*.pde tabs) into a single compilable PApplet
subclass — a minimal stand-in for Processing's preprocessor so the sketch can be
built with plain javac + jpackage (no Processing IDE needed).

Usage: preprocess.py <sketch_dir> <output.java>
"""
import re, sys, glob, os

def main(sketch_dir, out_path):
    order = ["RubiksCube.pde"]                         # main tab first
    files = order + sorted(f for f in
                           (os.path.basename(p) for p in glob.glob(os.path.join(sketch_dir, "*.pde")))
                           if f not in order)
    imports, bodies = set(), []
    for fn in files:
        text = open(os.path.join(sketch_dir, fn)).read()
        kept = []
        for line in text.splitlines():
            if line.strip().startswith("import "):
                imports.add(line.strip())
            else:
                kept.append(line)
        bodies.append("// ===== %s =====\n%s" % (fn, "\n".join(kept)))
    body = "\n\n".join(bodies)

    # size()/smooth() must live in settings() for P3D
    body = body.replace("  size(800, 640, P3D);\n", "").replace("  smooth(4);\n", "")
    # `color` type -> int  (leave color(...) calls alone)
    body = re.sub(r"\bcolor\b(?!\s*\()", "int", body)
    # Processing treats decimal/scientific literals as float
    body = re.sub(r"(?<![\w.])(\d+\.\d+([eE][+-]?\d+)?)(?![fFdD\w.])", r"\1f", body)
    body = re.sub(r"(?<![\w.])(\d+[eE][+-]?\d+)(?![fFdD\w.])", r"\1f", body)
    # PApplet callbacks must be public to override; methods invoked by name via
    # Processing's thread() must be public so reflection (getMethod) can find them.
    for m in ["setup","draw","mousePressed","mouseDragged","mouseReleased",
              "mouseMoved","mouseExited","keyPressed","keyReleased",
              "computePlanAsync","runSelfTest"]:
        body = re.sub(r"\nvoid " + m + r"\(\)", "\npublic void " + m + "()", body)

    header = ("import processing.core.*;\nimport processing.data.*;\n"
              "import processing.opengl.*;\nimport java.util.*;\n"
              + "\n".join(sorted(imports)) + "\n\n")
    cls = ("public class RubiksCube extends PApplet {\n"
           "  public void settings() { size(800, 640, P3D); smooth(4); }\n"
           "  static public void main(String[] a) { PApplet.main(\"RubiksCube\"); }\n\n"
           + body + "\n}\n")
    open(out_path, "w").write(header + cls)
    print("wrote", out_path)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("usage: preprocess.py <sketch_dir> <output.java>")
    main(sys.argv[1], sys.argv[2])
