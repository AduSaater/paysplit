# PaySplit Mobile App (Flutter)

PaySplit automatically routes an incoming salary into multiple destinations — goal-based savings wallets and bank transfers to beneficiaries — based on user-defined rules executed every pay cycle.

---

## Tool-Choice & Architecture Writeup

### Platform & Framework: Flutter (Dart)
- **Single codebase, native performance:** Compiles to native ARM machine code on both iOS and Android with 60/120fps rendering, fast cold starts, and consistent fintech UI across devices.
- **Strong typing & null safety:** Dart's sound null safety reduces runtime crashes when handling financial amounts (represented strictly in **kobo** integers/numbers to avoid floating-point rounding bugs).

### Key Libraries & Why
| Library | Purpose | Why Chosen |
|---|---|---|
| `flutter_riverpod` | State management & DI | Lifecycle-aware, compile-safe providers, no `BuildContext` coupling, clean async loading/error/data states. |
| `go_router` | Navigation | Declarative routing, auth redirect guards, `StatefulShellRoute.indexedStack` to preserve tab state across bottom navigation. |
| `dio` | HTTP client | Interceptors for Bearer token injection, 15–20s timeouts, and exponential-backoff retries on transient GET failures. |
| `flutter_secure_storage` | Secret storage | Stores JWT access tokens and setup tokens in iOS Keychain / Android EncryptedSharedPreferences (never in plain SharedPreferences). |
| `shared_preferences` | Offline JSON cache | Caches dashboard summary, wallets, beneficiaries, split rules, transactions, categories, and banks for offline viewing. |
| `connectivity_plus` | Network awareness | Live connectivity stream powering the persistent offline banner. |
| `image_picker` | KYC & profile media | Captures/selects selfies for biometric liveness and ID documents for international KYC. |
| `share_plus` + `path_provider` | Receipts & statements | Exports CSV transaction statements and shares payment receipts natively. |

---

## Project Structure

```
lib/
  app.dart                    # GoRouter configuration, auth guard, bottom navigation shell
  main.dart                   # App bootstrap & SharedPreferences override
  core/
    data/                     # Lookup repository (categories, banks with 24h cache)
    network/                  # Dio client, endpoints, retry/auth interceptors, connectivity
    storage/                  # SecureStorageService & LocalCacheService
    theme/                    # AppColors, AppTextStyles, AppTheme
    utils/                    # CurrencyFormatter (kobo <-> ₦), DateFormatter, Validators
    widgets/                  # Reusable UI library (AppButton, AppTextField, AppCard, StatusBadge, StateViews, OfflineBanner, ConfirmationModal)
  features/
    auth/                     # Signup (3-step), Login, Forgot Password
    kyc/                      # 3-step KYC stepper (Profile, NG BVN/NIN or Intl ID, Biometric Liveness)
    dashboard/                # Salary balance, KYC/setup banners, Run Split Now, QA Simulate Credit, Recent Activity
    wallets/                  # Goal-based wallets, create/edit/delete, move funds back to salary account
    beneficiaries/            # NUBAN account resolution, pause/resume, transfer history
    split_rules/              # Priority-ordered fixed (₦) & percentage (%) rules, allocation bar, split run history
    transactions/             # Filterable history, receipt detail & share, CSV statement export
    settings/                 # Profile, Salary Income Source, Change Password, Notifications, Sign Out
```

---

## Setup & Running Locally

### Prerequisites
- Flutter SDK `3.44.0+` (Dart `3.12.0+`)
- Xcode (for iOS Simulator) or Android Studio / Android Emulator

### Run the App
```bash
flutter pub get
flutter run
```

The app is pre-configured against the PaySplit sandbox API:
`https://paysplit-be-dev-14573850302.europe-west1.run.app/api/v1`

### Run Tests & Static Analysis
```bash
flutter analyze
flutter test
```
