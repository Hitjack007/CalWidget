# Privacy Policy

**CalWidget**
Last updated: 25 October 2026

This policy explains what CalWidget ("the app") does with your data. The short version: **your data stays on your Mac. We don't collect it, store it, or see it.**

## Who we are

The app is a free, open-source project by Hitjack007 ([github.com/Hitjack007](https://github.com/Hitjack007)). Contact: [CONTACT EMAIL].

## What the app accesses

When you sign in with Google, the app requests one permission (OAuth scope):

- `https://www.googleapis.com/auth/calendar.readonly` — read-only access to your Google Calendar events and calendar list (names and colors).

The app can't create, modify, or delete anything in your calendar.

## How your data is used

Calendar data is used only to display events in the widget and in the app's window. Nothing else.

## Where your data goes

- Your Mac talks **directly to Google's servers**. There is no server run by us in between.
- Event data is cached locally on your Mac, in a container shared between the app and its widget, so the widget can display it.
- Your Google sign-in tokens are stored in a file in `~/Library/Application Support/CalWidget` that only your macOS user account can read.
- We run no analytics, advertising, crash reporting, or tracking of any kind.
- We don't sell, share, or transfer your data to anyone. We don't receive it in the first place.

## Google API Services User Data Policy

The app's use and transfer of information received from Google APIs to any other app will adhere to the [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy), including the Limited Use requirements. Google user data is not used for advertising, is not used to train AI or machine-learning models, and is not read by humans.

## Google sign-in

Sign-in uses a Google OAuth client registered by the developer of CalWidget. The client ID identifies the app to Google. It doesn't give the developer any access to your account or data. Your sign-in tokens are issued to the app on your Mac, and only your Mac holds them. We never receive them.

## Retention and deletion

- **Remove the cached data:** quit the app and delete it. Choose "Sign out" in the app to clear the local cache and stored tokens.
- **Revoke access at any time:** visit [myaccount.google.com/permissions](https://myaccount.google.com/permissions), select the app, and choose "Remove access".

Because we hold no copy of your data, there is nothing for us to delete on our side.

## Children

The app isn't directed at children under 13, and we don't knowingly collect any data from anyone.

## Changes

If this policy changes, the updated version will be posted here with a new date. The full history is in the project's GitHub repository.

## Contact

Questions about this policy: [CONTACT EMAIL] or open an issue at [github.com/Hitjack007/googleCalendarWidget/issues](https://github.com/Hitjack007/googleCalendarWidget/issues).
