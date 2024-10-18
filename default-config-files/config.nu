# No plugin GC by default

$env.config = {
    show_banner: false
    plugin_gc: {
        default: {
            enabled: false
        }
    }
}
