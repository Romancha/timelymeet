#!/usr/bin/env bash
#
# Publishes a GitHub release with a notarized TimelyMeet.dmg in one command.
#
# Usage: scripts/release.sh
#
# Before running:
#   1. Bump MARKETING_VERSION / CURRENT_PROJECT_VERSION and add the version to release_notes.json
#   2. Commit and push to master
#
# The script takes the version from the Xcode project, checks everything it can up front, builds and
# notarizes the DMG, shows the release notes generated from release_notes.json, and after confirmation
# creates the tag and the GitHub release with the DMG attached, then bumps the Homebrew cask.
# Safe to re-run after a failure.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO="Romancha/timelymeet"
TAP_REPO="Romancha/homebrew-tap"
CASK_PATH="Casks/timelymeet.rb"
NOTES_JSON="$ROOT_DIR/TimelyMeet/Resources/release_notes.json"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
DMG_PATH="$BUILD_DIR/TimelyMeet.dmg"
NOTES_MD="$BUILD_DIR/release-notes.md"
NOTARY_KEYCHAIN_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-timelymeet}"

log() { echo "==> $*"; }
fail() { echo "Error: $*" >&2; exit 1; }

# Sets version and sha256 in the tap's cask via the GitHub API (no local clone needed).
# The checksum comes from the published release asset, i.e. exactly what users download.
update_homebrew_cask() {
    local dmg_sha cask file_sha current updated
    dmg_sha=$(gh release view "$VERSION" --repo "$REPO" --json assets \
        --jq '.assets[] | select(.name == "TimelyMeet.dmg") | .digest | sub("^sha256:"; "")') || return 1
    [[ -n "$dmg_sha" ]] || { echo "TimelyMeet.dmg not found in release $VERSION" >&2; return 1; }
    cask=$(gh api "repos/$TAP_REPO/contents/$CASK_PATH") || return 1
    file_sha=$(jq -r '.sha' <<<"$cask")
    current=$(jq -r '.content' <<<"$cask" | base64 --decode)
    updated=$(sed -E \
        -e "s/^  version \".*\"$/  version \"$VERSION\"/" \
        -e "s/^  sha256 \".*\"$/  sha256 \"$dmg_sha\"/" <<<"$current")

    if [[ "$updated" == "$current" ]]; then
        log "Homebrew cask is already at $VERSION"
        return 0
    fi
    gh api -X PUT "repos/$TAP_REPO/contents/$CASK_PATH" \
        -f message="timelymeet $VERSION" \
        -f content="$(base64 <<<"$updated")" \
        -f sha="$file_sha" > /dev/null || return 1
    log "Homebrew cask updated to $VERSION"
}

cd "$ROOT_DIR"

# --- Checks (fast, before the multi-minute build) ---

VERSION=$(xcodebuild -project TimelyMeet.xcodeproj -scheme TimelyMeet -configuration Release -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/ MARKETING_VERSION = / { print $2; exit }')
[[ -n "$VERSION" ]] || fail "could not read MARKETING_VERSION from the Xcode project"
log "Releasing TimelyMeet $VERSION"

[[ "$(git branch --show-current)" == "master" ]] || fail "switch to master first"
# Untracked files count too: Xcode compiles every file in the synchronized TimelyMeet/ folder
[[ -z "$(git status --porcelain -- TimelyMeet TimelyMeet.xcodeproj scripts)" ]] \
    || fail "app sources have uncommitted or untracked changes; commit or stash them first"
git fetch --quiet origin master --tags
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/master)" ]] \
    || fail "local master differs from origin/master; push or pull first"

if git rev-parse -q --verify "refs/tags/$VERSION" > /dev/null; then
    [[ "$(git rev-list -n 1 "$VERSION")" == "$(git rev-parse HEAD)" ]] \
        || fail "tag $VERSION already exists on another commit; bump MARKETING_VERSION"
fi
if gh release view "$VERSION" --repo "$REPO" --json isDraft --jq '.isDraft' 2>/dev/null | grep -q false; then
    log "Release $VERSION is already published; only making sure the Homebrew cask is up to date"
    update_homebrew_cask || fail "could not update the Homebrew cask"
    exit 0
fi

jq -e --arg v "$VERSION" '.releaseNotes[] | select(.version == $v)' "$NOTES_JSON" > /dev/null \
    || fail "release_notes.json has no entry for $VERSION"

xcrun notarytool history --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" > /dev/null 2>&1 \
    || fail "notarization profile '$NOTARY_KEYCHAIN_PROFILE' not found; see scripts/build-dmg.sh for one-time setup"
gh api "repos/$TAP_REPO/contents/$CASK_PATH" --silent \
    || fail "cannot read $CASK_PATH in $TAP_REPO"

# --- Build ---

EXPECTED_VERSION="$VERSION" NOTARY_KEYCHAIN_PROFILE="$NOTARY_KEYCHAIN_PROFILE" BUILD_DIR="$BUILD_DIR" \
    "$ROOT_DIR/scripts/build-dmg.sh"

# --- Release notes, same format as previous releases ---

PREVIOUS_TAG=$(git describe --tags --abbrev=0 --exclude "$VERSION" HEAD 2>/dev/null || true)
{
    jq -r --arg v "$VERSION" '
        (.releaseNotes[] | select(.version == $v) | .changes) as $changes
        | [["feature", "✨ New Features:"], ["improvement", "⬆️ Improvements:"], ["bugfix", "🐞 Bug Fixes:"]]
        | map(. as [$type, $title]
              | [$changes[] | select(.type == $type) | " - " + .description.en]
              | select(length > 0)
              | ([$title] + .) | join("\n"))
        | join("\n\n")
    ' "$NOTES_JSON"
    if [[ -n "$PREVIOUS_TAG" ]]; then
        echo
        echo "**Full Changelog**: https://github.com/$REPO/compare/$PREVIOUS_TAG...$VERSION"
    fi
} > "$NOTES_MD"

echo
echo "------------------------------------------------------------"
echo "Release $VERSION   (DMG: $(du -h "$DMG_PATH" | cut -f1 | tr -d ' '))"
echo "------------------------------------------------------------"
cat "$NOTES_MD"
echo "------------------------------------------------------------"
read -r -p "Publish release $VERSION to GitHub? [y/N] " answer
[[ "$answer" == "y" || "$answer" == "Y" ]] || { echo "Aborted; nothing was published"; exit 1; }

# --- Publish ---

if ! git rev-parse -q --verify "refs/tags/$VERSION" > /dev/null; then
    git tag "$VERSION"
fi
git push --quiet origin "refs/tags/$VERSION"

if gh release view "$VERSION" --repo "$REPO" > /dev/null 2>&1; then
    # A draft left by an earlier attempt: refresh its notes and asset, then publish
    gh release upload "$VERSION" "$DMG_PATH" --clobber --repo "$REPO"
    gh release edit "$VERSION" --title "Release $VERSION" --notes-file "$NOTES_MD" --draft=false --repo "$REPO"
else
    gh release create "$VERSION" "$DMG_PATH" --title "Release $VERSION" --notes-file "$NOTES_MD" --repo "$REPO"
fi

log "Published: https://github.com/$REPO/releases/tag/$VERSION"

# The release is already out at this point, so a tap failure only warns; re-running the script finishes it
update_homebrew_cask \
    || echo "Warning: Homebrew cask was not updated; re-run scripts/release.sh to retry" >&2
