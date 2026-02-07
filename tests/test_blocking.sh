#!/usr/bin/env bash
set -euo pipefail

# End-to-end test for claude-nvim: verify that the shell script blocks
# until the buffer is closed in NeoVim.

PROG="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CLAUDE_NVIM="$PROJECT_DIR/bin/claude-nvim"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

pass=0
fail=0
skip=0

log_pass() { echo -e "  ${GREEN}PASS${NC}: $1"; pass=$((pass + 1)); }
log_fail() { echo -e "  ${RED}FAIL${NC}: $1"; fail=$((fail + 1)); }
log_skip() { echo -e "  ${YELLOW}SKIP${NC}: $1"; skip=$((skip + 1)); }
log_info() { echo -e "  INFO: $1"; }

cleanup_pids=()
cleanup_files=()

cleanup() {
  if [[ ${#cleanup_pids[@]} -gt 0 ]]; then
    for pid in "${cleanup_pids[@]}"; do
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    done
  fi
  if [[ ${#cleanup_files[@]} -gt 0 ]]; then
    for f in "${cleanup_files[@]}"; do
      rm -rf "$f"
    done
  fi
}
trap cleanup EXIT

# Check prerequisites
if ! command -v nvim &>/dev/null; then
  echo "nvim not found, skipping all tests"
  exit 0
fi

echo "Running claude-nvim tests..."
echo ""

# ---------------------------------------------------------------------------
# Test 1: Shell script exists and is executable
# ---------------------------------------------------------------------------
echo "Test 1: Shell script is executable"
if [[ -x "$CLAUDE_NVIM" ]]; then
  log_pass "bin/claude-nvim is executable"
else
  log_fail "bin/claude-nvim is not executable"
fi

# ---------------------------------------------------------------------------
# Test 2: --help works
# ---------------------------------------------------------------------------
echo "Test 2: --help flag"
if "$CLAUDE_NVIM" --help &>/dev/null; then
  log_pass "--help exits successfully"
else
  log_fail "--help failed"
fi

# ---------------------------------------------------------------------------
# Test 3: --version works
# ---------------------------------------------------------------------------
echo "Test 3: --version flag"
version_output="$("$CLAUDE_NVIM" --version 2>&1)"
if [[ "$version_output" == *"0.1.0"* ]]; then
  log_pass "--version shows version"
else
  log_fail "--version output unexpected: $version_output"
fi

# ---------------------------------------------------------------------------
# Test 4: End-to-end blocking test with NeoVim
# ---------------------------------------------------------------------------
echo "Test 4: End-to-end blocking (open file, close buffer, verify exit)"

SOCK="/tmp/claude-nvim-test-$$.sock"
TEST_FILE="$(mktemp "${TMPDIR:-/tmp}/claude-nvim-test-XXXXXX.md")"
cleanup_files+=("$TEST_FILE" "$SOCK")

echo "Initial content" > "$TEST_FILE"

# Start NeoVim in headless mode with our plugin loaded
nvim --headless --listen "$SOCK" \
  --cmd "set rtp+=$PROJECT_DIR" \
  -c "lua require('claude-nvim').setup()" \
  &>/dev/null &
nvim_pid=$!
cleanup_pids+=("$nvim_pid")

# Wait for NeoVim to be ready
for i in $(seq 1 30); do
  if nvim --server "$SOCK" --remote-expr "1+1" &>/dev/null; then
    break
  fi
  sleep 0.1
done

if ! nvim --server "$SOCK" --remote-expr "1+1" &>/dev/null; then
  log_fail "NeoVim failed to start on socket $SOCK"
else
  # Run claude-nvim in background — it should block
  NVIM_CLAUDE_SOCK="$SOCK" "$CLAUDE_NVIM" edit "$TEST_FILE" &
  editor_pid=$!
  cleanup_pids+=("$editor_pid")

  # Give it a moment to connect and send the command
  sleep 1

  # Verify the editor is still running (blocking)
  if kill -0 "$editor_pid" 2>/dev/null; then
    log_pass "claude-nvim is blocking (waiting for buffer close)"
  else
    log_fail "claude-nvim exited prematurely"
  fi

  # Edit the file content via NeoVim
  nvim --server "$SOCK" --remote-send \
    ":call setline(1, 'Edited content')<CR>:write<CR>" 2>/dev/null || true
  sleep 0.5

  # Close the buffer — this should unblock claude-nvim
  nvim --server "$SOCK" --remote-send ":bdelete<CR>" 2>/dev/null || true

  # Wait for claude-nvim to exit (with timeout)
  for i in $(seq 1 30); do
    if ! kill -0 "$editor_pid" 2>/dev/null; then
      break
    fi
    sleep 0.1
  done

  if ! kill -0 "$editor_pid" 2>/dev/null; then
    log_pass "claude-nvim unblocked after buffer close"
  else
    log_fail "claude-nvim still running after buffer close"
    kill "$editor_pid" 2>/dev/null || true
  fi

  # Verify the file was edited
  content="$(cat "$TEST_FILE")"
  if [[ "$content" == "Edited content" ]]; then
    log_pass "File content was updated correctly"
  else
    log_fail "File content unexpected: $content"
  fi

  # Shutdown test NeoVim
  nvim --server "$SOCK" --remote-send ":qa!<CR>" 2>/dev/null || true
  sleep 0.5
  kill "$nvim_pid" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Test 5: :ClaudeNvimSend (signal without closing buffer)
# ---------------------------------------------------------------------------
echo "Test 5: :ClaudeNvimSend (signal done, keep buffer open)"

SOCK5="/tmp/claude-nvim-test5-$$.sock"
TEST_FILE5="$(mktemp "${TMPDIR:-/tmp}/claude-nvim-test5-XXXXXX.md")"
cleanup_files+=("$TEST_FILE5" "$SOCK5")

echo "Content for send test" > "$TEST_FILE5"

nvim --headless --listen "$SOCK5" \
  --cmd "set rtp+=$PROJECT_DIR" \
  -c "lua require('claude-nvim').setup()" \
  &>/dev/null &
nvim5_pid=$!
cleanup_pids+=("$nvim5_pid")

for i in $(seq 1 30); do
  if nvim --server "$SOCK5" --remote-expr "1+1" &>/dev/null; then
    break
  fi
  sleep 0.1
done

if ! nvim --server "$SOCK5" --remote-expr "1+1" &>/dev/null; then
  log_fail "NeoVim failed to start for test 5"
else
  NVIM_CLAUDE_SOCK="$SOCK5" "$CLAUDE_NVIM" edit "$TEST_FILE5" &
  editor5_pid=$!
  cleanup_pids+=("$editor5_pid")

  sleep 1

  # Use :ClaudeNvimSend — should unblock without closing buffer
  nvim --server "$SOCK5" --remote-send ":ClaudeNvimSend<CR>" 2>/dev/null || true

  for i in $(seq 1 30); do
    if ! kill -0 "$editor5_pid" 2>/dev/null; then
      break
    fi
    sleep 0.1
  done

  if ! kill -0 "$editor5_pid" 2>/dev/null; then
    log_pass "claude-nvim unblocked after :ClaudeNvimSend"
  else
    log_fail "claude-nvim still running after :ClaudeNvimSend"
    kill "$editor5_pid" 2>/dev/null || true
  fi

  # Verify buffer is still open (not deleted)
  buf_count="$(nvim --server "$SOCK5" --remote-expr "len(getbufinfo({'buflisted':1}))" 2>/dev/null)" || buf_count="0"
  if [[ "$buf_count" -ge 1 ]]; then
    log_pass "Buffer still open after :ClaudeNvimSend"
  else
    log_fail "Buffer was unexpectedly closed"
  fi

  nvim --server "$SOCK5" --remote-send ":qa!<CR>" 2>/dev/null || true
  sleep 0.5
  kill "$nvim5_pid" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $pass passed, $fail failed, $skip skipped"

if [[ $fail -gt 0 ]]; then
  exit 1
fi
