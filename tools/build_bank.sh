#!/usr/bin/env bash
#
# Builds the bundled no-guess puzzle bank by compiling the app's generator with optimization
# and running it offline. Re-run any time you want to refresh or grow the bank.
#
# Usage:  tools/build_bank.sh [count]      (default 1000)
#
# Output: Puzzle Garden/Resources/boards_9x9.json  (auto-bundled into the app target).
set -euo pipefail
cd "$(dirname "$0")/.."

COUNT="${1:-1000}"
MODELS="Puzzle Garden/Models"
OUT_DIR="Puzzle Garden/Resources"
OUT="$OUT_DIR/boards_9x9.json"
mkdir -p "$OUT_DIR"

BIN="$(mktemp -d)/bankgen"
echo "Compiling generator (-O)…"
swiftc -O \
  "$MODELS/Puzzle.swift" \
  "$MODELS/LogicSolver.swift" \
  "$MODELS/PuzzleBank.swift" \
  "$MODELS/PuzzleGenerator.swift" \
  "tools/BankGenerator/main.swift" \
  -o "$BIN"

echo "Generating $COUNT unique 9×9 boards…"
"$BIN" 9 "$COUNT" "$OUT"
