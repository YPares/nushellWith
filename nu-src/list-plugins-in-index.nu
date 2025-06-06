def parse-one [path] {
    open -r $path |
    from json --objects |
    last | # Select the most recent version
    select name vers cksum |
    rename name version checksum
}

def main [crates_io_index] {
    ls $"($crates_io_index)/nu/_p" |
        where {($in.name | path parse).stem | str starts-with "nu_plugin_"} |
        each {parse-one $in.name | {$in.name: $in}} |
        into record |
        save $env.out
}
