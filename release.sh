#!/bin/bash
set -euo pipefail

# Usage: ./release.sh <version> "<notes>"
# e.g.   ./release.sh 1.1 "Click an event to open it, optional Calendar app support"
#
# Bumps the version, archives, builds a signed DMG, updates the Sparkle appcast, creates the
# GitHub release and updates the Homebrew cask.
#
# Before running: add a WhatsNewCatalog entry for the version if it ships anything new, and
# close Xcode (the script edits the project file to bump the version).
VERSION="${1:?Usage: ./release.sh <version> \"<release notes>\"}"
NOTES="${2:?Please provide release notes as the second argument}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PBXPROJ="$SCRIPT_DIR/CalWidget.xcodeproj/project.pbxproj"
SCHEME="googleCalendarWidget"
APP_NAME="CalWidget"
BUNDLE_ID="com.hitjack007.calwidget"
REPO="Hitjack007/CalWidget"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
ARCHIVE_PATH="/tmp/${APP_NAME}-${VERSION}.xcarchive"
DMG_PATH="/tmp/${DMG_NAME}"
APPCAST="$SCRIPT_DIR/docs/appcast.xml"
BUILD_NUM=$(date +%Y%m%d%H%M)
TAP_REPO="Hitjack007/homebrew-calwidget"
CASK_NAME="calwidget"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ${APP_NAME} release script v${VERSION}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Preflight checks ────────────────────────────────────────────────────────

echo "→ Checking dependencies..."

if ! command -v gh &>/dev/null; then
    echo "Error: GitHub CLI (gh) not found. Install with: brew install gh"
    exit 1
fi

if ! command -v create-dmg &>/dev/null; then
    echo "Error: create-dmg not found. Install with: brew install create-dmg"
    exit 1
fi

SPARKLE_BIN=$(find ~/Library/Developer/Xcode/DerivedData/CalWidget-*/SourcePackages/artifacts -name "sign_update" -path "*/sparkle/Sparkle/bin/*" -not -path "*old_dsa_scripts*" 2>/dev/null | head -1)
if [ -z "$SPARKLE_BIN" ]; then
    echo "Error: Sparkle sign_update not found. Open the project in Xcode once to resolve packages."
    exit 1
fi
echo "  sign_update: $SPARKLE_BIN"

# The public key in Info.plist must match the private key in the keychain, or users' Macs
# will reject the update.
PLIST_KEY=$(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "$SCRIPT_DIR/googleCalendarWidget/Info.plist")
KEYCHAIN_KEY=$("$(dirname "$SPARKLE_BIN")/generate_keys" -p)
if [ "$PLIST_KEY" != "$KEYCHAIN_KEY" ]; then
    echo "Error: SUPublicEDKey in Info.plist doesn't match the Sparkle key in your keychain."
    exit 1
fi

if pgrep -x Xcode >/dev/null; then
    echo "Error: Xcode is running. Quit it first, because this script edits the project file."
    exit 1
fi

if git -C "$SCRIPT_DIR" status --short | grep -q '^[MADRC]'; then
    echo "Error: You have staged changes. Commit or stash them before releasing."
    exit 1
fi

if git -C "$SCRIPT_DIR" rev-parse "v${VERSION}" &>/dev/null; then
    echo "Error: tag v${VERSION} already exists."
    exit 1
fi

WHATSNEW_CATALOG="$SCRIPT_DIR/googleCalendarWidget/WhatsNewCatalog.swift"
if ! grep -q "version: \"${VERSION}\"" "$WHATSNEW_CATALOG"; then
    echo ""
    echo "⚠️  Warning: WhatsNewCatalog.swift has no entry for version \"${VERSION}\"."
    echo "   Patch releases legitimately have no highlights, but if this release ships"
    echo "   a feature, users won't be introduced to it in-app."
    read -p "   Continue anyway? [y/N] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# ── Bump version in Xcode project ───────────────────────────────────────────
# The app, widget extension and tests all share the version, because an embedded
# extension must match its host app.

echo ""
echo "→ Bumping version to ${VERSION} (build ${BUILD_NUM})..."
sed -i '' -E \
    -e "s/(MARKETING_VERSION = )[0-9][0-9.]*;/\1${VERSION};/" \
    -e "s/(CURRENT_PROJECT_VERSION = )[0-9]+;/\1${BUILD_NUM};/" \
    "$PBXPROJ"
echo "  MARKETING_VERSION = ${VERSION}"
echo "  CURRENT_PROJECT_VERSION = ${BUILD_NUM}"

echo ""
echo "→ Committing version bump..."
cd "$SCRIPT_DIR"
git add CalWidget.xcodeproj/project.pbxproj
git commit -m "Bump version to ${VERSION}"

# ── Resolve minimum supported macOS version ─────────────────────────────────

echo ""
echo "→ Resolving minimum macOS version from build settings..."
MIN_OS_VERSION=$(xcodebuild -showBuildSettings \
    -project "$SCRIPT_DIR/CalWidget.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release 2>/dev/null \
    | awk -F '= ' '$1 ~ /^[[:space:]]*MACOSX_DEPLOYMENT_TARGET[[:space:]]*$/ { print $2; exit }')

if [ -z "$MIN_OS_VERSION" ]; then
    echo "Error: Could not resolve MACOSX_DEPLOYMENT_TARGET from build settings."
    exit 1
fi
echo "  Minimum macOS version: $MIN_OS_VERSION"

# ── Archive ──────────────────────────────────────────────────────────────────

echo ""
echo "→ Archiving (this takes a minute)..."
rm -rf "$ARCHIVE_PATH"
xcodebuild archive \
    -project "$SCRIPT_DIR/CalWidget.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    SKIP_INSTALL=NO \
    2>&1 | grep -E "^(error:|\*\* ARCHIVE)" || true

APP_PATH=$(find "$ARCHIVE_PATH/Products" -name "*.app" -maxdepth 3 | head -1)
if [ -z "$APP_PATH" ]; then
    echo "Error: No .app found in archive. Check Xcode signing settings."
    exit 1
fi
echo "  App: $APP_PATH"

# ── DMG ──────────────────────────────────────────────────────────────────────

echo ""
echo "→ Creating DMG..."
rm -f "$DMG_PATH"
STAGING="/tmp/${APP_NAME}-staging-$$"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"

create-dmg \
    --volname "${APP_NAME}" \
    --window-pos 200 120 \
    --window-size 660 400 \
    --icon-size 128 \
    --icon "${APP_NAME}.app" 180 185 \
    --hide-extension "${APP_NAME}.app" \
    --app-drop-link 480 185 \
    --no-internet-enable \
    "$DMG_PATH" \
    "$STAGING/" 2>&1 | grep -v "^$" || true

rm -rf "$STAGING"
if [ ! -f "$DMG_PATH" ]; then
    echo "Error: DMG was not created."
    exit 1
fi
echo "  Created: $DMG_PATH ($(du -sh "$DMG_PATH" | cut -f1))"

# ── Sparkle signing ───────────────────────────────────────────────────────────

echo ""
echo "→ Signing DMG with Sparkle..."
SIGN_OUTPUT=$("$SPARKLE_BIN" "$DMG_PATH" 2>&1)
ED_SIG=$(echo "$SIGN_OUTPUT" | grep -oE 'edSignature="[^"]+"' | head -1 | cut -d'"' -f2)
FILE_LEN=$(echo "$SIGN_OUTPUT" | grep -oE 'length="[0-9]+"' | head -1 | cut -d'"' -f2)

if [ -z "$ED_SIG" ] || [ -z "$FILE_LEN" ]; then
    echo "Error: Could not parse Sparkle signature. Output was:"
    echo "$SIGN_OUTPUT"
    exit 1
fi
echo "  edSignature: ${ED_SIG:0:20}..."
echo "  length: $FILE_LEN"

# ── Update appcast.xml ────────────────────────────────────────────────────────

echo ""
echo "→ Updating appcast.xml..."
RELEASE_DATE=$(date -u "+%a, %d %b %Y %H:%M:%S +0000")
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/v${VERSION}/${DMG_NAME}"

python3 - "$APPCAST" "$VERSION" "$BUILD_NUM" "$RELEASE_DATE" "$DOWNLOAD_URL" "$ED_SIG" "$FILE_LEN" "$MIN_OS_VERSION" <<'PYEOF'
import sys
path, version, build, date, url, sig, length, min_os = sys.argv[1:]
new_item = (
    f"\n    <item>\n"
    f"      <title>Version {version}</title>\n"
    f"      <pubDate>{date}</pubDate>\n"
    f"      <sparkle:version>{build}</sparkle:version>\n"
    f"      <sparkle:shortVersionString>{version}</sparkle:shortVersionString>\n"
    f"      <sparkle:minimumSystemVersion>{min_os}</sparkle:minimumSystemVersion>\n"
    f"      <enclosure\n"
    f"        url=\"{url}\"\n"
    f"        sparkle:edSignature=\"{sig}\"\n"
    f"        length=\"{length}\"\n"
    f"        type=\"application/octet-stream\"/>\n"
    f"    </item>"
)
content = open(path).read()
content = content.replace('  </channel>', new_item + '\n\n  </channel>', 1)
open(path, 'w').write(content)
print(f"  Added v{version} entry")
PYEOF

# ── GitHub release ─────────────────────────────────────────────────────────

echo ""
echo "→ Creating GitHub release v${VERSION}..."
gh release create "v${VERSION}" "$DMG_PATH" \
    --repo "$REPO" \
    --title "${APP_NAME} v${VERSION}" \
    --notes "$NOTES"

# ── Homebrew cask ────────────────────────────────────────────────────────────
# Homebrew's `depends_on macos:` only accepts codename symbols, not raw version
# numbers, so MIN_OS_VERSION is mapped to the matching symbol. This keeps the cask's
# OS gate in sync with Sparkle's minimumSystemVersion.

echo ""
echo "→ Resolving Homebrew macOS codename for ${MIN_OS_VERSION}..."
MIN_OS_MAJOR="${MIN_OS_VERSION%%.*}"
case "$MIN_OS_MAJOR" in
    11) MACOS_CODENAME="big_sur" ;;
    12) MACOS_CODENAME="monterey" ;;
    13) MACOS_CODENAME="ventura" ;;
    14) MACOS_CODENAME="sonoma" ;;
    15) MACOS_CODENAME="sequoia" ;;
    26) MACOS_CODENAME="tahoe" ;;
    27) MACOS_CODENAME="golden_gate" ;;
    *)
        echo "Error: No Homebrew codename mapping for macOS major version ${MIN_OS_MAJOR}."
        echo "Add it to the case statement in release.sh before releasing."
        exit 1
        ;;
esac
echo "  depends_on macos: :${MACOS_CODENAME}"

echo ""
echo "→ Publishing Homebrew cask to ${TAP_REPO}..."
if ! gh repo view "$TAP_REPO" &>/dev/null; then
    echo "  Tap repo doesn't exist yet. Creating it..."
    gh repo create "$TAP_REPO" --public \
        --description "Homebrew tap for CalWidget" >/dev/null
fi

CASK_SHA256=$(shasum -a 256 "$DMG_PATH" | cut -d' ' -f1)
TAP_CLONE="/tmp/homebrew-calwidget-$$"
rm -rf "$TAP_CLONE"
gh repo clone "$TAP_REPO" "$TAP_CLONE" -- -q
mkdir -p "$TAP_CLONE/Casks"

cat > "$TAP_CLONE/Casks/${CASK_NAME}.rb" <<CASKEOF
cask "${CASK_NAME}" do
  version "${VERSION}"
  sha256 "${CASK_SHA256}"

  url "${DOWNLOAD_URL}"
  name "CalWidget"
  desc "Month view of your Google Calendar as a macOS widget"
  homepage "https://gcalwidget.marksstuff.com"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: :${MACOS_CODENAME}

  app "CalWidget.app"

  # Clears the quarantine flag so macOS doesn't show its security warning on first open.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/CalWidget.app"]
  end

  uninstall quit: "${BUNDLE_ID}"

  zap trash: [
    "~/Library/Application Scripts/${BUNDLE_ID}",
    "~/Library/Application Scripts/${BUNDLE_ID}.widget",
    "~/Library/Containers/${BUNDLE_ID}",
    "~/Library/Containers/${BUNDLE_ID}.widget",
    "~/Library/Group Containers/*.${BUNDLE_ID}",
  ]
end
CASKEOF

cd "$TAP_CLONE"
git add "Casks/${CASK_NAME}.rb"
if git diff --cached --quiet; then
    echo "  No cask changes to publish"
else
    git commit -m "Update ${CASK_NAME} to v${VERSION}"
    git push
    echo "  Cask updated: v${VERSION}"
fi
cd "$SCRIPT_DIR"
rm -rf "$TAP_CLONE"

# ── Push everything ───────────────────────────────────────────────────────────

echo ""
echo "→ Pushing appcast..."
cd "$SCRIPT_DIR"
git add docs/appcast.xml
git commit -m "Release v${VERSION}"
git push

# ── Done ─────────────────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  v${VERSION} shipped!"
echo "  https://github.com/${REPO}/releases/tag/v${VERSION}"
echo "  Install: brew install --cask Hitjack007/calwidget/${CASK_NAME}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
