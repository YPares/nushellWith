# These are always rejected, whatever the user settings, because
# they prevent the env from functioning correctly
const HIDDEN = [
  HOME FILE_PWD CURRENT_FILE PWD SHELL SHLVL
  name shell shellHook
  TMP TEMP TMPDIR TEMPDIR
  NIX_SSL_CERT_FILE
  SSL_CERT_FILE
  "NU_.*"
]

export def extract-from-env [
  selected: list<string>
  rejected: list<string>
] {
  let rejected = $HIDDEN ++ $rejected

  $env |
    transpose k v |
    where {|e| (
      ($e.v | describe) in [string "list<string>"]
      and
      ($selected | any {$e.k =~ $"^($in)$"})
      and
      (not ($rejected | any {$e.k =~ $"^($in)$"}))
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

def main [
  selected: string
  rejected: string
] {
  extract-from-env ($selected | from nuon) ($rejected | from nuon) | to nuon
}
