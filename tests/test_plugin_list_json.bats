#!/usr/bin/env bats

# Test suite: Plugin list JSON validation
# Framework: Bats (Bash Automated Testing System)
# Utilities: jq (for JSON parsing)
#
# Usage:
#   Set PLUGIN_LIST_JSON to the exact path of the JSON file if not at ./plugin_list.json.
#   Example:
#     PLUGIN_LIST_JSON=data/plugins.json bats tests/test_plugin_list_json.bats
#
# Focus:
#   Validate structure and fields based on the diff-provided content, covering:
#     - JSON parse validity
#     - Required top-level keys presence (for selected entries)
#     - Required fields presence for each plugin object: name, version, checksum, nu-plugin-dep
#     - Value sanity checks: non-empty strings, version patterns, checksum hex length
#     - Edge cases: null nu-plugin-dep allowed only where shown, and strings otherwise
#     - No unexpected extra fields in each plugin object (schema strictness)
#   The tests bias towards action by verifying a significant subset of entries and patterns found in the diff.

setup() {
  # Select default path or override
  export PLUGIN_LIST_JSON="${PLUGIN_LIST_JSON:-plugin_list.json}"

  if ! command -v jq >/dev/null 2>&1; then
    skip "jq is required for JSON validation; skipping tests."
  fi

  if [ ! -f "$PLUGIN_LIST_JSON" ]; then
    skip "Plugin list JSON not found at '$PLUGIN_LIST_JSON'; set PLUGIN_LIST_JSON to the correct path."
  fi
}

@test "plugin list JSON: is valid JSON" {
  run jq . "$PLUGIN_LIST_JSON"
  [ "$status" -eq 0 ]
}

# Helper: check object has exactly the allowed keys
# Usage: assert_exact_keys <jq_filter_for_object> <comma_separated_keys>
# Example: assert_exact_keys '.["nu_plugin_highlight"]' 'name,version,checksum,nu-plugin-dep'
assert_exact_keys() {
  local obj_filter="$1"
  local keys_csv="$2"
  local keys_json
  keys_json="$(printf '%s' "$keys_csv" | jq -R 'split(",") | map(.|gsub("^\\s+|\\s+$";""))')"

  run bash -c \
    "jq -e --argjson expected $keys_json '$obj_filter | (keys | sort) as \$got | (\$expected | sort) as \$exp | if \$got == \$exp then true else error(\"keys mismatch: got=\(\$got) expected=\(\$exp)\") end' \"$PLUGIN_LIST_JSON\""
  [ "$status" -eq 0 ]
}

# Helper: assert field exists and is a non-empty string
# Usage: assert_non_empty_string <jq_filter_for_field>
assert_non_empty_string() {
  local field_filter="$1"
  run bash -c \
    "jq -e '$field_filter | (type == \"string\" and length > 0)' \"$PLUGIN_LIST_JSON\""
  [ "$status" -eq 0 ]
}

# Helper: assert optional nullable or string dependency field
# Usage: assert_dep_string_or_null <jq_filter_for_field> <allow_null_true_or_false>
assert_dep_string_or_null() {
  local field_filter="$1"
  local allow_null="$2"
  if [ "$allow_null" = "true" ]; then
    run bash -c \
      "jq -e '$field_filter | (type == \"string\" and length > 0) or (. == null)' \"$PLUGIN_LIST_JSON\""
  else
    run bash -c \
      "jq -e '$field_filter | (type == \"string\" and length > 0)' \"$PLUGIN_LIST_JSON\""
  fi
  [ "$status" -eq 0 ]
}

# Helper: assert semantic-like version pattern (liberal)
# Accepts digits and dots and optional suffix like +0.106.0
# Usage: assert_version_pattern <jq_filter_for_field>
assert_version_pattern() {
  local field_filter="$1"
  # Regex: start with digits and dots, optionally + then more digits/dots
  local re='^[0-9]+(\.[0-9]+)*(\+[0-9]+(\.[0-9]+)*)?$'
  run bash -c \
    "jq -er '$field_filter' \"$PLUGIN_LIST_JSON\" | egrep -q '$re'"
  [ "$status" -eq 0 ]
}

# Helper: assert checksum is hex string length >= 64 (diff shows 64)
assert_checksum_hex64() {
  local field_filter="$1"
  run bash -c \
    "jq -er '$field_filter' \"$PLUGIN_LIST_JSON\" | egrep -q '^[a-f0-9]{64}$'"
  [ "$status" -eq 0 ]
}

# Validate a representative set of plugins pulled from the diff
# Each entry: exact keys, field types, patterns, and special rules

@test "nu_plugin_highlight: correct schema and values" {
  run jq -e 'has("nu_plugin_highlight")' "$PLUGIN_LIST_JSON"
  [ "$status" -eq 0 ]

  assert_exact_keys '.["nu_plugin_highlight"]' 'name,version,checksum,nu-plugin-dep'
  assert_non_empty_string '.["nu_plugin_highlight"].name'
  assert_version_pattern '.["nu_plugin_highlight"].version'
  assert_checksum_hex64 '.["nu_plugin_highlight"].checksum'
  assert_dep_string_or_null '.["nu_plugin_highlight"]["nu-plugin-dep"]' false
}

@test "nu_plugin_tracer: allows null dependency" {
  run jq -e 'has("nu_plugin_tracer")' "$PLUGIN_LIST_JSON"
  [ "$status" -eq 0 ]

  assert_exact_keys '.["nu_plugin_tracer"]' 'name,version,checksum,nu-plugin-dep'
  assert_non_empty_string '.["nu_plugin_tracer"].name'
  assert_version_pattern '.["nu_plugin_tracer"].version'
  assert_checksum_hex64 '.["nu_plugin_tracer"].checksum'
  # Specifically allow null for this plugin per diff
  run jq -e '.["nu_plugin_tracer"]["nu-plugin-dep"] == null' "$PLUGIN_LIST_JSON"
  [ "$status" -eq 0 ]
}

@test "nu_plugin_formats: semver with patch-level and matching dep ^0.106.1" {
  run jq -e 'has("nu_plugin_formats")' "$PLUGIN_LIST_JSON"
  [ "$status" -eq 0 ]

  assert_exact_keys '.["nu_plugin_formats"]' 'name,version,checksum,nu-plugin-dep'
  assert_non_empty_string '.["nu_plugin_formats"].name'
  assert_version_pattern '.["nu_plugin_formats"].version'
  assert_checksum_hex64 '.["nu_plugin_formats"].checksum'
  run jq -e '.["nu_plugin_formats"]["nu-plugin-dep"] == "^0.106.1"' "$PLUGIN_LIST_JSON"
  [ "$status" -eq 0 ]
}

@test "nu_plugin_ws: dependency caret matches 0.106.1 exactly" {
  run jq -e 'has("nu_plugin_ws")' "$PLUGIN_LIST_JSON"
  [ "$status" -eq 0 ]
  run jq -e '.["nu_plugin_ws"]["nu-plugin-dep"] == "^0.106.1"' "$PLUGIN_LIST_JSON"
  [ "$status" -eq 0 ]
}

@test "nu_plugin_twitch: dependency caret without patch is allowed" {
  run jq -e 'has("nu_plugin_twitch")' "$PLUGIN_LIST_JSON"
  [ "$status" -eq 0 ]
  run jq -e '.["nu_plugin_twitch"]["nu-plugin-dep"] == "^0.106"' "$PLUGIN_LIST_JSON"
  [ "$status" -eq 0 ]
}

@test "nu_plugin_from_parquet: legacy low nu-plugin-dep is still valid" {
  run jq -e 'has("nu_plugin_from_parquet")' "$PLUGIN_LIST_JSON"
  [ "$status" -eq 0 ]

  assert_version_pattern '.["nu_plugin_from_parquet"].version'
  run jq -e '.["nu_plugin_from_parquet"]["nu-plugin-dep"] == "^0.26.0"' "$PLUGIN_LIST_JSON"
  [ "$status" -eq 0 ]
}

@test "All plugin entries: each object has exactly name, version, checksum, nu-plugin-dep" {
  # Collect any offending entries with unexpected keys or missing keys
  run bash -c '
    jq -r "
      to_entries[]
      | select(.value | type == \"object\")
      | (
          (.value | (keys | sort)) as \$got
          | ([\"name\",\"version\",\"checksum\",\"nu-plugin-dep\"] | sort) as \$exp
          | if \$got == \$exp then empty else .key end
        )
    " \"$PLUGIN_LIST_JSON\" | sort -u
  '
  [ "$status" -eq 0 ]
  # stdout should be empty if all entries are exact-schema objects
  [ -z "$output" ]
}

@test "All plugin entries: name/version/checksum types are correct and non-empty" {
  run bash -c '
    jq -r "
      to_entries[]
      | select(.value | type == \"object\")
      | select(
          (.value.name | type != \"string\" or length == 0)
          or (.value.version | type != \"string\" or length == 0)
          or (.value.checksum | type != \"string\" or length == 0)
        )
      | .key
    " \"$PLUGIN_LIST_JSON\" | sort -u
  '
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "All plugin entries: checksum strings are 64-char lowercase hex" {
  run bash -c '
    jq -r "
      to_entries[]
      | select(.value | type == \"object\")
      | select(.value.checksum | test(\"^[a-f0-9]{64}$\") | not)
      | .key
    " \"$PLUGIN_LIST_JSON\" | sort -u
  '
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "All plugin entries: nu-plugin-dep is either a non-empty string or null" {
  run bash -c '
    jq -r "
      to_entries[]
      | select(.value | type == \"object\")
      | select(
          (.value[\"nu-plugin-dep\"] != null and (.value[\"nu-plugin-dep\"] | type != \"string\" or length == 0))
          or (.value[\"nu-plugin-dep\"] == null and false) # allow null
        )
      | .key
    " \"$PLUGIN_LIST_JSON\" | sort -u
  '
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "Representative entries exist: sanity check key presence for a sampling" {
  # A sampling from the diff to ensure keys exist
  for k in \
    nu_plugin_highlight \
    nu_plugin_bash_env \
    nu_plugin_x509 \
    nu_plugin_roaring \
    nu_plugin_rpm \
    nu_plugin_dbus \
    nu_plugin_prometheus \
    nu_plugin_tracer \
    nu_plugin_formats \
    nu_plugin_query \
    nu_plugin_ulid \
    nu_plugin_xpath
  do
    run jq -e "has(\"\$k\")" "$PLUGIN_LIST_JSON"
    [ "$status" -eq 0 ]
  done
}