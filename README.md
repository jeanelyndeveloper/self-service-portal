# Self Service Portal - Flutter Web App

A Flutter web application for Ipsos interviewers to self-manage their devices and applications.

## Features

- **New Interviewer Onboarding**: Email and mobile number verification, device setup, and interactive instructions for:
  - WiFi connection
  - Microsoft Teams setup
  - Ipsos app installation (iReach, etc.)
  - Android showcard synchronization
  - Helpdesk contact information

- **Existing Interviewer Dashboard**: 
  - Self-service iReach app updates
  - Device management
  - Support access

## Prerequisites

- Flutter SDK 3.0 or higher
- Dart 3.0 or higher

## Getting Started

### 1. Install Flutter dependencies

```bash
flutter pub get
```

### 2. Run the web app in development mode

Start the local API proxy in one terminal:

```bash
dart run tool/dev_api_proxy.dart
```

For new interviewer verification, the proxy authenticates to the BO API from
the server side. Provide the BO service account through environment variables;
do not put these credentials in Flutter Web code:

```bash
BO_API_ADMIN_USERNAME=... \
BO_API_ADMIN_PASSWORD=... \
dart run tool/dev_api_proxy.dart
```

For the existing-interviewer I-Reach update, configure the device-platform
values on the proxy process. Copy `.env.example` into your server secret
configuration; the Dart proxy does not load `.env` files automatically.

```bash
RMM_API_BASE_URL=... \
RMM_SYSTEM_TOKEN=... \
RMM_IREACH_SCRIPT_ID=130 \
dart run tool/dev_api_proxy.dart
```

The proxy keeps the system token and script ID server-side. The browser sends
only the confirmed `computerName` to `POST /update-ireach`. The proxy queries
`GET /agents/`, matches `hostname` to the computer name, extracts `agent_id`,
and calls `POST /agents/{agent_id}/runscript/` with output mode `wait` and a
90-second script timeout.

For local development, the proxy automatically loads a git-ignored `.env`
file from the project root. Real server environment variables take precedence.

The proxy uses `https://smstg.ipsos.co.nz` by default for existing interviewer
SMS API requests, including `POST /api/v1/Authentication`. BO requests for new
interviewer verification use `https://boapistg.ipsos.co.nz`. You can override
them with `DEV_API_PROXY_TARGET` and `BO_API_BASE_URL`.

Then run the Flutter web app in another terminal:

```bash
flutter run -d chrome
```

The app will open in your default Chrome browser at `http://localhost:port`

To bypass the local proxy and point directly at a specific API base URL, pass it
explicitly:

```bash
flutter run -d chrome --dart-define=APP_API_BASE_URL=https://smstg.ipsos.co.nz
```

### 3. Build for production

```bash
flutter build web --release
```

The production build will be available in the `build/web` directory.

## Project Structure

```
lib/
├── main.dart                 # App entry point and routing
├── models/
│   └── device_type.dart     # Device type enum and utilities
├── screens/
│   ├── auth_screen.dart                      # Initial auth selection
│   ├── new_interviewer_screen.dart           # New interviewer login
│   ├── existing_interviewer_screen.dart      # Existing interviewer login
│   ├── existing_interviewer_dashboard.dart   # Existing interviewer dashboard
│   ├── device_setup_screen.dart              # Device setup and instructions
│   └── update_ireach_screen.dart             # iReach update workflow
├── services/
│   └── auth_service.dart    # API communication and authentication
├── providers/
│   └── auth_provider.dart   # Authentication state management
└── widgets/
    ├── auth_button.dart         # Reusable button for auth options
    ├── loading_dialog.dart      # Loading indicator dialog
    └── setup_instruction.dart   # Expandable instruction widget
```

## Configuration

### API Endpoints

Update the `baseUrl` in `lib/services/auth_service.dart` with your backend API:

```dart
static const String baseUrl = 'https://your-api.example.com';
```

### Device Validation

Replace the mock device validation in `validateDeviceId()` with calls to your RMM (Remote Management Manager) API.

### iReach Update Script

Replace the mock update execution in `executeIReachUpdate()` with calls to your RMM API to trigger the update script.

## Dependencies

- **flutter**: Flutter framework
- **provider**: State management
- **go_router**: Navigation and routing
- **http**: HTTP client for API calls
- **google_fonts**: Google fonts integration

## Authentication Flow

### New Interviewer
1. Select "New Interviewer" on auth screen
2. Enter email and last 4 digits of phone number
3. The server-side proxy authenticates to the BO API with the service account
4. The proxy looks up the Surveyor record by email and validates the mobile number
5. Receive assigned device details and device-specific setup instructions
6. Follow the setup steps to complete onboarding

### Existing Interviewer
1. Select "Existing Interviewer" on auth screen
2. Enter username and password
3. Authenticate through the SMS API at `https://smstg.ipsos.co.nz/api/v1/Authentication`
4. Retrieve the signed-in profile from `https://smstg.ipsos.co.nz/api/v1/Users` using the `sm-authorize` token
5. Access dashboard with options including:
   - Update iReach application
   - View device information
   - Contact support

## Update Workflow (Existing Interviewer)

1. Go to dashboard and select "Update iReach"
2. Enter device ID
3. Confirm device is valid
4. Close iReach application
5. Confirm closure and start update
6. Update runs automatically via RMM API
7. Device restarts and iReach reopens with new version

## Contributing

When adding new features:

1. Keep screens focused on their primary task
2. Use the provider pattern for state management
3. Add helpful error messages and loading states
4. Test on both desktop and mobile viewports
5. Follow Flutter style guide conventions

## Support

For issues or questions:
- Email: helpdesk@ipsos.com
- Phone: 0800 478 783
- Hours: 7 days, 9AM-8PM (Local Time)

## License

Internal use only - Ipsos Limited
# interviewer-self-service-portal-
