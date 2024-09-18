def create_left_prompt [] {
    let dir = match (do --ignore-shell-errors { $env.PWD | path relative-to $nu.home-path }) {
        null => $env.PWD
        '' => '~'
        $relative_pwd => ([~ $relative_pwd] | path join)
    }

    let path_color = (if (is-admin) { ansi red_bold } else { ansi green_bold })
    let separator_color = (if (is-admin) { ansi light_red_bold } else { ansi light_green_bold })
    let path_segment = $"($path_color)($dir)"

    let path = $path_segment | str replace --all (char path_sep) $"($separator_color)(char path_sep)($path_color)"
    mut prompt = $"(ansi reset)[nuw"
    if $env.IN_NIX_SHELL? != null {
        $prompt = $"($prompt),(ansi yellow)($env.IN_NIX_SHELL)-nix(ansi reset)"
    }
    $"($prompt)] ($path)"
}

$env.PROMPT_COMMAND = {|| create_left_prompt }
