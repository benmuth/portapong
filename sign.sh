#!/bin/sh
# Ad-hoc codesign the executable with the get-task-allow entitlement so that
# Instruments.app (and lldb) can attach to it. `zig build` re-links the binary
# and drops the entitlement, so re-run this after every rebuild of the exe.
set -eu

root=$(cd "$(dirname "$0")" && pwd)
bin=${1:-"$root/zig-out/bin/portapong"}

if [ ! -f "$bin" ]; then
    echo "sign.sh: no such binary: $bin" >&2
    echo "sign.sh: run 'zig build' first" >&2
    exit 1
fi

codesign --force --sign - --entitlements "$root/debug.plist" "$bin"
echo "signed $bin"
