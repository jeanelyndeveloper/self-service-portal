# Security Contract

This Flutter Web app must not call Ipsos staging or BO APIs directly from the browser.

## Secret Handling

- Do not embed BO admin credentials, platform tokens, script IDs, or API sessions in Flutter code, Dart defines, JavaScript, or static assets.
- Store BO admin credentials and platform tokens only in the backend/proxy secret store.
- The browser may send interviewer-entered credentials only to this app's backend proxy over HTTPS.
- Backend logs must redact passwords, session tokens, platform tokens, phone numbers, and request/response bodies that contain credentials.

## Required Backend Proxy Routes

The Flutter app expects these same-origin routes under `APP_API_BASE_URL`:

- `POST /existing-interviewer/authentication`
  - Body: `{ "username": "...", "password": "..." }`
  - Backend action: calls `https://smstg.ipsos.co.nz/api/v1/Authentication`.
  - Returns a short-lived session/token response to the client.

- `GET /existing-interviewer/user`
  - Header from client: `X-Session-Token`
  - Backend action: calls the staging user profile API using the correct Ipsos session header.
  - Returns only safe profile fields needed by the UI, including name and computer/device ID.

- `POST /new-interviewer/verify`
  - Body: `{ "email": "...", "lastFourDigits": "1234" }`
  - Backend action: authenticates to `https://boapistg.ipsos.co.nz/boapi/v1/Authentication` with server-side admin credentials, searches BO users, validates phone digits, and returns only safe setup fields.

- `POST /ireach/update`
  - Body: `{ "hostname": "IPLT569" }`
  - Backend action: uses the server-side BO/platform token and script ID to trigger the I-Reach update for the target hostname.

- `GET /devices/{deviceId}`
  - Backend action: returns safe, non-secret device setup metadata.

## Browser Hardening

- The app includes a restrictive Content Security Policy in `index.html`.
- All API calls are same-origin by default through `/api`.
- User-facing errors are sanitized so raw network exceptions, tokens, hosts, and stack details are not displayed.
