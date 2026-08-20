#!/usr/bin/env bash
set -euo pipefail

PREFIX="${WINEPREFIX:-$HOME/dev/wine_prefix}"
WINE_ROOT="/opt/wine-cachyos"

export WINEPREFIX="$PREFIX"
export PATH="$WINE_ROOT/bin:$PATH"

WINE="$WINE_ROOT/bin/wine"
WINESERVER="$WINE_ROOT/bin/wineserver"

die() {
    echo "error: $*" >&2
    exit 1
}

[[ -f "$PREFIX/system.reg" ]] || die "invalid prefix: $PREFIX"
[[ -x "$WINE" ]] || die "Wine-CachyOS not found"

for cmd in curl jq tar zstd; do
    command -v "$cmd" >/dev/null || die "missing: $cmd"
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

get_release() {
    local repo="$1"
    local regex="$2"
    local json tag url

    json="$(curl -fsSL --retry 3 \
        "https://api.github.com/repos/$repo/releases/latest")"

    tag="$(jq -r '.tag_name' <<<"$json")"

    url="$(
        jq -r --arg re "$regex" \
            '.assets[]
             | select(.name | test($re))
             | .browser_download_url' \
            <<<"$json" |
        head -n1
    )"

    [[ -n "$tag" && "$tag" != null ]] || die "cannot find latest $repo release"
    [[ -n "$url" && "$url" != null ]] || die "cannot find $repo release archive"

    printf '%s\n%s\n' "$tag" "$url"
}

mapfile -t DXVK < <(
    get_release \
        "doitsujin/dxvk" \
        '^dxvk-[0-9].*\.tar\.gz$'
)

mapfile -t VKD3D < <(
    get_release \
        "HansKristian-Work/vkd3d-proton" \
        '^vkd3d-proton-[0-9].*\.tar\.zst$'
)

DXVK_TAG="${DXVK[0]}"
DXVK_URL="${DXVK[1]}"

VKD3D_TAG="${VKD3D[0]}"
VKD3D_URL="${VKD3D[1]}"

echo "DXVK:         $DXVK_TAG"
echo "VKD3D-Proton: $VKD3D_TAG"

curl -fL --retry 3 -o "$tmp/dxvk.tar.gz" "$DXVK_URL"
curl -fL --retry 3 -o "$tmp/vkd3d.tar.zst" "$VKD3D_URL"

mkdir "$tmp/dxvk" "$tmp/vkd3d"

tar -xzf "$tmp/dxvk.tar.gz" \
    -C "$tmp/dxvk" \
    --strip-components=1

tar --zstd -xf "$tmp/vkd3d.tar.zst" \
    -C "$tmp/vkd3d" \
    --strip-components=1

# Stop applications using this prefix.
"$WINESERVER" -k 2>/dev/null || true

#
# VKD3D-Proton: D3D12
#
# Use upstream's own installer.
#
(
    cd "$tmp/vkd3d"
    bash ./setup_vkd3d_proton.sh install
)

#
# DXVK: D3D8-11 + DXGI
#
cp -f "$tmp/dxvk"/x64/*.dll \
    "$PREFIX/drive_c/windows/system32/"

cp -f "$tmp/dxvk"/x32/*.dll \
    "$PREFIX/drive_c/windows/syswow64/"

for dll in d3d8 d3d9 d3d10core d3d11 dxgi; do
    "$WINE" reg add \
        'HKCU\Software\Wine\DllOverrides' \
        /v "$dll" \
        /d native \
        /f >/dev/null
done

"$WINESERVER" -k 2>/dev/null || true

echo
echo "Installed:"
echo "  DXVK         $DXVK_TAG"
echo "  VKD3D-Proton $VKD3D_TAG"
echo "  Prefix       $PREFIX"
