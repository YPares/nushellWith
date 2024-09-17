# Prepend a PATH to a nushell file, writing result someplace else
def patchNuFile [path: list<path>, inFile: path, outFile: path] {
    # `use` directives must remain at the top of the file
    let contents = open -r $inFile
    let new_contents = [
        $"export-env {
            $env.PATH = \($env.PATH | prepend ($path | to nuon))
          }"
        $contents
    ]
    $new_contents | str join "\n\n" | save -r $outFile
}

# Recursively add PATH to each .nu file in a directory, writing result someplace else
def patchNuDir [path: list<path>, inDir: path, outDir: path] {
    cd $inDir
    for inFile in (ls -a **/*) {
        let outFile = $"($outDir)/($inFile.name)"
        let outParent = $outFile | path dirname
        if (not ($outParent | path exists)) {
            mkdir $outParent
        }
        if ($inFile.name | path parse | get extension) == "nu" {
            patchNuFile $path $inFile.name $outFile
        } else if ($inFile.type == "file") {
            cp $inFile.name $outFile
        }
    }
}

# Prepend a PATH to each .nu file (recursively) in some folder, writing result someplace else
def main [path: string, # Colon-separated PATH to add
          inDir: path, # Source directory
          outDir: path # Destination directory. Must already exist
    ] {
    patchNuDir ($path | split row :) $inDir $outDir
}
