#!/usr/bin/env bash
set -uo pipefail

SCRIPT="$(dirname "$0")/enable-auto-merge-error-handler.sh"
PASS=0
FAIL=0

run_test() {
  local name="$1"
  local input="$2"
  local expected_exit="$3"
  local expected_pattern="$4"

  output=$(echo "$input" | bash "$SCRIPT" 2>&1)
  actual_exit=$?

  if [ "$actual_exit" -ne "$expected_exit" ]; then
    echo "FAIL [$name]: expected exit $expected_exit, got $actual_exit"
    FAIL=$((FAIL + 1))
    return
  fi

  if ! echo "$output" | grep -q "$expected_pattern"; then
    echo "FAIL [$name]: output did not match '$expected_pattern'"
    echo "  actual: $output"
    FAIL=$((FAIL + 1))
    return
  fi

  echo "PASS [$name]"
  PASS=$((PASS + 1))
}

run_test "success response" \
  '{"data":{"enablePullRequestAutoMerge":{"pullRequest":{"autoMergeRequest":{}}}}}' \
  0 \
  "Auto merge enabled successfully"

run_test "rate limit type" \
  '{"errors":[{"type":"RATE_LIMIT","message":"API rate limit exceeded"}]}' \
  0 \
  "Warning: could not enable auto merge"

run_test "unstable message" \
  '{"errors":[{"type":"OTHER","message":"The repository is in an unstable state"}]}' \
  0 \
  "Warning: could not enable auto merge"

run_test "already has auto merge" \
  '{"errors":[{"type":"OTHER","message":"already has auto-merge enabled"}]}' \
  0 \
  "Warning: could not enable auto merge"

run_test "rate limit in message" \
  '{"errors":[{"type":"OTHER","message":"rate.limit reached"}]}' \
  0 \
  "Warning: could not enable auto merge"

run_test "rate_limit in message" \
  '{"errors":[{"type":"OTHER","message":"rate_limit exceeded"}]}' \
  0 \
  "Warning: could not enable auto merge"

run_test "required protected branch" \
  '{"errors":[{"type":"OTHER","message":"required protected branch rules are not satisfied"}]}' \
  0 \
  "Warning: could not enable auto merge"

run_test "unknown error fails" \
  '{"errors":[{"type":"OTHER","message":"some unexpected error occurred"}]}' \
  1 \
  "Failed to enable auto merge"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
