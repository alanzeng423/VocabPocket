#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_ROOT="$PROJECT_ROOT/.build"
APP_PATH="$BUILD_ROOT/VocabPocket.app"

export CLANG_MODULE_CACHE_PATH="$BUILD_ROOT/module-cache/clang"
export SWIFT_MODULECACHE_PATH="$BUILD_ROOT/module-cache/swift"

mkdir -p "$CLANG_MODULE_CACHE_PATH" "$SWIFT_MODULECACHE_PATH"
if [[ "${VOCABPOCKET_UNIVERSAL:-0}" == "1" ]]; then
    ARM_SCRATCH="$BUILD_ROOT/arm64"
    INTEL_SCRATCH="$BUILD_ROOT/x86_64"
    UNIVERSAL_BIN="$BUILD_ROOT/universal-bin"

    swift build --package-path "$PROJECT_ROOT" --scratch-path "$ARM_SCRATCH" -c release --product VocabPocket --arch arm64
    swift build --package-path "$PROJECT_ROOT" --scratch-path "$INTEL_SCRATCH" -c release --product VocabPocket --arch x86_64
    ARM_BIN_PATH="$(swift build --package-path "$PROJECT_ROOT" --scratch-path "$ARM_SCRATCH" -c release --arch arm64 --show-bin-path)"
    INTEL_BIN_PATH="$(swift build --package-path "$PROJECT_ROOT" --scratch-path "$INTEL_SCRATCH" -c release --arch x86_64 --show-bin-path)"

    mkdir -p "$UNIVERSAL_BIN"
    lipo -create "$ARM_BIN_PATH/VocabPocket" "$INTEL_BIN_PATH/VocabPocket" -output "$UNIVERSAL_BIN/VocabPocket"
    BIN_PATH="$UNIVERSAL_BIN"
else
    swift build --package-path "$PROJECT_ROOT" -c release --product VocabPocket
    BIN_PATH="$(swift build --package-path "$PROJECT_ROOT" -c release --show-bin-path)"
fi

if [[ -d "$APP_PATH" ]]; then
    rm -rf "$APP_PATH"
fi

mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$BIN_PATH/VocabPocket" "$APP_PATH/Contents/MacOS/VocabPocket"
cp "$PROJECT_ROOT/Support/Info.plist" "$APP_PATH/Contents/Info.plist"
cp "$PROJECT_ROOT/Support/PrivacyInfo.xcprivacy" "$APP_PATH/Contents/Resources/PrivacyInfo.xcprivacy"
chmod +x "$APP_PATH/Contents/MacOS/VocabPocket"

ICON_BASE="$BUILD_ROOT/AppIcon-1024.png"
sips -s format png "$PROJECT_ROOT/Support/AppIcon.pdf" --out "$ICON_BASE" >/dev/null
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ICON_BASE" --out "$BUILD_ROOT/AppIcon-${size}.png" >/dev/null
done

# An ICNS file is a small big-endian container around PNG representations.
LC_ALL=C LANG=C LC_CTYPE=C perl -e '
    use strict;
    binmode STDOUT;
    my $body = "";
    while (@ARGV) {
        my $type = shift @ARGV;
        my $file = shift @ARGV;
        open my $fh, "<:raw", $file or die "$file: $!";
        local $/;
        my $data = <$fh>;
        $body .= $type . pack("N", length($data) + 8) . $data;
    }
    print "icns", pack("N", length($body) + 8), $body;
' \
    icp4 "$BUILD_ROOT/AppIcon-16.png" \
    icp5 "$BUILD_ROOT/AppIcon-32.png" \
    ic07 "$BUILD_ROOT/AppIcon-128.png" \
    ic08 "$BUILD_ROOT/AppIcon-256.png" \
    ic09 "$BUILD_ROOT/AppIcon-512.png" \
    ic10 "$ICON_BASE" \
    > "$APP_PATH/Contents/Resources/AppIcon.icns"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_PATH"
fi

echo "Built $APP_PATH"
