#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$project_dir/Support/Info.plist")"
archive_path="$project_dir/dist/ImpactBar-$version-macOS-universal.zip"
checksum_path="$archive_path.sha256"

IMPACTBAR_UNIVERSAL=1 "$project_dir/scripts/build-app.sh" >/dev/null
ditto -c -k --sequesterRsrc --keepParent \
    "$project_dir/dist/ImpactBar.app" \
    "$archive_path"

(
    cd "$project_dir/dist"
    shasum -a 256 "${archive_path:t}" > "${checksum_path:t}"
)

echo "$archive_path"
echo "$checksum_path"
