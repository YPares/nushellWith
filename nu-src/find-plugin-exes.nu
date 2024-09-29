# In each given folder, finds an executable file
#
# Fails if one of the folders contains more than one executable file
#
# Prints the results in outFile
def main [...dirs] {
    mut results = []
    for dir in $dirs {
        let executables = ls -l $dir |
            insert filename {$in.name | path parse | get stem} |
            where type == file and filename starts-with "nu_plugin_"
        match $executables {
            [] => (error make -u {
                msg: $"Folder ($dir) does not contain any nu_plugin_* file. It contains: (ls -s $dir | get name)"
            }),
            [$exe] => ($results = $results | append $exe.name),
            _ => (error make -u {
                msg: $"Folder ($dir) contains more than one nu_plugin_* file: ($executables.filename).
                       Did you forget to pass `-p <pkg_name>` to cargo?"
            })
        }
    }
    $results | to nuon | save -r $env.out
}
