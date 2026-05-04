#!/bin/bash
# Build and package the Jellyfin 2FA plugin (fat package by default)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/src/Jellyfin.Plugin.TwoFactorAuth"
MODE="${1:-fat}"
INSTALL_FLAG="${2:-}"
OUTPUT_DIR="$SCRIPT_DIR/dist/TwoFactorAuth"

if [ "$MODE" = "--install" ]; then
    MODE="fat"
    INSTALL_FLAG="--install"
fi

if [ "$MODE" = "fat" ]; then
    RIDS=(linux-x64 linux-arm64 linux-musl-x64)
else
    RIDS=("$MODE")
    OUTPUT_DIR="$SCRIPT_DIR/dist/TwoFactorAuth-$MODE"
fi

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

PRIMARY_PUBLISH_DIR=""
for RID in "${RIDS[@]}"; do
    PUBLISH_DIR="$SCRIPT_DIR/dist/publish-$RID"
    rm -rf "$PUBLISH_DIR"
    echo "Building plugin (Release, RID=$RID)..."
    dotnet publish "$PROJECT_DIR" -c Release -r "$RID" --self-contained false -o "$PUBLISH_DIR" --nologo

    if [ -z "$PRIMARY_PUBLISH_DIR" ]; then
        PRIMARY_PUBLISH_DIR="$PUBLISH_DIR"
        for file in \
            Jellyfin.Plugin.TwoFactorAuth.dll \
            Otp.NET.dll \
            QRCoder.dll \
            Fido2.dll \
            Fido2.Models.dll \
            NSec.Cryptography.dll \
            System.Formats.Cbor.dll \
            MaxMind.Db.dll \
            QuestPDF.dll \
            IdentityModel.OidcClient.dll \
            IdentityModel.dll \
            Microsoft.IdentityModel.Abstractions.dll \
            Microsoft.IdentityModel.JsonWebTokens.dll \
            Microsoft.IdentityModel.Logging.dll \
            Microsoft.IdentityModel.Tokens.dll \
            System.IdentityModel.Tokens.Jwt.dll \
        ; do
            if [ -f "$PRIMARY_PUBLISH_DIR/$file" ]; then
                cp "$PRIMARY_PUBLISH_DIR/$file" "$OUTPUT_DIR/"
            fi
        done
    fi

    NATIVE_DIR="$PUBLISH_DIR/runtimes/$RID/native"
    if [ -d "$NATIVE_DIR" ]; then
        mkdir -p "$OUTPUT_DIR/runtimes/$RID/native"
        cp "$NATIVE_DIR"/* "$OUTPUT_DIR/runtimes/$RID/native/" 2>/dev/null || true
    fi
done

# Copy meta.json
cp "$PROJECT_DIR/meta.json" "$OUTPUT_DIR/"

echo ""
echo "Plugin built to: $OUTPUT_DIR"
ls -la "$OUTPUT_DIR"

# Install if --install flag passed
if [ "$INSTALL_FLAG" = "--install" ]; then
    PLUGIN_DIR="${JELLYFIN_DATA:-$HOME/.local/share/jellyfin}/plugins/TwoFactorAuth"
    rm -rf "$PLUGIN_DIR"
    cp -r "$OUTPUT_DIR" "$PLUGIN_DIR"
    echo ""
    echo "Installed to: $PLUGIN_DIR"
    echo "Restart Jellyfin to load the plugin."
fi
