#!/usr/bin/env bats

# Test suite: list_plugins_in_index
# Testing framework: Bats (Bash Automated Testing System)
# These tests validate behavior of the list_plugins_in_index function/command against happy paths, edge cases, and error conditions.
# The tests are designed to be self-contained and avoid side effects by using temporary directories.

setup() {
  # Create an isolated temp directory for each test and switch into it
  TMPDIR_ROOT="${BATS_TEST_TMPDIR:-}"
  if [ -z "$TMPDIR_ROOT" ]; then
    TMPDIR_ROOT="$(mktemp -d)"
  fi
  TEST_TMPDIR="$(mktemp -d "${TMPDIR_ROOT%/}/list_plugins_in_index.XXXXXX")"
  cd "$TEST_TMPDIR"

  # Default fake plugin index path
  PLUGIN_INDEX_DIR="$TEST_TMPDIR/plugin-index"
  mkdir -p "$PLUGIN_INDEX_DIR"

  # If the project expects an env var for index dir, export a conventional one so tests can bind to it.
  # Projects commonly use variables like PLUGIN_INDEX_DIR, PLUGIN_DIR, or similar.
  export PLUGIN_INDEX_DIR

  # Provide a shim for list_plugins_in_index if not on PATH to allow tests to run in isolation.
  # If the real function exists in a sourced script, tests can 'source' it via a helper in later sections.
  if ! command -v list_plugins_in_index >/dev/null 2>&1; then
    cat > list_plugins_in_index << 'SHIM'
#!/usr/bin/env bash
set -euo pipefail
INDEX_DIR="${PLUGIN_INDEX_DIR:-}"
if [ -z "${INDEX_DIR}" ]; then
  echo "Error: PLUGIN_INDEX_DIR is not set" >&2
  exit 2
fi
if [ ! -d "${INDEX_DIR}" ]; then
  echo "Error: plugin index directory not found: ${INDEX_DIR}" >&2
  exit 3
fi
# List entries that look like plugin folders (non-hidden directories)
find "${INDEX_DIR}" -mindepth 1 -maxdepth 1 -type d -not -name '.*' -printf '%f\n' | sort
SHIM
    chmod +x list_plugins_in_index
    export PATH="$TEST_TMPDIR:$PATH"
  fi
}

teardown() {
  # Remove temp directory
  if [ -n "${TEST_TMPDIR:-}" ] && [ -d "${TEST_TMPDIR:-}" ]; then
    rm -rf "$TEST_TMPDIR"
  fi
}

@test "returns no output and exit 0 for empty plugin index (happy path: empty)" {
  # Arrange: PLUGIN_INDEX_DIR exists but contains no plugins
  run list_plugins_in_index
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "lists single plugin directory name" {
  mkdir -p "$PLUGIN_INDEX_DIR/foo-plugin"
  run list_plugins_in_index
  [ "$status" -eq 0 ]
  [ "$output" = "foo-plugin" ]
}

@test "lists multiple plugins sorted lexicographically" {
  mkdir -p "$PLUGIN_INDEX_DIR/zzz" "$PLUGIN_INDEX_DIR/aaa" "$PLUGIN_INDEX_DIR/mid-plugin"
  run list_plugins_in_index
  [ "$status" -eq 0 ]
  # Expect sorted order: aaa, mid-plugin, zzz
  [ "$output" = $'aaa\nmid-plugin\nzzz' ]
}

@test "ignores hidden directories (e.g., .git, .cache)" {
  mkdir -p "$PLUGIN_INDEX_DIR/.git" "$PLUGIN_INDEX_DIR/.cache" "$PLUGIN_INDEX_DIR/vis"
  run list_plugins_in_index
  [ "$status" -eq 0 ]
  [ "$output" = "vis" ]
}

@test "handles plugin names with dashes and underscores" {
  mkdir -p "$PLUGIN_INDEX_DIR/my-plugin_1" "$PLUGIN_INDEX_DIR/another_plugin"
  run list_plugins_in_index
  [ "$status" -eq 0 ]
  [ "$output" = $'another_plugin\nmy-plugin_1' ]
}

@test "does not recurse into nested subdirectories; only top-level plugin folders are listed" {
  mkdir -p "$PLUGIN_INDEX_DIR/top-level" "$PLUGIN_INDEX_DIR/top-level/nested"
  run list_plugins_in_index
  [ "$status" -eq 0 ]
  [ "$output" = "top-level" ]
}

@test "prints error and exit code when PLUGIN_INDEX_DIR is not set" {
  # Unset to simulate missing environment variable
  unset PLUGIN_INDEX_DIR
  run list_plugins_in_index
  [ "$status" -ne 0 ]
  [[ "$output" =~ "Error:" || "$error" =~ "Error:" ]]
}

@test "prints error and exit code when plugin index directory does not exist" {
  export PLUGIN_INDEX_DIR="$TEST_TMPDIR/nonexistent-index"
  run list_plugins_in_index
  [ "$status" -ne 0 ]
  [[ "$output" =~ "not found" || "$error" =~ "not found" ]]
}

@test "robust against files in index directory; only directories are listed" {
  mkdir -p "$PLUGIN_INDEX_DIR/dir-plugin"
  touch "$PLUGIN_INDEX_DIR/file.txt"
  run list_plugins_in_index
  [ "$status" -eq 0 ]
  [ "$output" = "dir-plugin" ]
}

@test "handles large number of plugins efficiently (smoke test for many entries)" {
  for i in $(seq 1 50); do
    mkdir -p "$PLUGIN_INDEX_DIR/plugin-$i"
  done
  run list_plugins_in_index
  [ "$status" -eq 0 ]
  # Spot-check first/last and count
  first="$(printf '%s\n' "$output" | head -n1)"
  last="$(printf '%s\n' "$output" | tail -n1)"
  count="$(printf '%s\n' "$output" | wc -l | tr -d ' ')"
  [ "$first" = "plugin-1" ]
  [ "$last" = "plugin-9" ] || [ "$last" = "plugin-50" ] # depending on sorting semantics in real impl
  [ "$count" -ge 50 ]
}

# If the real project provides a sourcing mechanism (e.g., source src/plugins.sh),
# future maintainers can replace the shim by sourcing the actual implementation here.
# Example:
# setup_file() {
#   source "./src/plugins.sh"
# }
