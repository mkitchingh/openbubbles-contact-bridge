# Google OAuth setup for the dry run

The bridge uses its own Google desktop OAuth session. It never reads or reuses
OpenBubbles tokens.

1. Create or select a Google Cloud project.
2. Configure the OAuth consent screen. While the app remains in testing, add
   the Google accounts that will test it.
3. Create an OAuth client with application type **Desktop app**.
4. Download the client JSON. Do not commit that file to this repository.
5. Extract the complete Windows artifact, close OpenBubbles including its tray
   icon, and double-click `Start-OpenBubblesGoogleDryRun.cmd`.
6. Select the downloaded OAuth JSON, choose where to save the redacted report,
   and complete authorization in the system browser.

The browser flow uses a random loopback port, state verification, and PKCE. The
bridge requests only `https://www.googleapis.com/auth/carddav`. The access token
is held in memory for the one fetch and is neither written to disk nor included
in the report. No refresh token is requested or retained.

Google requires HTTPS plus OAuth 2.0 for CardDAV and requires clients to
discover resource URLs rather than hard-code them:

- https://developers.google.com/people/carddav
- https://developers.google.com/identity/protocols/oauth2/native-app
- https://developers.google.com/identity/protocols/oauth2/resources/best-practices

For broad public distribution, the repository owner will need a production
OAuth consent configuration and may need Google verification for the requested
scope. The configurable JSON flow lets contributors test without publishing
anyone else's OAuth client credentials.
