#!/usr/bin/env bash
# ============================================================
# Chess Kingdom Defense — headless auto-play batch runner.
#
# One command = a full data-generation pass:
# 4 buying strategies × 6 levels (level_1..level_5 + final_stand,
# capped at FINAL_STAND_CAP waves so it terminates).
#
# Usage:
#   GODOT_BIN=/path/to/godot RUNS=10 ./tools/run_autoplay_batch.sh
#
# Environment overrides (all optional):
#   GODOT_BIN          godot executable   (default: "godot")
#   RUNS               runs per strategy×level combination (default 10)
#   TIME_SCALE         game speed-up      (default 16)
#   TIMEOUT_SECONDS    hard per-run timeout, real seconds (default 600)
#   FINAL_STAND_CAP    wave cap for final_stand (default 30)
#   DECISION_INTERVAL  bot decision cadence, game seconds (default 0.5)
#   SEED               optional RNG seed for reproducible runs
#   CAPTURE_DIR        where archived logs go
#                      (default: data-captures/<timestamp>)
# ============================================================
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-godot}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUNS="${RUNS:-10}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-600}"
FINAL_STAND_CAP="${FINAL_STAND_CAP:-30}"
TIME_SCALE="${TIME_SCALE:-16}"
DECISION_INTERVAL="${DECISION_INTERVAL:-0.5}"
SEED="${SEED:-}"
CAPTURE_DIR="${CAPTURE_DIR:-$PROJECT_DIR/data-captures/$(date +%Y%m%d_%H%M%S)}"

STRATEGIES=(cheapest_first balanced rush_strongest random)
LEVELS=(level_1 level_2 level_3 level_4 level_5 final_stand)

# --- Save-data hygiene (tasks plan Q2) ------------------------
# If a real save file exists, back it up and restore it afterwards
# so bot runs can't pollute it. If none exists (fresh profile), the
# game creates a new save.cfg on the first run — expected.
USER_DIR="$HOME/Library/Application Support/Godot/app_userdata/ChessDefense"
LOG_DIR="$USER_DIR/logs"
SAVE_FILE="$USER_DIR/save.cfg"
BACKUP=""

if [[ -f "$SAVE_FILE" ]]; then
    BACKUP="$SAVE_FILE.pre-autoplay.bak"
    cp "$SAVE_FILE" "$BACKUP"
    echo "Backed up save.cfg → $BACKUP (bot runs would otherwise pollute it)"
fi

restore_save() {
    if [[ -n "$BACKUP" ]]; then
        mv "$BACKUP" "$SAVE_FILE"
        echo "Restored original save.cfg"
    fi
}
trap restore_save EXIT

mkdir -p "$LOG_DIR" "$CAPTURE_DIR"
echo "Capturing logs to $CAPTURE_DIR"

SEED_ARGS=()
if [[ -n "$SEED" ]]; then
    SEED_ARGS=(--seed="$SEED")
fi

for strategy in "${STRATEGIES[@]}"; do
    for level in "${LEVELS[@]}"; do
        echo "=== strategy=$strategy level=$level runs=$RUNS ==="

        # Snapshot existing logs so only this combination's fresh
        # files get archived (and each archive is identifiable by
        # a strategy_level prefix). Only GameLogger run files are
        # archived — the shared logs dir also receives Godot's own
        # engine logs (godot*.log), which are not gameplay data.
        MANIFEST="$(mktemp)"
        { ls -1 "$LOG_DIR"/run_*.csv "$LOG_DIR"/run_*.jsonl 2>/dev/null || true; } | sort > "$MANIFEST"

        "$GODOT_BIN" --headless --path "$PROJECT_DIR" -- \
            --strategy="$strategy" --level="$level" --runs="$RUNS" \
            --timeout-seconds="$TIMEOUT_SECONDS" \
            --final-stand-cap="$FINAL_STAND_CAP" \
            --time-scale="$TIME_SCALE" \
            --decision-interval="$DECISION_INTERVAL" \
            ${SEED_ARGS[@]+"${SEED_ARGS[@]}"}

        NEW_MANIFEST="$(mktemp)"
        { ls -1 "$LOG_DIR"/run_*.csv "$LOG_DIR"/run_*.jsonl 2>/dev/null || true; } | sort > "$NEW_MANIFEST"

        while IFS= read -r file_name; do
            [[ -z "$file_name" ]] && continue
            cp "$file_name" "$CAPTURE_DIR/${strategy}_${level}_$(basename "$file_name")"
        done < <(comm -13 "$MANIFEST" "$NEW_MANIFEST")

        rm -f "$MANIFEST" "$NEW_MANIFEST"
    done
done

echo "Done. $RUNS runs × ${#STRATEGIES[@]} strategies × ${#LEVELS[@]} levels."
echo "Captured logs: $CAPTURE_DIR"
