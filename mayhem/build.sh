#!/usr/bin/env bash
set -euo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SRC:=/mayhem}"
: "${MAYHEM_JOBS:=$(nproc)}"
export CARGO_BUILD_JOBS="$MAYHEM_JOBS"

cd "$SRC"

export CC=clang CXX=clang++
export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER=clang

: "${RUST_DEBUG_FLAGS:=-C debuginfo=2 -C force-frame-pointers=yes}"
DWARF_FLAGS="-Zdwarf-version=3"
FUZZ_RUSTFLAGS="${RUSTFLAGS:-} --cfg fuzzing -Zsanitizer=address ${RUST_DEBUG_FLAGS} ${DWARF_FLAGS}"
echo "SANITIZER_FLAGS (base, informational) = ${SANITIZER_FLAGS:-<unset>}"

FUZZ_DIR="mayhem/fuzz"
TRIPLE="x86_64-unknown-linux-gnu"

export CFLAGS="${CFLAGS:-} -gdwarf-3"
export CXXFLAGS="${CXXFLAGS:-} -gdwarf-3"

ASAN_A="$(rustc --print sysroot)/lib/rustlib/${TRIPLE}/lib/librustc-nightly_rt.asan.a"
if [ -f "$ASAN_A" ]; then
  objcopy --strip-debug "$ASAN_A" 2>/dev/null || objcopy --remove-section '.debug_*' "$ASAN_A" 2>/dev/null || true
fi

FUZZ_TARGETS=()
for f in "$FUZZ_DIR"/fuzz_targets/*.rs; do
  FUZZ_TARGETS+=("$(basename "${f%.*}")")
done
[ "${#FUZZ_TARGETS[@]}" -gt 0 ] || { echo "ERROR: no fuzz targets under $FUZZ_DIR/fuzz_targets/" >&2; exit 1; }

for t in "${FUZZ_TARGETS[@]}"; do
  RUSTFLAGS="$FUZZ_RUSTFLAGS" cargo fuzz build --fuzz-dir "$FUZZ_DIR" -O --debug-assertions "$t"
  bin="$SRC/$FUZZ_DIR/target/$TRIPLE/release/$t"
  [ -x "$bin" ] || { echo "ERROR: expected fuzz binary not found at $bin" >&2; exit 1; }
done

cp "$SRC/$FUZZ_DIR/target/$TRIPLE/release/tree_from_bytes" /mayhem/tree-from-bytes
echo "built /mayhem/tree-from-bytes"

# Non-fuzzer reproducer for the same entry point: no libFuzzer runtime, no sanitizer, panic = abort.
# Besides being the reproducer BACKPORT.md replays the corpus through, it is the Mayhemfile's second
# (native, file-input) cmd — the shape the original mayhemheroes run used (`<t>_no_inst @@`), and the
# only crash channel on this target whose report is not dominated by the libFuzzer/panic-hook frames.
echo "=== standalone reproducer (mayhem/standalone) ==="
( cd "$SRC/mayhem/standalone" \
  && RUSTFLAGS="--cfg fuzzing ${RUST_DEBUG_FLAGS} ${DWARF_FLAGS}" cargo build --release )
sb="$SRC/mayhem/standalone/target/release/tree_from_bytes_standalone"
[ -x "$sb" ] || { echo "ERROR: expected standalone binary not found at $sb" >&2; exit 1; }
cp "$sb" /mayhem/tree-from-bytes-standalone
if command -v file >/dev/null 2>&1; then
  file /mayhem/tree-from-bytes-standalone | grep -q 'dynamically linked' \
    || { echo "ERROR: /mayhem/tree-from-bytes-standalone is not dynamically linked" >&2; exit 1; }
fi
readelf -S /mayhem/tree-from-bytes-standalone | grep -qE '[[:space:]]\.debug_info' \
  || { echo "ERROR: /mayhem/tree-from-bytes-standalone has no .debug_info" >&2; exit 1; }
echo "built /mayhem/tree-from-bytes-standalone"

echo "=== cargo test --no-run -p usvg (clean flags, for test.sh) ==="
( cd "$SRC" && env -u RUSTFLAGS CARGO_TARGET_DIR="$SRC/mayhem/test-target" \
  cargo test --no-run -p usvg --no-default-features --features text,memmap-fonts )
echo "build.sh complete"
