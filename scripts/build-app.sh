#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
app_dir="$project_dir/dist/ImpactBar.app"
contents_dir="$app_dir/Contents"
module_cache_dir="$project_dir/.build/module-cache"
package_cache_dir="$project_dir/.build/cache"
asset_info_plist="$project_dir/.build/asset-info.plist"
sign_identity="${IMPACTBAR_SIGN_IDENTITY:--}"

architecture_args=()
if [[ "${IMPACTBAR_UNIVERSAL:-0}" == "1" ]]; then
    architecture_args=(--arch arm64 --arch x86_64)
fi

mkdir -p "$module_cache_dir" "$package_cache_dir"
export CLANG_MODULE_CACHE_PATH="$module_cache_dir"
export SWIFTPM_MODULECACHE_OVERRIDE="$module_cache_dir"
export XDG_CACHE_HOME="$package_cache_dir"

swift build \
    --package-path "$project_dir" \
    -c release \
    --disable-sandbox \
    -debug-info-format none \
    "${architecture_args[@]}"
binary_dir="$(swift build \
    --package-path "$project_dir" \
    -c release \
    --disable-sandbox \
    -debug-info-format none \
    "${architecture_args[@]}" \
    --show-bin-path)"

if [[ -d "$app_dir" ]]; then
    rm -rf "$app_dir"
fi

mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp "$binary_dir/ImpactBar" "$contents_dir/MacOS/ImpactBar"
cp "$project_dir/Support/Info.plist" "$contents_dir/Info.plist"
xcrun actool "$project_dir/Resources/Assets.xcassets" \
    --compile "$contents_dir/Resources" \
    --platform macosx \
    --minimum-deployment-target 13.0 \
    --app-icon AppIcon \
    --output-partial-info-plist "$asset_info_plist" \
    >/dev/null
xattr -cr "$app_dir"

signing_args=(--force --deep --sign "$sign_identity")
if [[ "$sign_identity" != "-" ]]; then
    signing_args+=(--options runtime --timestamp)
fi
codesign "${signing_args[@]}" "$app_dir"

echo "$app_dir"
