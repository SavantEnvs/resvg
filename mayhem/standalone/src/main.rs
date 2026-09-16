// Non-fuzzer reproducer for the tree-from-bytes harness (SPEC "Fuzzer + standalone binaries"):
// runs the same entry point as mayhem/fuzz/fuzz_targets/tree_from_bytes.rs once, on one input file.
use std::io::Read;

fn main() {
    let mut args = std::env::args_os();
    let _ = args.next();
    let path = match args.next() {
        Some(p) => p,
        None => {
            eprintln!("usage: tree_from_bytes_standalone <input-file>");
            std::process::exit(2);
        }
    };
    let mut data = Vec::new();
    match std::fs::File::open(&path).and_then(|mut f| f.read_to_end(&mut data)) {
        Ok(_) => {}
        Err(e) => {
            eprintln!("cannot read {}: {}", path.to_string_lossy(), e);
            std::process::exit(2);
        }
    }

    let opts = usvg::Options::default();
    let _ = usvg::Tree::from_data(&data, &opts.to_ref());
}
