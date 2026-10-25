# CalWidget

A native macOS widget that shows a full month view of your Google Calendar, right in Notification Center or on your desktop. It reads Google Calendar directly, so it doesn't depend on syncing through Apple Calendar.

**Website:** [gcalwidget.marksstuff.com](https://gcalwidget.marksstuff.com) · [Privacy Policy](https://gcalwidget.marksstuff.com/privacy) · [Support](https://gcalwidget.marksstuff.com/support)

## Features

- Month grid with event chips in each day, including events that span several days
- Reads directly from Google Calendar, using your calendar colors
- Medium (mini month with event dots and a "coming up" list), Large and Extra Large sizes
- Month arrows and a + button on the widget
- Per-widget style (Dark, Light, Automatic, Custom) and calendars, from **Edit Widget**
- Works with the macOS Clear and Tinted widget styles, so it can use the system's Liquid Glass look
- No account on our side and no tracking. Your data goes only between your Mac and Google

## Using it

1. Open the app and click **Sign in with Google**.
2. Allow read-only access to your calendar.
3. Add the widget from Edit Widgets in Notification Center or on the desktop.

The widget refreshes in the background and shows the current month.

## Privacy

The app asks for one permission, `https://www.googleapis.com/auth/calendar.readonly`, and can't create, edit, or delete events. It keeps only each calendar's name and color and each event's title, times, and all-day flag. Data is cached on your Mac and sign-in tokens are kept in the Keychain. Nothing is sent to us or anyone else, and there are no analytics. Full details are in the [Privacy Policy](https://gcalwidget.marksstuff.com/privacy).

## Building from source

Requirements: Xcode with the macOS 27 SDK (the deployment target is macOS 27.0) and an Apple developer team for signing.

1. Open `CalWidget.xcodeproj`.
2. For both targets (`googleCalendarWidget` and `MonthWidgetExtension`), choose your team under **Signing & Capabilities**. The app and widget share data through an App Group and a Keychain access group that are prefixed with your team ID.
3. Copy `Config/GoogleSecrets.swift.example` to `Shared/GoogleSecrets.swift` and fill in the OAuth client secret. That file is git-ignored, so it never gets committed. To use your own Google client instead, create a **Desktop app** client in the Google Cloud Console and set `clientID` in `Shared/GoogleConfig.swift`.
4. Run the `googleCalendarWidget` scheme, then sign in with Google like any other user.

The app comes with its own Google sign-in built in, so there's nothing to set up in Google Cloud.

## Project layout

| Path | What's in it |
| --- | --- |
| `googleCalendarWidget/` | The macOS app: sign-in, settings panes, calendar selection |
| `MonthWidget/` | The WidgetKit extension |
| `Shared/` | Code used by both: Google API client, models, storage, the month calendar views, OAuth config |
| `CalWidgetTests/` | Unit tests (Swift Testing) for the shared logic |
| `website/` | The static website, deployed with Firebase Hosting |

### Website

The site in `website/public/` is plain HTML and CSS. To preview and deploy it:

```sh
cd website
firebase emulators:start --only hosting   # preview at http://localhost:5050
firebase deploy --only hosting
```

## Tests

Run the `googleCalendarWidget` scheme's tests (⌘U), or from the command line:

```sh
xcodebuild test -project CalWidget.xcodeproj -scheme googleCalendarWidget -destination 'platform=macOS'
```

## Debugging

In Debug builds, **General → Serve dummy data in the widget** makes the widget show sample events without a Google sign-in. That switch is compiled out of Release builds.

## Support

Bugs and feature requests: [open an issue](https://github.com/Hitjack007/CalWidget/issues). You can also email [hitjack007.master@gmail.com](mailto:hitjack007.master@gmail.com) or find me on Discord as `hitjack007`.

---

*This project is not affiliated with or endorsed by Google. Google Calendar is a trademark of Google LLC.*
