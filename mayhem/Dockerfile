# syntax=docker/dockerfile:1.7
FROM ghcr.io/savantenvs/base:20260621

ARG COMMIT
ARG REPO_URL
ARG SOURCE_DATE_EPOCH
ARG SANITIZER_FLAGS

ARG RUST_CHANNEL=nightly-2026-01-20
ARG CARGO_FUZZ_VERSION=0.12.0

ENV RUSTUP_HOME=/opt/toolchains/rust/rustup \
    CARGO_HOME=/opt/toolchains/rust/cargo \
    PATH=/opt/toolchains/rust/cargo/bin:${PATH} \
    CC=clang CXX=clang++

USER root
RUN install -d /opt/toolchains/rust \
 && curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs -o /tmp/rustup-init.sh \
 && sh /tmp/rustup-init.sh -y --no-modify-path --profile minimal \
        --default-toolchain "${RUST_CHANNEL}" \
 && rustup component add rust-src --toolchain "${RUST_CHANNEL}" \
 && cargo install -j1 cargo-fuzz --version "${CARGO_FUZZ_VERSION}" --locked \
 && rm -f /tmp/rustup-init.sh \
 && chown -R 2000:2000 /opt/toolchains/rust

# Every bug on this target is a Rust panic, so every crash reaches libc through the same
# panic-hook -> std::process::abort path and only the frames *below* it name the bug. Mayhem keys a
# defect on the first three frames it does not recognise as runtime noise; Debian's detached glibc
# debug info (libc6-dbg, /usr/lib/debug) symbolizes that abort path into named, source-located
# frames (__pthread_kill_implementation at nptl/pthread_kill.c:43) which its filter does not know,
# so they fill the window and every distinct panic collapses into one defect. The mayhemheroes image
# this run reproduces carried no detached debug info -- its libc frames were address-only and were
# filtered -- and it told the pathdata.rs and svgtree/parse.rs panics apart. Drop it so the usvg
# frames reach the key again. Nothing under test loses debug info: the fuzz and standalone binaries
# carry their own DWARF (mayhem/build.sh asserts it).
RUN rm -rf /usr/lib/debug
ENV DEBUGINFOD_URLS=""

# The original triage environment ran with backtraces enabled; keep the crash reports as legible.
ENV RUST_BACKTRACE=1

USER mayhem
WORKDIR /mayhem
COPY --chown=2000:2000 . /mayhem

RUN bash mayhem/build.sh
RUN if [ -f mayhem/test.sh ]; then bash mayhem/test.sh; else echo "no mayhem/test.sh"; fi

LABEL org.opencontainers.image.source="${REPO_URL}" \
      org.opencontainers.image.revision="${COMMIT}" \
      rlenv.tier="commit" \
      rlenv.source_date_epoch="${SOURCE_DATE_EPOCH}" \
      rlenv.user="mayhem"

USER mayhem
WORKDIR /mayhem
