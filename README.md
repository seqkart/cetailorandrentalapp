# Creative Ease Tailoring & Rentals

Flutter Android client for the existing Creative Ease tailoring and
occasionwear-rental service.

## Current app foundation

- Team sign-in using App ID, username, password, and the selected financial year.
- Financial years are loaded from the existing API for the entered App ID.
- The session token is stored using Android secure storage; the password is
  never persisted.
- Dashboard totals, rental due/overdue counts, and recent payments load from the
  existing API.
- Customer, measurement, tailoring-order, rental-booking, and return workflows
  are planned for the next implementation pass from the Angular reference.

## Run

```powershell
flutter pub get
flutter run
```

The default API base URL is
`https://tailorapi.creativeease.app/api/v1/`. Override it at build/run time when
needed:

```powershell
flutter run --dart-define=TAILOR_API_BASE_URL=https://your-api.example/api/v1/
```

Never commit App IDs, passwords, access tokens, or production exports. Sign-in
details must be entered by the operator in the app.
