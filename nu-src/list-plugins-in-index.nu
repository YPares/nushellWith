def parse-one [path] {
    open -r $path |
    from json --objects |
    last | # Select the most recent version
    select name vers cksum |
    rename name version checksum
}

def to-attr-name [] {
    str replace "nu_plugin_" "plugin-"
}

def main [crates_io_index] {
    mkdir $env.out
    ls $"($crates_io_index)/nu/_p" |
        where {($in.name | path parse).stem | str starts-with "nu_plugin_"} |
        each {parse-one $in.name | {($in.name | to-attr-name): $in}} |
        into record |
        save $"($env.out)/plugins.json"
}
