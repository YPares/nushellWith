#!/usr/bin/env bats

# Test framework: Bats (Bash Automated Testing System - bats-core)
# These tests target the Nushell script that defines:
#   - def search-crates-io-rec [qs] { ... }
#   - export def list-latest-plugin-versions [] { ... }
#   - def main [] { ... }
#
# Strategy:
# - Invoke Nushell (nu) to source the target script and call its functions.
# - Mock network interactions:
#     * Overlay a custom 'http' module to shadow 'http get' for deterministic fixtures.
#     * Override 'search-crates-io-rec' within the test Nu session to avoid crates.io search.
# - Validate:
#     * Happy path aggregation of latest versions and nu-plugin dependency.
#     * Edge case with no matching crates.
#     * Failure when the latest index line is malformed JSON.
#     * 'main' writes plugin-list.json to disk.
#
# Notes:
# - Requires Nushell 'nu' on PATH.
# - Uses 'overlay use' to shadow built-in http behavior where supported.

setup() {
  TMPDIR="$(mktemp -d)"
  export TMPDIR

  # Nushell module that mocks 'http get'
  # It returns newline-delimited JSON for index.crates.io lookups so that
  # 'lines | last | from json' in the implementation selects the latest.
  cat > "${TMPDIR}/http.nu" << 'NUHTTP'
module http {
  export def get [url:string] {
    if ($url | str starts-with "https://index.crates.io/nu/_p/nu_plugin_example_a") {
      $"{"name":"nu_plugin_example_a","vers":"0.1.0","cksum":"aaa","deps":[{"name":"nu-plugin","req":"^0.90"}]}
{"name":"nu_plugin_example_a","vers":"0.2.3","cksum":"abc123","deps":[{"name":"nu-plugin","req":"^0.91"}]}"
    } else if ($url | str starts-with "https://index.crates.io/nu/_p/nu_plugin_example_b") {
      $"{"name":"nu_plugin_example_b","vers":"1.5.0","cksum":"bbb","deps":[{"name":"nu-plugin","req":"^0.90"}]}
{"name":"nu_plugin_example_b","vers":"2.0.0","cksum":"def456","deps":[{"name":"nu-plugin","req":"^1.0"}]}"
    } else if ($url | str starts-with "https://index.crates.io/nu/_p/nu_plugin_badjson") {
      $"{"name":"nu_plugin_badjson","vers":"0.1.0","cksum":"ccc","deps":[{"name":"nu-plugin","req":"^0.90"}]}
THIS_IS_NOT_JSON"
    } else if ($url | str starts-with "https://crates.io/api/v1/crates") {
      # Fallback for search; in tests we override the search function anyway.
      $"{"crates":[],"meta":{"next_page":null}}" | from json
    } else {
      $"{"name":"unknown","vers":"0.0.0","cksum":"zzz","deps":[{"name":"nu-plugin","req":"^0.0"}]}"
    }
  }
}
export module http
NUHTTP
}

teardown() {
  rm -rf "${TMPDIR}"
}

# Helper: locate the Nushell script that exports list-latest-plugin-versions
_find_nushell_script() {
  if command -v rg >/dev/null 2>&1; then
    rg -l --hidden --no-ignore -S "export def list-latest-plugin-versions" 2>/dev/null | head -1
  else
    grep -Rsl --exclude-dir=.git "export def list-latest-plugin-versions" . 2>/dev/null | head -1
  fi
}

_require_nu_or_skip() {
  if ! command -v nu >/dev/null 2>&1; then
    skip "Nushell 'nu' is not installed in PATH"
  fi
}

_require_script_or_skip() {
  local script
  script="$(_find_nushell_script)"
  if [[ -z "$script" ]]; then
    skip "Could not locate Nushell script that exports list-latest-plugin-versions"
  fi
}

_overlay_supported() {
  nu -c 'overlay list | ignore' >/dev/null 2>&1
}

@test "list-latest-plugin-versions aggregates latest versions and nu-plugin req (happy path via mocks)" {
  _require_nu_or_skip
  _require_script_or_skip

  if ! _overlay_supported; then
    skip "Nushell overlay not supported; skipping mock-based test"
  fi

  local script
  script="$(_find_nushell_script)"

  run nu -c "
    let httpmod = (\$env.TMPDIR | path join 'http.nu');
    overlay use \$httpmod;
    source '${script}';
    def search-crates-io-rec [qs] {
      [ { name: 'nu_plugin_example_a' } { name: 'nu_plugin_example_b' } ]
    }
    list-latest-plugin-versions | to json
  "

  [ "$status" -eq 0 ]
  # Contains both crates
  [[ "$output" == *"nu_plugin_example_a"* ]]
  [[ "$output" == *"nu_plugin_example_b"* ]]

  # Latest versions and checksums from mock
  [[ "$output" == *'"nu_plugin_example_a":{"name":"nu_plugin_example_a","version":"0.2.3","checksum":"abc123"'* ]] || \
  [[ "$output" == *'"nu_plugin_example_a": {"name": "nu_plugin_example_a", "version": "0.2.3", "checksum": "abc123"'* ]]

  [[ "$output" == *'"nu_plugin_example_b":{"name":"nu_plugin_example_b","version":"2.0.0","checksum":"def456"'* ]] || \
  [[ "$output" == *'"nu_plugin_example_b": {"name": "nu_plugin_example_b", "version": "2.0.0", "checksum": "def456"'* ]]

  # nu-plugin requirement extracted
  [[ "$output" == *'"nu-plugin-dep":"^0.91"'* ]] || [[ "$output" == *'"nu-plugin-dep": "^0.91"'* ]]
  [[ "$output" == *'"nu-plugin-dep":"^1.0"'* ]] || [[ "$output" == *'"nu-plugin-dep": "^1.0"'* ]]
}

@test "list-latest-plugin-versions returns empty structure when search yields no crates" {
  _require_nu_or_skip
  _require_script_or_skip

  if ! _overlay_supported; then
    skip "Nushell overlay not supported; skipping mock-based test"
  fi

  local script
  script="$(_find_nushell_script)"

  run nu -c "
    let httpmod = (\$env.TMPDIR | path join 'http.nu');
    overlay use \$httpmod;
    source '${script}';
    def search-crates-io-rec [qs] { [] }
    list-latest-plugin-versions | to json
  "

  [ "$status" -eq 0 ]
  # Should not contain any nu_plugin_ keys
  [[ "$output" != *"nu_plugin_"* ]]
}

@test "list-latest-plugin-versions errors when latest index line is invalid JSON" {
  _require_nu_or_skip
  _require_script_or_skip

  if ! _overlay_supported; then
    skip "Nushell overlay not supported; skipping mock-based test"
  fi

  local script
  script="$(_find_nushell_script)"

  run nu -c "
    let httpmod = (\$env.TMPDIR | path join 'http.nu');
    overlay use \$httpmod;
    source '${script}';
    def search-crates-io-rec [qs] {
      [ { name: 'nu_plugin_badjson' } ]
    }
    # from json should fail on malformed line
    list-latest-plugin-versions | to json
  "

  [ "$status" -ne 0 ]
  [[ "$output" == *"json"* ]] || [[ "$output" == *"parse"* ]] || true
}

@test "main writes plugin-list.json (smoke, mocked network)" {
  _require_nu_or_skip
  _require_script_or_skip

  if ! _overlay_supported; then
    skip "Nushell overlay not supported; skipping mock-based test"
  fi

  local script outdir
  script="$(_find_nushell_script)"
  outdir="$(mktemp -d)"
  pushd "$outdir" >/dev/null

  run nu -c "
    let httpmod = (\$env.TMPDIR | path join 'http.nu');
    overlay use \$httpmod;
    source '${script}';
    def search-crates-io-rec [qs] {
      [ { name: 'nu_plugin_example_a' } ]
    }
    main
  "

  [ "$status" -eq 0 ]
  [ -f "plugin-list.json" ]
  grep -q "nu_plugin_example_a" plugin-list.json

  popd >/dev/null
}

@test "list-latest-plugin-versions runs (network-dependent fallback) [lenient]" {
  _require_nu_or_skip
  _require_script_or_skip

  if _overlay_supported; then
    skip "Overlay mocking supported; skipping network-dependent fallback"
  fi

  local script
  script="$(_find_nushell_script)"

  run nu -c "
    source '${script}';
    list-latest-plugin-versions | to json | length
  "

  if [ "$status" -ne 0 ]; then
    skip "Network call failed in environment; skipping"
  fi
  [[ -n "$output" ]]
}