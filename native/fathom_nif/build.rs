fn main() {
    for file in [
        "vendor/fathom/src/tbprobe.c",
        "vendor/fathom/src/tbchess.c",
        "vendor/fathom/src/tbprobe.h",
        "vendor/fathom/src/tbconfig.h",
        "vendor/fathom/src/stdendian.h",
        "csrc/wrapper.c",
    ] {
        println!("cargo:rerun-if-changed={file}");
    }

    cc::Build::new()
        .file("vendor/fathom/src/tbprobe.c")
        .file("csrc/wrapper.c")
        .include("vendor/fathom/src")
        .flag_if_supported("-std=gnu99")
        .flag_if_supported("-O2")
        .warnings(false)
        .compile("fathom");
}
