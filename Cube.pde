class Cube {
  char[][] U, D, F, B, L, R;

  Cube() {
    U = filledFace('W');
    D = filledFace('Y');
    F = filledFace('G');
    B = filledFace('B');
    L = filledFace('O');
    R = filledFace('R');
  }

  char[][] filledFace(char c) {
    char[][] f = new char[3][3];
    for (int i = 0; i < 3; i++)
      for (int j = 0; j < 3; j++)
        f[i][j] = c;
    return f;
  }

  void rotateFaceCW(char[][] f) {
    char tmp;
    tmp = f[0][0]; f[0][0] = f[2][0]; f[2][0] = f[2][2]; f[2][2] = f[0][2]; f[0][2] = tmp;
    tmp = f[0][1]; f[0][1] = f[1][0]; f[1][0] = f[2][1]; f[2][1] = f[1][2]; f[1][2] = tmp;
  }

  void rotateFaceCCW(char[][] f) {
    rotateFaceCW(f); rotateFaceCW(f); rotateFaceCW(f);
  }

  // U move: top face CW, cycle F[0] -> L[0] -> B[0] -> R[0] -> F[0] (top rows align, no reversal)
  void moveU() {
    rotateFaceCW(U);
    char[] tmp = new char[3];
    for (int i = 0; i < 3; i++) tmp[i] = F[0][i];
    for (int i = 0; i < 3; i++) F[0][i] = R[0][i];
    for (int i = 0; i < 3; i++) R[0][i] = B[0][i];
    for (int i = 0; i < 3; i++) B[0][i] = L[0][i];
    for (int i = 0; i < 3; i++) L[0][i] = tmp[i];
  }

  void moveUPrime() {
    rotateFaceCCW(U);
    char[] tmp = new char[3];
    for (int i = 0; i < 3; i++) tmp[i] = F[0][i];
    for (int i = 0; i < 3; i++) F[0][i] = L[0][i];
    for (int i = 0; i < 3; i++) L[0][i] = B[0][i];
    for (int i = 0; i < 3; i++) B[0][i] = R[0][i];
    for (int i = 0; i < 3; i++) R[0][i] = tmp[i];
  }

  // D move: bottom face CW, cycle F[2] -> R[2] -> B[2] -> L[2] -> F[2] (bottom rows align, no reversal)
  void moveD() {
    rotateFaceCW(D);
    char[] tmp = new char[3];
    for (int i = 0; i < 3; i++) tmp[i] = F[2][i];
    for (int i = 0; i < 3; i++) F[2][i] = L[2][i];
    for (int i = 0; i < 3; i++) L[2][i] = B[2][i];
    for (int i = 0; i < 3; i++) B[2][i] = R[2][i];
    for (int i = 0; i < 3; i++) R[2][i] = tmp[i];
  }

  void moveDPrime() {
    rotateFaceCCW(D);
    char[] tmp = new char[3];
    for (int i = 0; i < 3; i++) tmp[i] = F[2][i];
    for (int i = 0; i < 3; i++) F[2][i] = R[2][i];
    for (int i = 0; i < 3; i++) R[2][i] = B[2][i];
    for (int i = 0; i < 3; i++) B[2][i] = L[2][i];
    for (int i = 0; i < 3; i++) L[2][i] = tmp[i];
  }

  // R move: right face CW, cycle F col2 -> U col2 -> B col0 (reversed) -> D col2 -> F col2
  void moveR() {
    rotateFaceCW(R);
    char[] tmp = new char[3];
    for (int i = 0; i < 3; i++) tmp[i] = F[i][2];
    for (int i = 0; i < 3; i++) F[i][2] = D[i][2];
    for (int i = 0; i < 3; i++) D[i][2] = B[2-i][0];
    for (int i = 0; i < 3; i++) B[2-i][0] = U[i][2];
    for (int i = 0; i < 3; i++) U[i][2] = tmp[i];
  }

  void moveRPrime() {
    rotateFaceCCW(R);
    char[] tmp = new char[3];
    for (int i = 0; i < 3; i++) tmp[i] = F[i][2];
    for (int i = 0; i < 3; i++) F[i][2] = U[i][2];
    for (int i = 0; i < 3; i++) U[i][2] = B[2-i][0];
    for (int i = 0; i < 3; i++) B[2-i][0] = D[i][2];
    for (int i = 0; i < 3; i++) D[i][2] = tmp[i];
  }

  // L move: left face CW, cycle F col0 -> U col0 -> B col2 (reversed) -> D col0 -> F col0
  void moveL() {
    rotateFaceCW(L);
    char[] tmp = new char[3];
    for (int i = 0; i < 3; i++) tmp[i] = F[i][0];
    for (int i = 0; i < 3; i++) F[i][0] = U[i][0];
    for (int i = 0; i < 3; i++) U[i][0] = B[2-i][2];
    for (int i = 0; i < 3; i++) B[2-i][2] = D[i][0];
    for (int i = 0; i < 3; i++) D[i][0] = tmp[i];
  }

  void moveLPrime() {
    rotateFaceCCW(L);
    char[] tmp = new char[3];
    for (int i = 0; i < 3; i++) tmp[i] = F[i][0];
    for (int i = 0; i < 3; i++) F[i][0] = D[i][0];
    for (int i = 0; i < 3; i++) D[i][0] = B[2-i][2];
    for (int i = 0; i < 3; i++) B[2-i][2] = U[i][0];
    for (int i = 0; i < 3; i++) U[i][0] = tmp[i];
  }

  // F move: front face CW, cycle U row2 -> R col0 -> D row0 (reversed) -> L col2 (reversed) -> U row2
  void moveF() {
    rotateFaceCW(F);
    char[] tmp = new char[3];
    for (int i = 0; i < 3; i++) tmp[i] = U[2][i];
    for (int i = 0; i < 3; i++) U[2][i] = L[2-i][2];
    for (int i = 0; i < 3; i++) L[2-i][2] = D[0][2-i];
    for (int i = 0; i < 3; i++) D[0][2-i] = R[i][0];
    for (int i = 0; i < 3; i++) R[i][0] = tmp[i];
  }

  void moveFPrime() {
    rotateFaceCCW(F);
    char[] tmp = new char[3];
    for (int i = 0; i < 3; i++) tmp[i] = U[2][i];
    for (int i = 0; i < 3; i++) U[2][i] = R[i][0];
    for (int i = 0; i < 3; i++) R[i][0] = D[0][2-i];
    for (int i = 0; i < 3; i++) D[0][2-i] = L[2-i][2];
    for (int i = 0; i < 3; i++) L[2-i][2] = tmp[i];
  }

  // B move: back face CW, cycle U row0 -> L col0 -> D row2 (reversed) -> R col2 (reversed) -> U row0
  void moveB() {
    rotateFaceCW(B);
    char[] tmp = new char[3];
    for (int i = 0; i < 3; i++) tmp[i] = U[0][i];
    for (int i = 0; i < 3; i++) U[0][i] = R[i][2];
    for (int i = 0; i < 3; i++) R[i][2] = D[2][2-i];
    for (int i = 0; i < 3; i++) D[2][2-i] = L[2-i][0];
    for (int i = 0; i < 3; i++) L[2-i][0] = tmp[i];
  }

  void moveBPrime() {
    rotateFaceCCW(B);
    char[] tmp = new char[3];
    for (int i = 0; i < 3; i++) tmp[i] = U[0][i];
    for (int i = 0; i < 3; i++) U[0][i] = L[2-i][0];
    for (int i = 0; i < 3; i++) L[2-i][0] = D[2][2-i];
    for (int i = 0; i < 3; i++) D[2][2-i] = R[i][2];
    for (int i = 0; i < 3; i++) R[i][2] = tmp[i];
  }

  void scramble(String moves) {
    for (String m : moves.trim().split("\\s+")) {
      switch (m) {
        case "U":  moveU();      break;
        case "U'": moveUPrime(); break;
        case "D":  moveD();      break;
        case "D'": moveDPrime(); break;
        case "R":  moveR();      break;
        case "R'": moveRPrime(); break;
        case "L":  moveL();      break;
        case "L'": moveLPrime(); break;
        case "F":  moveF();      break;
        case "F'": moveFPrime(); break;
        case "B":  moveB();      break;
        case "B'": moveBPrime(); break;
        case "U2": moveU(); moveU(); break;
        case "D2": moveD(); moveD(); break;
        case "R2": moveR(); moveR(); break;
        case "L2": moveL(); moveL(); break;
        case "F2": moveF(); moveF(); break;
        case "B2": moveB(); moveB(); break;
      }
    }
  }

  boolean isSolved() {
    char[][][] faces = {U, D, F, B, L, R};
    for (char[][] face : faces) {
      char c = face[0][0];
      for (int i = 0; i < 3; i++)
        for (int j = 0; j < 3; j++)
          if (face[i][j] != c) return false;
    }
    return true;
  }
}
