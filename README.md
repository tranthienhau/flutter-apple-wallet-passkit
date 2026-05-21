# flutter-apple-wallet-passkit

Flutter portfolio POC that demonstrates two banking-app integrations:

1. **Apple Wallet in-app payment card provisioning** via
   `PKAddPaymentPassViewController` (`PassKit`), driven from Dart through
   a Swift MethodChannel.
2. **HID Approve SDK** for OTP-signed HTTP requests, exposed to Dart as
   a `Dio` interceptor that stamps `X-HID-OTP` on every outbound call.

This is a **portfolio demo**: the HID Approve SDK and the issuer/TSP are
mocked so the project runs offline without licenses or production
secrets. The shapes of the APIs, the iOS delegate flow, and the
entitlement workflow are real and production-faithful.

## Architecture

```
Flutter (Dart)                        iOS (Swift)
+-------------------+   MethodChan   +--------------------------------+
| WalletService     | <------------> | WalletProvisioningChannel      |
|                   |                |  + PKAddPaymentPassVC          |
|                   |                |  + PKAddPaymentPassRequest     |
|                   |                |  + MockIssuerService           |
+-------------------+                +--------------------------------+
| HidApproveService | <------------> | HidApproveChannel (mock OTP)   |
+-------------------+                +--------------------------------+
        |
        v
+-------------------+
| HidOtpInterceptor |  -> stamps X-HID-OTP / X-HID-Request-Id on Dio
+-------------------+
```

Layers in `lib/`:

- `app/` - root widget, routing (`go_router`), Material 3 + dark theme.
- `screens/` - Wallet, Transactions, Settings.
- `widgets/` - `AddToWalletButton` (PKAddPassButton lookalike), tiles,
  status rows.
- `services/` - `WalletService`, `HidApproveService`,
  `SecureStorageService`.
- `state/` - `WalletController` Riverpod `StateNotifier`
  (idle -> provisioning -> active/failed).
- `providers/` - Riverpod wiring, including a Dio instance with the HID
  interceptor pre-installed.

## What runs natively vs. in Flutter

| Concern                                        | Lives in   |
|------------------------------------------------|------------|
| Presenting `PKAddPaymentPassViewController`    | Swift      |
| Implementing `generateRequestWithCertificateChain` delegate | Swift |
| Building `PKAddPaymentPassRequest` (encrypted PAN, activation data) | Swift |
| Calling the issuer/TSP                         | Swift (mocked) |
| HID Approve OTP generation                     | Swift (mocked) |
| UI, state machine, navigation, settings        | Dart       |
| Authenticated HTTP via Dio + OTP interceptor   | Dart       |

## Apple entitlement workflow (production)

Apple Wallet in-app provisioning requires the
`com.apple.developer.payment-pass-provisioning` entitlement. Apple does
NOT grant this through the developer portal toggle. Steps:

1. Submit the request form:
   https://developer.apple.com/contact/request/wallet-pass-payment
2. Apple reviews your bank/issuer relationship and approves your team.
3. Enable the entitlement on your App ID in Apple Developer.
4. Add the keys to `Runner.entitlements` (template included, commented).
5. Coordinate with your TSP (Visa VTS / Mastercard MDES) so the issuer
   service can return real `encryptedPassData`, `activationData`, and
   `ephemeralPublicKey`.

`Runner.entitlements` ships with the keys commented and a pointer to
the Apple request URL.

## What is mocked

| Component | Mock | Real replacement |
|---|---|---|
| HID Approve OTP | FNV-1a hash of the request id (Swift) | HID Approve xcframework + license |
| Issuer / TSP    | `MockIssuerService` returns canned bytes | Bank backend over HTTPS |
| Backend host    | `https://mocked-bank.example.invalid` (never reached) | Bank's authenticated API |
| Entitlement     | `hasEntitlement` returns `false` | Real provisioned entitlement |

Every mock is tagged with a `// MOCK` comment so they are easy to find
and replace.

## Swapping in the real HID Approve SDK

1. Obtain the HID Approve xcframework from your HID Global account.
2. Drag `HIDApprove.xcframework` into `ios/Runner` (Embed & Sign).
3. In `HidApproveChannel.swift`:
   - `import HIDApprove`
   - Replace `generateMockOtp` with `HIDOTPGenerator.generate(...)`
     (exact API name depends on your SDK version).
4. Provision the license key through HID's secure provisioning flow
   (do NOT commit the key to git).
5. The Dart side and the Dio interceptor do not change.

## Running

```bash
flutter pub get
flutter run -d ios     # full flow on iOS
flutter run -d android # wallet screen shows "iOS only" disabled state
```

## Tests

```bash
flutter test
```

Covers:
- `HidOtpInterceptor` attaches the OTP header / rejects on SDK failure.
- `WalletController` state machine: success / failure / unsupported /
  dismiss.

## Disclaimer

Portfolio POC. Not a shippable banking app. Do not embed real HID
licenses, real TSP endpoints, or real PANs in this codebase.
