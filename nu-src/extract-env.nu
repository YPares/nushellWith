const HIDDEN_VARS = [
  HOME FILE_PWD CURRENT_FILE PWD SHELL SHLVL name shell shellHook TMP TEMP TMPDIR TEMPDIR
  # LANG LOCALE_ARCHIVE 
  NIX_SSL_CERT_FILE
  SSL_CERT_FILE
]

export def extract-from-env [selected] {
  $env |
    reject -i ...$HIDDEN_VARS |
    transpose k v |
    where {|e| (
      ($e.v | describe) in [string "list<string>"]
      and
      ($e.k !~ "^NU_.*")
      and
      ($selected | any {$e.k =~ $in})
    )} |
    transpose -rd
}

export def merge-deep-all [paths: list<path>] {
  match $paths {
    [] => {
      $in
    }
    [$p ..$rest] => {
      merge deep -s append (open $p | from nuon) | merge-deep-all $rest
    }
  }
}

export def --env merge-into-env [paths: list<path>] {
  load-env (
    $env |
      transpose k v |
      where {($in.v | describe) == "list<string>"} |
      transpose -rd |
      merge-deep-all $paths
  )
}

def main [...selected] {
  extract-from-env $selected | to nuon
}
