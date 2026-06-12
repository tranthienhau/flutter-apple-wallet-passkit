# Screenshot capture flow

Real captures from the iOS Simulator via an integration-test driver (no mockups).

## Steps

1. Boot the simulator:
   ```bash
   xcrun simctl boot "iPhone 17 Pro"
   open -a Simulator
   ```
2. Scaffold the iOS platform folder (if missing) and get dependencies:
   ```bash
   flutter create . --platforms=ios --project-name flutter_apple_wallet_passkit
   flutter pub get
   ```
3. Drive the screenshot test:
   ```bash
   flutter drive \
     --driver test_driver/integration_test.dart \
     --target integration_test/screenshot_test.dart \
     -d "iPhone 17 Pro"
   ```
4. Build the demo GIF from the PNGs:
   ```bash
   cd screenshots
   ffmpeg -y -framerate 1 -pattern_type glob -i '*.png' \
     -vf "scale=320:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
     -loop 0 demo.gif
   ```

PNGs + `demo.gif` are written to `screenshots/` and embedded in `README.md`.

## How it works

- `test_driver/integration_test.dart` - `integrationDriver(onScreenshot:)` writes each PNG to `screenshots/<name>.png`.
- `integration_test/screenshot_test.dart` - pumps the full `WalletPocApp` (Riverpod + go_router) and walks the bottom navigation:
  - `01-wallet` - the Wallet tab with PassKit status rows and a seeded provisioned Visa card.
  - `02-transactions` - the Transactions tab after tapping "Send signed transaction"; the Dio HID interceptor stamps `X-HID-OTP` / `X-HID-Request-Id`, shown in the result card.
  - `03-settings` - the Settings tab with the cardholder name and biometric toggle.
- The native HID Approve MethodChannel has no implementation under `flutter drive`, so the test overrides `hidApproveServiceProvider` with a deterministic stub OTP via `ProviderScope(overrides: [...])`, keeping the Transactions screen populated and real-looking.
- Each capture calls `binding.convertFlutterSurfaceToImage()` + `pumpAndSettle()` + `binding.takeScreenshot('NN-name')`.
