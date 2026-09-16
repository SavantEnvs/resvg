#![no_main]
use libfuzzer_sys::fuzz_target;

fuzz_target!(|data: &[u8]| {
    let opts = usvg::Options::default();
    let _ = usvg::Tree::from_data(data, &opts.to_ref());
});
