# Creative Ease Tailoring & Rentals

Flutter Android client for the existing Creative Ease tailoring and
occasionwear-rental service.

## Current app foundation

- Team sign-in using App ID, username, password, and the selected financial year.
- Financial years are loaded from the existing API for the entered App ID.
- The session token is stored using Android secure storage; the password is
  never persisted.
- A 4-digit MPIN is stored with the session in Android secure storage and locks
  the app when it returns from the background. Fingerprint unlock is optional
  on devices with enrolled biometrics; the MPIN remains available as a fallback.
- Signing out removes the saved session, MPIN, and biometric-unlock preference.
- Dashboard totals, tailoring/rental status counts, rental due/overdue counts,
  and recent payments load from the existing API.
- Admins can see both tailoring (stitching) and rental workflows. Rental users
  see rental bookings, delivery, alterations, returns, and rental alerts; tailor
  users see the tailoring workflow only.
- The admin Masters drawer opens a separate Item Master screen (not the rental
  catalogue) with item name, group, unit, rate, and active status. Group, size,
  color, measurement, and process masters have create forms; units, tailors, and
  voucher series follow the Angular reference as list screens.
- The tailoring workspace provides date-filtered orders, stitching-order entry
  with item variants, measurements, photos, and advance payment, unassigned-item
  assignment, tailor-job receipt, pre-fit approval or alteration measurements,
  status-filtered all-orders, and barcode-based invoice generation.
- The rental workspace provides date-filtered catalogue availability, a rental
  cart, catalogue item creation from existing Item Master entries or by adding
  a new master item first with its group, unit, item rate, and active status.
  Groups can also be added while creating an item. The flow supports
  size/colour creation when a master option is missing, stock variants, and
  photos attached from files or captured with the camera,
  searchable customer selection with inline customer creation, and booking with
  payment and security-deposit tracking. When alterations are required, each
  booking item can store measurements and an assigned tailor, matching the
  Angular rental booking flow. It also supports booking-to-delivery conversion
  and item-level returns with damage, late-fee,   and settlement handling.
- The Reports area includes the seven Angular reports: Active Rentals, Bookings
  In Hand, Tailoring Orders, Alteration Issue Pending, Returned Rentals,
  Customer Ledger, and Cash Flow Summary. Report filters, totals, ledger
  balances, and cash-flow account summaries load from the existing API.
- The app assistant is available from a floating button across the dashboard
  workflows. It searches signed-in customer, tailoring order, rental booking,
  catalogue, and Item Master records. Voice input starts only after tapping the
  microphone, and spoken assistant replies can be toggled on or off. Saying
  “create new item” opens Item Master directly into its add-item form. Other
  create requests open the existing validated forms; the assistant never saves
  an order or rental directly. This version uses app-aware search and command
  routing rather than a generative AI service; a conversational model requires
  a secured backend endpoint and must not use an API key bundled in the mobile
  app.
- The dashboard follows a light blue-and-white studio layout with frosted-glass
  panels, role-aware workflow cards, quick navigation, and recent payments.
- Customer-management and remaining workflow refinements are planned for a
  later implementation pass from the Angular reference.

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
