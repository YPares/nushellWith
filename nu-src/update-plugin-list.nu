#! /usr/bin/env -S nu -n

use std/formats "from jsonl"

def search-crates-io-rec [qs] {
  let r = http get https://crates.io/api/v1/crates($qs)
  $r.crates | append (
    match $r.meta?.next_page? {
      null => []
      $qs_next => {
        search-crates-io-rec $qs_next
      }
    }
  )
}

export def list-latest-compatible-versions [wanted_nu_version] {
  search-crates-io-rec "?q=nu_plugin_&per_page=100" |
    where name =~ "^nu_plugin_" |
    select name |
    par-each {|crate|
      let versions = http get https://index.crates.io/nu/_p/($crate.name) |
        from jsonl |
        each {|ver|
          let nu_plugin_dep = $ver.deps | where name == "nu-plugin" | get -o 0.req
          {
            key: ($crate.name | str replace "nu_plugin_" "")
            value: {
              name: $crate.name
              version: $ver.vers
              checksum: $ver.cksum
              nu-plugin-dep: $nu_plugin_dep
              broken: ($nu_plugin_dep == null or not ($wanted_nu_version | semver match-req $nu_plugin_dep))
            }
          }
        }
      match ($versions | where not value.broken | slice (-1)..) {
        [$ver] => $ver
        _ => ($versions | last)
      }
    } | sort-by key | transpose -rd
}

const self = path self | path basename

# Fetch from crates.io the list of packages named nu_plugin_*
# and write their details (name, version, checksum) to a TOML file
def main [out: path = "plugin-list.toml"] {
  let wanted_nu_version = open -r ($self | path join .. flake.lock) |
    from json | get nodes.nushell-src.original.ref
  print $"Updating plugin list from crates.io and finding latest versions compatible with Nu ($wanted_nu_version)..."
  [
    $"## THIS FILE IS GENERATED AUTOMATICALLY BY ($self)"
    "## DO NOT EDIT MANUALLY"
    ""
    ...(list-latest-compatible-versions $wanted_nu_version | to toml | lines)
  ] | save --raw -f $out
}
