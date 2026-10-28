# CalWidget

Your Google Calendar, as a real macOS widget. CalWidget puts a full month view on your desktop or in Notification Center, reading Google Calendar directly so it doesn't depend on syncing through Apple Calendar.

**Website:** [gcalwidget.marksstuff.com](https://gcalwidget.marksstuff.com) · [Privacy Policy](https://gcalwidget.marksstuff.com/privacy) · [Support](https://gcalwidget.marksstuff.com/support)

---

## Features

- **Month grid** — event chips in each day, including events that span several days
- **Your calendar colors** — reads directly from Google Calendar and keeps the colors you chose
- **Three sizes** — Medium (a mini month with event dots and a "coming up" list), Large and Extra Large
- **Click to open** — click an event to open it in Google Calendar
- **Month arrows and a + button** — browse months and add events without leaving the widget
- **Per-widget style** — Automatic (follows macOS), Light or Dark, plus which calendars each widget shows, from **Edit Widget**
- **Liquid Glass** — works with the macOS Clear and Tinted widget styles, so it can use the system's Liquid Glass look
- **Automatic updates** — updates itself with Sparkle, and shows what's new after each update
- **Private** — no account on our side and no tracking. Your data goes only between your Mac and Google

---

## Requirements

- macOS **26 Tahoe** or later
- A Google account

---

## Installation

### Option 1: Download and Install Manually

1. Download the latest **CalWidget.dmg** from the [Releases](https://github.com/Hitjack007/CalWidget/releases/latest) page
2. Open the DMG and drag **CalWidget** to your Applications folder
3. Before opening, run this once in Terminal to clear the macOS security warning:
   ```bash
   xattr -dr com.apple.quarantine /Applications/CalWidget.app
   ```
4. Open the app and click **Sign in with Google**, then allow read-only access to your calendar
5. Add the widget from Edit Widgets in Notification Center or on the desktop

### Option 2: Install via Homebrew

You can also install using [Homebrew](https://brew.sh). The Homebrew installation automatically bypasses the macOS security warning described above.

```bash
brew install --cask hitjack007/calwidget/calwidget
```

The widget refreshes in the background and shows the current month.

---

## Privacy

The app asks for one permission, `https://www.googleapis.com/auth/calendar.readonly`, and can't create, edit, or delete events. It keeps only each calendar's name and color and each event's title, times, and all-day flag. Data is cached on your Mac and sign-in tokens are kept in a file in `~/Library/Application Support/CalWidget` that only your user account can read. Nothing is sent to us or anyone else, and there are no analytics. Full details are in the [Privacy Policy](https://gcalwidget.marksstuff.com/privacy).

---

## Building from Source

For developers who want to build it themselves:

### Prerequisites

- Xcode with the macOS 27 SDK (the deployment target is macOS 26.0)
- An Apple developer team for signing

### Steps

```bash
git clone https://github.com/Hitjack007/CalWidget.git
cd CalWidget
open CalWidget.xcodeproj
```

1. For both targets (`googleCalendarWidget` and `MonthWidgetExtension`), choose your team under **Signing & Capabilities**. The app and widget share data through files in `~/Library/Application Support/CalWidget`, so no App Group or provisioning profile is needed.
2. Copy `Config/GoogleSecrets.swift.example` to `Shared/GoogleSecrets.swift` and fill in the OAuth client secret. That file is git-ignored, so it never gets committed. To use your own Google client instead, create a **Desktop app** client in the Google Cloud Console and set `clientID` in `Shared/GoogleConfig.swift`.
3. Run the `googleCalendarWidget` scheme with **Cmd + R**, then sign in with Google like any other user.

The app comes with its own Google sign-in built in, so there's nothing to set up in Google Cloud.

### Project layout

| Path | What's in it |
| --- | --- |
| `googleCalendarWidget/` | The macOS app: onboarding, What's New, updates, sign-in, settings panes, calendar selection |
| `MonthWidget/` | The WidgetKit extension |
| `Shared/` | Code used by both: Google API client, models, storage, the month calendar views, OAuth config |
| `CalWidgetTests/` | Unit tests (Swift Testing) for the shared logic |
| `docs/` | The Sparkle appcast and the privacy and support pages |
| `website/` | The static website, deployed with Firebase Hosting |
| `release.sh` | Builds, signs and publishes a release |

### Tests

Run the `googleCalendarWidget` scheme's tests (⌘U), or from the command line:

```bash
xcodebuild test -project CalWidget.xcodeproj -scheme googleCalendarWidget -destination 'platform=macOS'
```

### Debugging

In Debug builds, **General → Serve dummy data in the widget** makes the widget show sample events without a Google sign-in. That switch is compiled out of Release builds.

### Website

The site in `website/public/` is plain HTML and CSS. To preview and deploy it:

```bash
cd website
firebase emulators:start --only hosting   # preview at http://localhost:5050
firebase deploy --only hosting
```

---

## Releasing

Updates are delivered with [Sparkle](https://sparkle-project.org), and each release is also published to the [Homebrew tap](https://github.com/Hitjack007/homebrew-calwidget).

1. Add an entry for the new version to `googleCalendarWidget/WhatsNewCatalog.swift` if it ships anything users should know about.
2. Commit everything and quit Xcode (the script edits the project file to bump the version).
3. Run `./release.sh <version> "<release notes>"`.

The script archives the app, builds and signs a DMG, adds it to `docs/appcast.xml`, creates the GitHub release and updates the cask. It needs `gh` and `create-dmg` (`brew install gh create-dmg`), and the Sparkle signing key in your keychain. The appcast is served by GitHub Pages from `docs/`.

---

## Support

Bugs and feature requests: [open an issue](https://github.com/Hitjack007/CalWidget/issues). You can also email [hitjack007.master@gmail.com](mailto:hitjack007.master@gmail.com) or find me on Discord as `hitjack007`.

---

*This project is not affiliated with or endorsed by Google. Google Calendar is a trademark of Google LLC.*
