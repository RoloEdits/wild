export CC := "clang"

cflags := "-march=native -O3 -flto=full"
rustflags := "-Ctarget-cpu=native -Clinker=clang"

CWD := shell("pwd")

default: build

build:
    CFLAGS="{{cflags}}" \
    RUSTFLAGS="{{rustflags}} -Clink-arg=-fuse-ld=lld -Clink-args=-Wl,--icf=all" cargo +nightly build -Zbuild-std --release

pgo: clean instrument train-wezterm train-nushell train-helix merge opt

clean:
    cargo clean
    rm -rf /tmp/wild-pgo

instrument:
    @echo "Instrumenting..."
    CFLAGS="{{cflags}}" \
    RUSTFLAGS="{{rustflags}} -Clink-arg=-fuse-ld=lld -Cprofile-generate=/tmp/wild-pgo" cargo build --bin wild --release --target=x86_64-unknown-linux-gnu

[working-directory: "../wezterm"]
train-wezterm:
    @echo "Training..."
    cargo clean
    LLVM_PROFILE_FILE=/tmp/wild-pgo/default_%m_%p.profraw \
    RUSTFLAGS="-Clinker=clang -Clink-arg=--ld-path={{CWD}}/target/x86_64-unknown-linux-gnu/release/wild" cargo build

[working-directory: "../nushell"]
train-nushell:
    @echo "Training..."
    cargo clean
    LLVM_PROFILE_FILE=/tmp/wild-pgo/default_%m_%p.profraw \
    RUSTFLAGS="-Clinker=clang -Clink-arg=--ld-path={{CWD}}/target/x86_64-unknown-linux-gnu/release/wild" cargo build

[working-directory: "../helix"]
train-helix:
    @echo "Training..."
    cargo clean
    LLVM_PROFILE_FILE=/tmp/wild-pgo/default_%m_%p.profraw \
    RUSTFLAGS="-Clinker=clang -Clink-arg=--ld-path={{CWD}}/target/x86_64-unknown-linux-gnu/release/wild" cargo build

merge:
    @echo "Merging..."
    llvm-profdata merge -o /tmp/wild-pgo/merged.profdata /tmp/wild-pgo/*.profraw

opt:
    @echo "Optimizing..."
    CFLAGS="{{cflags}}" \
    RUSTFLAGS="{{rustflags}} -Clink-arg=-fuse-ld=lld -Clink-args=-Wl,--icf=all -Cprofile-use=/tmp/wild-pgo/merged.profdata" \
    cargo build --bin wild --release

install:
    cp -f target/release/wild ~/.local/bin/wild
