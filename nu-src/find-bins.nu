# In each given folder, finds an executable file
#
# Fails if one of the folders contains more than one executable file
#
# Prints the results in outFile
def main [...dirs] {
    mut results = []
    for dir in $dirs {
        let executables = ls -l $dir | where type == file and mode =~ "x$"
        match $executables {
            [] => (error make -u {msg: $"Folder ($dir) does not contain any executable"}),
            [$exe] => ($results = $results | append $exe.name),
            _ => (error make -u {msg: $"Folder ($dir) contains more than one executable: ($executables.name)"})
        }
    }
    $results | to nuon | save -r $env.out
}
